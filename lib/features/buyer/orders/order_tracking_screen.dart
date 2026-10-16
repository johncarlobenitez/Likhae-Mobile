import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;

import '../../../core/config/app_config.dart';
import '../../../services/buyer_mobile_service.dart';
import '../../../services/realtime_service.dart';
import 'orders_screen.dart';

class OrderTrackingScreen extends StatefulWidget {
  final BuyerOrderData order;

  final VoidCallback? onBack;

  const OrderTrackingScreen({super.key, required this.order, this.onBack});

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}
class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const String _mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  static const Color _maroon = Color(0xFF7A2430);
  static const Color _text = Color(0xFF2D2926);
  static const Color _muted = Color(0xFF766C65);

  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _mapMarkers;
  mapbox.PolylineAnnotationManager? _routeLines;

  late BuyerOrderData _trackedOrder;
  Timer? _locationRefreshTimer;
  RealtimeSubscription? _shipmentRealtime;
  bool _refreshingLocation = false;
  bool _locationRefreshErrorShown = false;
  bool _routeRequestInProgress = false;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteRequestAt;
  bool _roadRouteUnavailable = false;
  double? _roadDistanceMeters;
  double? _roadDurationSeconds;

  double _zoomLevel = 14;
  LatLng _lastMapCenter = _defaultCenter;

  BuyerOrderData get order => _trackedOrder;

  @override
  void initState() {
    super.initState();
    _trackedOrder = widget.order;
    if (AppConfig.apiEnabled && !widget.order.isPreview) {
      _locationRefreshTimer = Timer.periodic(
        const Duration(seconds: 15),
        (_) => unawaited(_refreshOrderLocation()),
      );
      unawaited(_connectShipmentRealtime());
    }
  }

  @override
  void didUpdateWidget(covariant OrderTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _trackedOrder = widget.order;
    }
  }

  @override
  void dispose() {
    _locationRefreshTimer?.cancel();
    unawaited(_shipmentRealtime?.cancel());
    super.dispose();
  }

  Future<void> _connectShipmentRealtime() async {
    final String? shipmentId = order.shipmentId;
    if (shipmentId == null || shipmentId.isEmpty) return;

    try {
      final RealtimeSubscription subscription =
          await LikhaeRealtimeService.subscribe('shipments.$shipmentId');
      if (!mounted) {
        await subscription.cancel();
        return;
      }
      _shipmentRealtime = subscription;
      await for (final RealtimeEvent event in subscription.events) {
        if (!mounted) return;
        if (event.name == 'rider.location.updated') {
          final double? latitude =
              double.tryParse((event.data['latitude'] ?? '').toString());
          final double? longitude =
              double.tryParse((event.data['longitude'] ?? '').toString());
          if (latitude == null || longitude == null) continue;
          setState(() {
            _trackedOrder = order.copyWith(
              riderLocation: BuyerOrderLocation(
                latitude: latitude,
                longitude: longitude,
                label: 'Rider location',
              ),
            );
          });
          await _syncMapboxMarkers(recenter: false);
        } else if (event.name == 'shipment.tracking.updated') {
          final String status =
              (event.data['current_status'] ?? '').toString().trim();
          if (status.isEmpty) continue;
          setState(() {
            _trackedOrder = order.copyWith(
              backendStatus: status,
              statusLabel: status.replaceAll('_', ' '),
            );
          });
        }
      }
    } catch (_) {
      // The existing location request remains the safe fallback.
    }
  }

  Future<void> _refreshOrderLocation() async {
    if (_refreshingLocation || order.id.isEmpty) {
      return;
    }
    _refreshingLocation = true;
    try {
      final BuyerOrderLocation? riderLocation =
          await BuyerMobileService.fetchRiderLocation(order.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _trackedOrder = order.copyWith(
          riderLocation: riderLocation,
          clearRiderLocation: riderLocation == null,
        );
      });
      _locationRefreshErrorShown = false;
      await _syncMapboxMarkers(recenter: false);
    } catch (error) {
      if (mounted && !_locationRefreshErrorShown) {
        _locationRefreshErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to refresh rider location: $error')),
        );
      }
    } finally {
      _refreshingLocation = false;
    }
  }

  List<BuyerOrderLocation> get _locations {
    final List<BuyerOrderLocation> locations = <BuyerOrderLocation>[];
    if (order.riderLocation != null) {
      locations.add(order.riderLocation!);
    }
    if (order.orderLocation != null) {
      locations.add(order.orderLocation!);
    }
    return locations;
  }

  bool get _supportsMapbox {
    if (kIsWeb) {
      return false;
    }

    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _canShowMapbox {
    return _supportsMapbox && _mapboxAccessToken.isNotEmpty;
  }

  LatLng get _center {
    final BuyerOrderLocation? rider = order.riderLocation;
    final BuyerOrderLocation? destination = order.orderLocation;

    if (rider != null && destination != null) {
      return LatLng(
        (rider.latitude + destination.latitude) / 2,
        (rider.longitude + destination.longitude) / 2,
      );
    }

    final BuyerOrderLocation? location = destination ?? rider;
    return location == null
        ? _defaultCenter
        : LatLng(location.latitude, location.longitude);
  }

  String? get _riderDistanceText {
    final BuyerOrderLocation? rider = order.riderLocation;
    final BuyerOrderLocation? destination = order.orderLocation;
    if (rider == null || destination == null) {
      return null;
    }

    final double meters = Geolocator.distanceBetween(
      rider.latitude,
      rider.longitude,
      destination.latitude,
      destination.longitude,
    );

    if (meters < 1000) {
      return '${meters.round()} m away';
    }

    return '${(meters / 1000).toStringAsFixed(1)} km away';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F0EB),
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text('Track Order'),
        backgroundColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: ListView(
            children: <Widget>[
              _buildMapCard(),
              const SizedBox(height: 16),
              _buildTimelineCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapCard() {
    final bool hasRider = order.riderLocation != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: ShopColors.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: _maroon,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Live Delivery Map',
                        style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasRider
                            ? 'Current rider location and route to the buyer.'
                            : 'Waiting for rider location updates.',
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 300,
            child: Stack(
              children: <Widget>[
                if (_canShowMapbox)
                  Positioned.fill(
                    child: mapbox.MapWidget(
                      viewport: mapbox.CameraViewportState(
                        center: _toMapboxPoint(_center),
                        zoom: _zoomLevel,
                      ),
                      onMapCreated: _onMapboxMapCreated,
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: const Color(0xFFF7F2EE),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _supportsMapbox
                                ? 'Add MAPBOX_ACCESS_TOKEN to your Flutter run configuration to load the map.'
                                : 'Mapbox Maps SDK is available on Android and iOS.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_canShowMapbox)
                  Positioned(
                    right: 16,
                    bottom: 20,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        _buildZoomButton(
                          icon: Icons.add,
                          onPressed: () => _zoomMap(1),
                        ),
                        const SizedBox(height: 8),
                        _buildZoomButton(
                          icon: Icons.remove,
                          onPressed: () => _zoomMap(-1),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: _LegendDot(color: _maroon, label: 'Buyer location'),
                ),
                if (hasRider)
                  const Expanded(
                    child: _LegendDot(
                      color: Color(0xFF1976D2),
                      label: 'Current rider location',
                    ),
                  ),
              ],
            ),
          ),
          if (order.riderLocation != null && order.orderLocation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '${_roadRouteSummary}\nRider is ${_riderDistanceText ?? 'nearby'} and on the way.',
                style: const TextStyle(
                  color: _text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildZoomButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon, color: _text),
        splashRadius: 20,
        padding: EdgeInsets.zero,
      ),
    );
  }

  Widget _buildTimelineCard() {
    final bool isCompleted = order.status == 'completed' ||
        order.backendStatus == 'completed';

    final List<BuyerOrderTimelineEvent> events = order.timeline.isNotEmpty
        ? order.timeline
        : <BuyerOrderTimelineEvent>[
            const BuyerOrderTimelineEvent(
              label: 'Order placed',
              time: 'Sep 24, 2026 • 1:31 PM',
              done: true,
            ),
            const BuyerOrderTimelineEvent(
              label: 'Packed',
              time: 'Sep 24, 2026 • 2:15 PM',
              done: true,
            ),
            const BuyerOrderTimelineEvent(
              label: 'On the way',
              time: 'Sep 24, 2026 • 4:10 PM',
              done: true,
            ),
            BuyerOrderTimelineEvent(
              label: 'Delivered',
              time: 'Sep 24, 2026 • 4:42 PM',
              done: isCompleted,
            ),
          ];

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Tracking Timeline',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ...List<Widget>.generate(events.length, (int index) {
            final BuyerOrderTimelineEvent event = events[index];
            final bool isLast = index == events.length - 1;
            final bool isDone = event.done;

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    event.time,
                    style: const TextStyle(
                      color: _muted,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: isDone ? _maroon : const Color(0xFFEAE1D8),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDone ? _maroon : const Color(0xFFD6C7B9),
                            width: 2,
                          ),
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: 34,
                          color: const Color(0xFFD9CFC3),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 0, bottom: isLast ? 0 : 10),
                    child: Text(
                      event.label,
                      style: TextStyle(
                        color: isDone ? _text : _muted,
                        fontSize: 15,
                        fontWeight: isDone ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Future<void> _onMapboxMapCreated(mapbox.MapboxMap map) async {
    _mapboxMap = map;
    _mapMarkers = await map.annotations.createCircleAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    await _syncMapboxMarkers();
  }

  Future<void> _syncMapboxMarkers({bool recenter = true}) async {
    final mapbox.MapboxMap? map = _mapboxMap;
    final mapbox.CircleAnnotationManager? manager = _mapMarkers;

    if (map == null || manager == null) {
      return;
    }

    await manager.deleteAll();

    final List<mapbox.CircleAnnotationOptions> annotations =
        <mapbox.CircleAnnotationOptions>[];

    for (final BuyerOrderLocation location in _locations) {
      final bool isRider = order.riderLocation != null &&
          location.latitude == order.riderLocation!.latitude &&
          location.longitude == order.riderLocation!.longitude;

      annotations.add(
        mapbox.CircleAnnotationOptions(
          geometry: _toMapboxPoint(LatLng(location.latitude, location.longitude)),
          circleColor: isRider ? const Color(0xFF1976D2).toARGB32() : _maroon.toARGB32(),
          circleRadius: isRider ? 10 : 11,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
          circleSortKey: isRider ? 3 : 2,
        ),
      );
    }

    if (annotations.isNotEmpty) {
      await manager.createMulti(annotations);
    }

    if (recenter) {
      _lastMapCenter = _center;
      _zoomLevel = _locations.isEmpty ? 11 : 14;
      final BuyerOrderLocation? rider = order.riderLocation;
      final BuyerOrderLocation? destination = order.orderLocation;
      if (rider != null && destination != null) {
        final mapbox.CameraOptions camera = await map.cameraForCoordinatesPadding(
          <mapbox.Point>[
            _toMapboxPoint(LatLng(rider.latitude, rider.longitude)),
            _toMapboxPoint(LatLng(destination.latitude, destination.longitude)),
          ],
          mapbox.CameraOptions(
            padding: mapbox.MbxEdgeInsets(
              top: 48,
              left: 48,
              bottom: 48,
              right: 48,
            ),
          ),
          null,
          14,
          null,
        );
        _zoomLevel = camera.zoom ?? _zoomLevel;
        await map.setCamera(camera);
      } else {
        await map.setCamera(
          mapbox.CameraOptions(
            center: _toMapboxPoint(_lastMapCenter),
            zoom: _zoomLevel,
          ),
        );
      }
    }

    await _syncRoadRoute();
  }

  Future<void> _syncRoadRoute() async {
    final mapbox.PolylineAnnotationManager? manager = _routeLines;
    final BuyerOrderLocation? rider = order.riderLocation;
    final BuyerOrderLocation? destination = order.orderLocation;
    if (manager == null) return;
    if (rider == null || destination == null || _mapboxAccessToken.isEmpty) {
      await manager.deleteAll();
      if (mounted) {
        setState(() {
          _roadDistanceMeters = null;
          _roadDurationSeconds = null;
          _roadRouteUnavailable = false;
        });
      }
      return;
    }

    final LatLng origin = LatLng(rider.latitude, rider.longitude);
    final LatLng target = LatLng(destination.latitude, destination.longitude);
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequestAt = _lastRouteRequestAt;
    if (_routeRequestInProgress ||
        (previousOrigin != null &&
            previousRequestAt != null &&
            DateTime.now().difference(previousRequestAt) <
                const Duration(seconds: 15) &&
            Geolocator.distanceBetween(
                  previousOrigin.latitude,
                  previousOrigin.longitude,
                  origin.latitude,
                  origin.longitude,
                ) <
                50)) {
      return;
    }

    _routeRequestInProgress = true;
    _lastRouteOrigin = origin;
    _lastRouteRequestAt = DateTime.now();
    final String coordinates =
        '${origin.longitude},${origin.latitude};'
        '${target.longitude},${target.latitude}';
    try {
      final Response<Map<String, dynamic>> response = await Dio().get(
        'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/$coordinates',
        queryParameters: <String, dynamic>{
          'access_token': _mapboxAccessToken,
          'geometries': 'geojson',
          'overview': 'full',
          'steps': false,
        },
      );
      final List<dynamic> routes =
          response.data?['routes'] as List<dynamic>? ?? const <dynamic>[];
      if (routes.isEmpty) throw StateError('No driving route was returned.');
      final Map<String, dynamic> route =
          Map<String, dynamic>.from(routes.first as Map);
      final Map<String, dynamic> geometry =
          Map<String, dynamic>.from(route['geometry'] as Map);
      final List<dynamic> rawCoordinates =
          geometry['coordinates'] as List<dynamic>? ?? const <dynamic>[];
      final List<mapbox.Position> positions = rawCoordinates
          .whereType<List<dynamic>>()
          .where((List<dynamic> pair) => pair.length >= 2)
          .map((List<dynamic> pair) => mapbox.Position(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              ))
          .toList(growable: false);
      if (positions.length < 2) throw StateError('The driving route was incomplete.');

      await manager.deleteAll();
      await manager.create(
        mapbox.PolylineAnnotationOptions(
          geometry: mapbox.LineString(coordinates: positions),
          lineColor: _maroon.toARGB32(),
          lineWidth: 5,
          lineOpacity: 0.85,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.5,
        ),
      );
      if (mounted) {
        setState(() {
          _roadDistanceMeters = (route['distance'] as num?)?.toDouble();
          _roadDurationSeconds = (route['duration'] as num?)?.toDouble();
          _roadRouteUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _roadRouteUnavailable = true);
      }
    } finally {
      _routeRequestInProgress = false;
    }
  }

  String get _roadRouteSummary {
    final double? distance = _roadDistanceMeters;
    final double? duration = _roadDurationSeconds;
    if (_roadRouteUnavailable && (distance == null || duration == null)) {
      return 'Road route unavailable; retrying.';
    }
    if (distance == null || duration == null) return 'Calculating road route…';
    final String distanceText = distance < 1000
        ? '${distance.round()} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';
    final int minutes = (duration / 60).ceil();
    final String durationText = minutes < 60
        ? '$minutes min'
        : '${minutes ~/ 60}h ${minutes % 60}m';
    return '$distanceText by road · about $durationText';
  }

  Future<void> _zoomMap(double step) async {
    final mapbox.MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }

    _zoomLevel = (_zoomLevel + step).clamp(3.0, 18.0);
    _lastMapCenter = _center;

    await map.setCamera(
      mapbox.CameraOptions(
        center: _toMapboxPoint(_lastMapCenter),
        zoom: _zoomLevel,
      ),
    );
  }

  mapbox.Point _toMapboxPoint(LatLng point) {
    return mapbox.Point(
      coordinates: mapbox.Position(
        point.longitude,
        point.latitude,
      ),
    );
  }

}

class _LegendDot extends StatelessWidget {
  final Color color;

  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF766C65)),
        ),
      ],
    );
  }
}

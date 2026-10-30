import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;

import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../../services/rider_mobile_service.dart';
import 'pickups/rider_pickups_screen.dart';

class RiderStageNavigationScreen extends StatefulWidget {
  final RiderPickupData pickup;
  final bool toLogisticsCenter;

  const RiderStageNavigationScreen({
    super.key,
    required this.pickup,
    required this.toLogisticsCenter,
  });

  @override
  State<RiderStageNavigationScreen> createState() =>
      _RiderStageNavigationScreenState();
}

class _RiderStageNavigationScreenState
    extends State<RiderStageNavigationScreen> {
  static const Color _maroon = Color(0xFF7A2430);
  static const Color _riderBlue = Color(0xFF1976D2);
  static const Color _muted = Color(0xFF766C65);
  static const Color _routeColor = Color(0xFF7A2A22);

  maplibre.MapLibreSession? _map;
  maplibre.CircleAnnotationManager? _markers;
  maplibre.PolylineAnnotationManager? _routeLines;
  StreamSubscription<Position>? _positionSubscription;
  Position? _latestPosition;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteRequestAt;
  DateTime? _routeArrivalAt;
  DateTime? _lastLocationPostAt;
  LatLng? _lastPostedLocation;
  double? _routeMeters;
  double? _routeSeconds;
  bool _routeRequestInProgress = false;
  bool _cameraPositioned = false;
  bool _gpsTracking = false;
  bool _gpsStarting = false;
  bool _locationPostErrorShown = false;
  String _status = 'Waiting for rider GPS.';

  bool get _supportsMapLibre =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  double? get _destinationLatitude => widget.toLogisticsCenter
      ? widget.pickup.logisticsCenterLatitude
      : widget.pickup.sellerLatitude;

  double? get _destinationLongitude => widget.toLogisticsCenter
      ? widget.pickup.logisticsCenterLongitude
      : widget.pickup.sellerLongitude;

  LatLng? get _destination {
    final double? latitude = _destinationLatitude;
    final double? longitude = _destinationLongitude;
    if (latitude == null ||
        longitude == null ||
        !latitude.isFinite ||
        !longitude.isFinite ||
        latitude < -90 ||
        latitude > 90 ||
        longitude < -180 ||
        longitude > 180 ||
        (latitude == 0 && longitude == 0)) {
      return null;
    }
    return LatLng(latitude, longitude);
  }

  String get _destinationName {
    if (widget.toLogisticsCenter) {
      return widget.pickup.logisticsCenter.trim().isEmpty
          ? 'Logistics center'
          : widget.pickup.logisticsCenter.trim();
    }
    return widget.pickup.sellerName.trim().isEmpty
        ? 'Seller pickup'
        : widget.pickup.sellerName.trim();
  }

  String get _destinationAddress => widget.toLogisticsCenter
      ? widget.pickup.destinationAddress
      : widget.pickup.address;

  List<int> get _assignmentIds {
    final Iterable<RiderPickupBatchItemData> parcels = widget.toLogisticsCenter
        ? widget.pickup.parcels.where(
            (RiderPickupBatchItemData parcel) => parcel.wasCollected,
          )
        : widget.pickup.parcels.where(
            (RiderPickupBatchItemData parcel) => !parcel.isResolved,
          );
    final List<int> batchAssignmentIds = parcels
        .map((RiderPickupBatchItemData parcel) => parcel.assignmentId)
        .where((int id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (widget.pickup.isBatch) return batchAssignmentIds;
    return widget.pickup.id > 0 ? <int>[widget.pickup.id] : const <int>[];
  }

  @override
  void initState() {
    super.initState();
    if (_destination == null) {
      _status = widget.toLogisticsCenter
          ? 'Logistics center coordinates are unavailable.'
          : 'The seller has not saved an exact map pin.';
    }
    if (_supportsMapLibre) unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _startLocationTracking() async {
    if (!_supportsMapLibre || _positionSubscription != null || _gpsStarting) {
      return;
    }
    if (mounted) setState(() => _gpsStarting = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsTracking = false;
            _status = 'Turn on device location to share GPS.';
          });
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _gpsTracking = false;
            _status = 'Location permission is required for rider GPS.';
          });
        }
        return;
      }

      if (mounted) {
        setState(() {
          _gpsTracking = true;
          _status = 'Waiting for a precise GPS fix.';
        });
      }
      await _positionSubscription?.cancel();
      _positionSubscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.bestForNavigation,
              distanceFilter: 5,
            ),
          ).listen(
            _onPosition,
            onError: (_) {
              unawaited(_positionSubscription?.cancel());
              _positionSubscription = null;
              if (mounted) {
                setState(() {
                  _gpsTracking = false;
                  _status = 'Device GPS is temporarily unavailable.';
                });
              }
            },
          );
    } catch (error) {
      if (mounted) {
        setState(() {
          _gpsTracking = false;
          _status = 'Could not start rider GPS: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _gpsStarting = false);
    }
  }

  Future<void> _toggleLocationTracking() async {
    if (_positionSubscription != null) {
      await _positionSubscription?.cancel();
      _positionSubscription = null;
      if (mounted) {
        setState(() {
          _gpsTracking = false;
          _status = 'Live rider GPS paused. Resume GPS to update your route.';
        });
      }
      return;
    }
    await _startLocationTracking();
  }

  void _onPosition(Position position) {
    _latestPosition = position;
    if (mounted) setState(() => _status = 'Live rider GPS is active.');
    final LatLng origin = LatLng(position.latitude, position.longitude);
    unawaited(_syncMap(origin));
    _postLocationIfNeeded(position, origin);
  }

  void _postLocationIfNeeded(Position position, LatLng location) {
    if (!AppConfig.apiEnabled || _assignmentIds.isEmpty) return;
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 250) {
      if (mounted)
        setState(
          () => _status = 'GPS accuracy is too low; waiting for a better fix.',
        );
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastPost = _lastLocationPostAt;
    final LatLng? lastLocation = _lastPostedLocation;
    if (lastPost != null &&
        now.difference(lastPost) < const Duration(seconds: 10)) {
      if (lastLocation == null ||
          Geolocator.distanceBetween(
                lastLocation.latitude,
                lastLocation.longitude,
                location.latitude,
                location.longitude,
              ) <
              25) {
        return;
      }
    }

    _lastLocationPostAt = now;
    _lastPostedLocation = location;
    unawaited(_uploadLocation(position));
  }

  Future<void> _uploadLocation(Position position) async {
    final List<int> assignmentIds = _assignmentIds;
    try {
      await Future.wait<void>(
        assignmentIds.map((int assignmentId) {
          return RiderMobileService.updateLiveLocation(
            assignmentId: assignmentId,
            latitude: position.latitude,
            longitude: position.longitude,
            accuracy: position.accuracy,
            recordedAt: position.timestamp,
          );
        }),
      );
      _locationPostErrorShown = false;
    } catch (error) {
      if (mounted && !_locationPostErrorShown) {
        _locationPostErrorShown = true;
        _showMessage(
          'GPS is visible on this device but could not sync: $error',
        );
      }
    }
  }

  Future<void> _onMapCreated(maplibre.MapLibreSession map) async {
    _map = map;
    _markers = await map.annotations.createCircleAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    final Position? position = _latestPosition;
    await _syncMap(
      position == null ? null : LatLng(position.latitude, position.longitude),
    );
  }

  Future<void> _syncMap(LatLng? origin) async {
    final maplibre.MapLibreSession? map = _map;
    final maplibre.CircleAnnotationManager? markerManager = _markers;
    final LatLng? destination = _destination;
    if (map == null || markerManager == null || destination == null) return;

    await markerManager.deleteAll();
    await markerManager.createMulti(<maplibre.CircleAnnotationOptions>[
      maplibre.CircleAnnotationOptions(
        geometry: _toMapLibrePoint(destination),
        circleColor: _maroon.toARGB32(),
        circleRadius: 11,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
      if (origin != null)
        maplibre.CircleAnnotationOptions(
          geometry: _toMapLibrePoint(origin),
          circleColor: _riderBlue.toARGB32(),
          circleRadius: 9,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
        ),
    ]);

    if (!_cameraPositioned) {
      if (origin != null) {
        final maplibre.CameraOptions camera = await map
            .cameraForCoordinatesPadding(
              <maplibre.Point>[
                _toMapLibrePoint(origin),
                _toMapLibrePoint(destination),
              ],
              maplibre.CameraOptions(
                padding: maplibre.MbxEdgeInsets(
                  top: 48,
                  left: 48,
                  bottom: 48,
                  right: 48,
                ),
              ),
              null,
              15,
              null,
            );
        await map.setCamera(camera);
      } else {
        await map.setCamera(
          maplibre.CameraOptions(
            center: _toMapLibrePoint(destination),
            zoom: 14,
          ),
        );
      }
      _cameraPositioned = true;
    }

    if (origin != null) unawaited(_drawRoute(origin, destination));
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    if (manager == null || _routeRequestInProgress) return;
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequestAt = _lastRouteRequestAt;
    if (previousOrigin != null && previousRequestAt != null) {
      final double movedMeters = Geolocator.distanceBetween(
        previousOrigin.latitude,
        previousOrigin.longitude,
        origin.latitude,
        origin.longitude,
      );
      final Duration routeAge = DateTime.now().difference(previousRequestAt);
      final bool routeIsAvailable = _routeMeters != null;
      if (movedMeters < 100 &&
          routeAge < Duration(seconds: routeIsAvailable ? 90 : 30)) {
        return;
      }
    }

    _routeRequestInProgress = true;
    _lastRouteOrigin = origin;
    _lastRouteRequestAt = DateTime.now();
    final String coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    try {
      final Response<dynamic> response = await ApiClient.get(
        'maps/route',
        queryParameters: <String, dynamic>{'waypoints': coordinates},
      );
      final List<dynamic> routes =
          response.data?['routes'] as List<dynamic>? ?? const <dynamic>[];
      if (routes.isEmpty) throw StateError('No driving route was returned.');
      final Map<String, dynamic> route = Map<String, dynamic>.from(
        routes.first as Map,
      );
      final Map<String, dynamic> geometry = Map<String, dynamic>.from(
        route['geometry'] as Map,
      );
      final List<dynamic> coordinatesList =
          geometry['coordinates'] as List<dynamic>? ?? const <dynamic>[];
      final List<maplibre.Position> positions = coordinatesList
          .whereType<List<dynamic>>()
          .where((List<dynamic> pair) => pair.length >= 2)
          .map(
            (List<dynamic> pair) => maplibre.Position(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ),
          )
          .toList(growable: false);
      if (positions.length < 2)
        throw StateError('The driving route was incomplete.');

      await manager.deleteAll();
      await manager.create(
        maplibre.PolylineAnnotationOptions(
          geometry: maplibre.LineString(coordinates: positions),
          lineColor: _routeColor.toARGB32(),
          lineWidth: 5,
          lineOpacity: 0.85,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.5,
        ),
      );
      if (mounted) {
        final double? distance = (route['distance'] as num?)?.toDouble();
        final double? duration = (route['duration'] as num?)?.toDouble();
        setState(() {
          _routeMeters = distance;
          _routeSeconds = duration;
          _routeArrivalAt = duration == null || !duration.isFinite
              ? null
              : DateTime.now().add(Duration(seconds: duration.round()));
          _status = 'Road route updated from rider GPS.';
        });
      }
    } catch (error) {
      if (mounted)
        setState(
          () => _status = 'Map route is temporarily unavailable: $error',
        );
    } finally {
      _routeRequestInProgress = false;
    }
  }

  maplibre.Point _toMapLibrePoint(LatLng point) => maplibre.Point(
    coordinates: maplibre.Position(point.longitude, point.latitude),
  );

  String _formatDistance(double? meters) {
    if (meters == null || !meters.isFinite) return '—';
    if (meters < 1000) return '${meters.round()} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  String _formatDuration(double? seconds) {
    if (seconds == null || !seconds.isFinite) return '—';
    final int minutes = (seconds / 60).ceil();
    if (minutes < 60) return '$minutes min';
    final int hours = minutes ~/ 60;
    final int remainder = minutes % 60;
    return remainder == 0 ? '${hours}h' : '${hours}h ${remainder}m';
  }

  String _formatArrivalTime(DateTime? arrival) {
    if (arrival == null) return '—';
    return TimeOfDay.fromDateTime(arrival.toLocal()).format(context);
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final LatLng? destination = _destination;
    return Scaffold(
      backgroundColor: const Color(0xFFFBF7F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFBF7F2),
        foregroundColor: const Color(0xFF3B211B),
        title: Text(
          widget.toLogisticsCenter
              ? 'Navigate to Logistics'
              : 'Navigate to Seller',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _supportsMapLibre && destination != null
                  ? maplibre.MapLibreMapWidget(
                      viewport: maplibre.MapLibreViewport(
                        center: _toMapLibrePoint(destination),
                        zoom: 13,
                      ),
                      onMapCreated: _onMapCreated,
                    )
                  : ColoredBox(
                      color: const Color(0xFFF1E9E2),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            !_supportsMapLibre
                                ? 'The interactive map is available on Android and iOS.'
                                : 'The saved destination coordinates are unavailable.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: _muted, height: 1.5),
                          ),
                        ),
                      ),
                    ),
            ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Text(
                    _destinationName,
                    style: const TextStyle(
                      color: Color(0xFF3B211B),
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (_destinationAddress.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 5),
                    Text(
                      _destinationAddress,
                      style: const TextStyle(color: _muted, height: 1.4),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _RouteMetric(
                          label: 'Road distance',
                          value: _formatDistance(_routeMeters),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _RouteMetric(
                          label: 'Estimated time',
                          value: _formatDuration(_routeSeconds),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _RouteMetric(
                    label: 'Estimated arrival',
                    value: _formatArrivalTime(_routeArrivalAt),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _status,
                    style: const TextStyle(color: _muted, fontSize: 12),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _gpsStarting || !_supportsMapLibre
                          ? null
                          : _toggleLocationTracking,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _maroon,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: Icon(
                        _gpsTracking
                            ? Icons.pause_circle_outline_rounded
                            : Icons.my_location_rounded,
                      ),
                      label: Text(
                        _gpsStarting
                            ? 'Starting rider GPS'
                            : _gpsTracking
                            ? 'Pause live GPS'
                            : 'Resume rider GPS',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RouteMetric extends StatelessWidget {
  final String label;
  final String value;

  const _RouteMetric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFBF7F2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: _RiderStageNavigationScreenState._muted,
              fontSize: 10,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: _RiderStageNavigationScreenState._maroon,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

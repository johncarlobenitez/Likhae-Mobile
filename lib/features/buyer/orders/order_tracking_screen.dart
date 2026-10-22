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
  static final Dio _directionsClient = Dio();

  static const Duration _locationRefreshInterval = Duration(seconds: 15);
  static const Duration _minimumRouteRefreshInterval = Duration(seconds: 45);
  static const double _minimumRerouteDistanceMeters = 100;
  static const double _minimumRiderMapUpdateMeters = 5;

  static const Color _maroon = ShopColors.accent;
  static const Color _text = ShopColors.text;
  static const Color _muted = ShopColors.muted;
  static const Color _canvas = ShopColors.canvas;
  static const Color _surface = ShopColors.surface;
  static const Color _timelineActive = Color(0xFF258575);
  static const Color _timelineInactive = Color(0xFFB7B7B7);
  static const Color _proofLink = Color(0xFF3978C7);

  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _mapMarkers;
  mapbox.PointAnnotationManager? _routeLabels;
  mapbox.PolylineAnnotationManager? _routeLines;
  mapbox.PolylineAnnotation? _roadRouteLine;
  List<mapbox.CircleAnnotation> _circleAnnotations =
      <mapbox.CircleAnnotation>[];
  List<mapbox.PointAnnotation> _pointAnnotations =
      <mapbox.PointAnnotation>[];
  List<_TrackingMapMarkerSpec> _renderedMapMarkers =
      <_TrackingMapMarkerSpec>[];

  late BuyerOrderData _trackedOrder;
  Timer? _locationRefreshTimer;
  RealtimeSubscription? _shipmentRealtime;
  bool _refreshingLocation = false;
  bool _locationRefreshErrorShown = false;
  bool _syncingMapAnnotations = false;
  bool _mapSyncQueued = false;
  bool _queuedMapSyncRecenters = false;
  bool _routeRequestInProgress = false;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteRequestAt;
  String? _lastRouteTopologyKey;
  bool _roadRouteUnavailable = false;
  double? _roadDistanceMeters;
  double? _roadDurationSeconds;

  double _zoomLevel = 14;
  LatLng _lastMapCenter = _defaultCenter;

  BuyerOrderData get order => _trackedOrder;

  static String _humanizeStatus(String value) {
    return value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((String word) => word.isNotEmpty)
        .map((String word) =>
            '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}')
        .join(' ');
  }

  static String _sentenceCase(String value) {
    String sentence = value.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (sentence.isEmpty) return '';

    if (!RegExp(r'[a-z]').hasMatch(sentence)) {
      sentence = sentence.toLowerCase();
    } else {
      sentence = sentence.replaceFirstMapped(
        RegExp(r'^[A-Z]{2,}(?=\s|[.,:;!?]|$)'),
        (Match match) {
          final String word = match.group(0)!;
          return '${word[0]}${word.substring(1).toLowerCase()}';
        },
      );
    }

    return '${sentence[0].toUpperCase()}${sentence.substring(1)}';
  }

  static String _timelineDescription(BuyerOrderTimelineEvent event) {
    final String key = event.label
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');
    if (key.endsWith('delivered') ||
        key.contains('deliverysuccess') ||
        key.contains('deliverycomplete')) {
      return 'Parcel has been delivered.';
    }
    if (key.contains('outfordelivery')) {
      return 'Parcel is out for delivery.';
    }
    if (key.contains('assignedtorider') || key.contains('riderassigned')) {
      if (event.details.toLowerCase().contains('accepted')) {
        return _sentenceCase(event.details);
      }
      return 'Delivery rider assigned.';
    }
    if (key.contains('readyforpickup')) {
      return 'Parcel is ready for pickup.';
    }
    if (key.contains('pickedup')) {
      return 'Parcel has been picked up.';
    }

    final String details = _sentenceCase(event.details);
    if (details.isNotEmpty) return details;

    final String readableLabel = event.label
        .replaceAll(RegExp(r'(?<=[a-z0-9])(?=[A-Z])'), ' ')
        .replaceAll(RegExp(r'[_-]+'), ' ');
    return _sentenceCase(readableLabel);
  }

  static String _formatTrackingTime(DateTime value) {
    final DateTime local = value.toLocal();
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}\n$hour:$minute $period';
  }

  @override
  void initState() {
    super.initState();
    _trackedOrder = widget.order;
    if (AppConfig.apiEnabled && !widget.order.isPreview) {
      unawaited(_loadDeliveryProof());
      _locationRefreshTimer = Timer.periodic(
        _locationRefreshInterval,
        (_) {
          if (mounted &&
              WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
              ModalRoute.of(context)?.isCurrent != false) {
            unawaited(_refreshOrderLocation());
          }
        },
      );
      unawaited(_connectShipmentRealtime());
    }
  }

  Future<void> _loadDeliveryProof({bool force = false}) async {
    final BuyerOrderData initialOrder = order;
    if ((!force && initialOrder.deliveryProofImageUrls.isNotEmpty) ||
        !AppConfig.apiEnabled ||
        initialOrder.isPreview ||
        initialOrder.id.trim().isEmpty) {
      return;
    }

    final bool deliveryComplete =
        const <String>{'delivered', 'completed', 'complete'}
            .contains(initialOrder.normalizedStatus) ||
        initialOrder.timeline.any((BuyerOrderTimelineEvent event) {
          final String label = event.label.toLowerCase();
          return label.contains('delivered') ||
              label.contains('delivery successful') ||
              label.contains('delivery complete');
        });
    if (!deliveryComplete) return;

    try {
      final BuyerOrderData detail = await BuyerMobileService.fetchOrder(
        initialOrder.id,
      );
      if (!mounted || detail.id != initialOrder.id) return;

      final List<String> proofUrls = List<String>.from(
        order.deliveryProofImageUrls,
      );
      for (final String proofUrl in detail.deliveryProofImageUrls) {
        if (!proofUrls.contains(proofUrl)) proofUrls.add(proofUrl);
      }
      if (proofUrls.length == order.deliveryProofImageUrls.length) return;

      setState(() {
        _trackedOrder = order.copyWith(deliveryProofImageUrls: proofUrls);
      });
    } catch (_) {
      // The tracking screen still works if the optional proof lookup fails.
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
          await _applyRiderLocation(
            BuyerOrderLocation(
              latitude: latitude,
              longitude: longitude,
              label: 'Rider location',
            ),
          );
        } else if (event.name == 'shipment.tracking.updated') {
          final String status = (event.data['current_status'] ??
                  event.data['status'] ??
                  event.data['status_code'] ??
                  '')
              .toString()
              .trim();
          if (status.isEmpty) continue;
          final String label = (event.data['label'] ??
                  event.data['status_label'] ??
                  _humanizeStatus(status))
              .toString()
              .trim();
          final dynamic rawDetails = event.data['notes'] ??
              event.data['details'] ??
              event.data['description'] ??
              event.data['location_name'] ??
              event.data['facility_name'] ??
              event.data['location'];
          final String details = rawDetails is Map
              ? (rawDetails['label'] ??
                        rawDetails['name'] ??
                        rawDetails['facility_name'] ??
                        rawDetails['location_name'] ??
                        '')
                    .toString()
                    .trim()
              : rawDetails?.toString().trim() ?? '';
          final DateTime? occurredAt = DateTime.tryParse(
            (event.data['occurred_at'] ?? event.data['created_at'] ?? '')
                .toString(),
          );
          final String time = occurredAt == null
              ? ''
              : _formatTrackingTime(occurredAt);
          final List<BuyerOrderTimelineEvent> timeline =
              List<BuyerOrderTimelineEvent>.from(order.timeline);
          if (timeline.isEmpty ||
              timeline.last.label != label ||
              timeline.last.details != details ||
              timeline.last.time != time) {
            timeline.add(
              BuyerOrderTimelineEvent(
                label: label.isEmpty ? _humanizeStatus(status) : label,
                time: time,
                done: true,
                details: details,
              ),
            );
          }
          final List<String> deliveryProofImageUrls =
              List<String>.from(order.deliveryProofImageUrls);
          for (final String proofUrl in parseBuyerDeliveryProofUrls(
            <Map<String, dynamic>>[event.data],
          )) {
            if (!deliveryProofImageUrls.contains(proofUrl)) {
              deliveryProofImageUrls.add(proofUrl);
            }
          }
          setState(() {
            _trackedOrder = order.copyWith(
              backendStatus: status,
              statusLabel: label.isEmpty ? _humanizeStatus(status) : label,
              timeline: timeline,
              deliveryProofImageUrls: deliveryProofImageUrls,
            );
          });
          unawaited(_refreshShipmentDetails());
          await _syncMapboxMarkers(recenter: false);
        }
      }
    } catch (_) {
      // The existing location request remains the safe fallback.
    }
  }

  Future<void> _refreshShipmentDetails() async {
    final String orderId = order.id;
    try {
      final BuyerOrderData detail = await BuyerMobileService.fetchOrder(orderId);
      if (!mounted || detail.id != orderId) return;

      final List<String> proofUrls = List<String>.from(
        order.deliveryProofImageUrls,
      );
      for (final String proofUrl in detail.deliveryProofImageUrls) {
        if (!proofUrls.contains(proofUrl)) proofUrls.add(proofUrl);
      }
      setState(() {
        _trackedOrder = detail.copyWith(
          riderLocation: order.riderLocation ?? detail.riderLocation,
          deliveryProofImageUrls: proofUrls,
        );
      });
      await _syncMapboxMarkers(recenter: false);
    } catch (_) {
      // Keep the last route visible until the order API is reachable again.
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
      await _applyRiderLocation(riderLocation);
      _locationRefreshErrorShown = false;
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

  bool _sameRiderLocation(
    BuyerOrderLocation? current,
    BuyerOrderLocation? next,
  ) {
    if (current == null || next == null) return current == null && next == null;
    return Geolocator.distanceBetween(
          current.latitude,
          current.longitude,
          next.latitude,
          next.longitude,
        ) <
        _minimumRiderMapUpdateMeters;
  }

  Future<void> _applyRiderLocation(BuyerOrderLocation? riderLocation) async {
    if (!mounted || _sameRiderLocation(order.riderLocation, riderLocation)) {
      return;
    }
    setState(() {
      _trackedOrder = order.copyWith(
        riderLocation: riderLocation,
        clearRiderLocation: riderLocation == null,
      );
    });
    await _syncMapboxMarkers(recenter: false);
  }

  List<BuyerOrderLocation> get _locations {
    final List<BuyerOrderLocation> locations = <BuyerOrderLocation>[];
    for (final BuyerOrderLocation location in <BuyerOrderLocation>[
      if (order.sellerLocation != null) order.sellerLocation!,
      ...order.shipmentRouteStops,
      if (order.riderLocation != null) order.riderLocation!,
      if (order.orderLocation != null) order.orderLocation!,
    ]) {
      if (!locations.any(
        (BuyerOrderLocation existing) =>
            existing.latitude == location.latitude &&
            existing.longitude == location.longitude,
      )) {
        locations.add(location);
      }
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
    final List<BuyerOrderLocation> locations = _locations;
    if (locations.isNotEmpty) {
      return LatLng(
        locations.map((BuyerOrderLocation location) => location.latitude)
                .reduce((double sum, double value) => sum + value) /
            locations.length,
        locations.map((BuyerOrderLocation location) => location.longitude)
                .reduce((double sum, double value) => sum + value) /
            locations.length,
      );
    }
    return _defaultCenter;
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
      backgroundColor: _canvas,
      appBar: AppBar(
        leading: IconButton(
          onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
        title: const Text(
          'Track Order',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        backgroundColor: _canvas,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
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
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ShopColors.border),
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
                        'Shipment Journey',
                        style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.shipmentRouteStops.isNotEmpty
                            ? 'See the logistics hubs your parcel passes through on its way to you.'
                            : hasRider
                            ? 'Live rider location and route to your delivery address.'
                            : order.tracking?.trim().isNotEmpty == true
                            ? 'No live rider position yet. Parcel updates appear in the timeline below.'
                            : 'A map location will appear after the parcel is dispatched.',
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
                      color: _canvas,
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: <Widget>[
                    if (order.sellerLocation != null)
                      const _LegendDot(
                        color: Color(0xFFB56B32),
                        label: 'Seller',
                      ),
                    ...List<Widget>.generate(
                      order.shipmentRouteStops.length,
                      (int index) => _LegendDot(
                        color: _routeStopColor(index),
                        label: order.shipmentRouteStops[index].label,
                      ),
                    ),
                    const _LegendDot(
                      color: _maroon,
                      label: 'Buyer',
                    ),
                    if (hasRider)
                      const _LegendDot(
                        color: Color(0xFF1976D2),
                        label: 'Current rider',
                      ),
                  ],
                ),
                if (order.shipmentRouteStops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Route: ${<String>[
                      if (order.sellerLocation != null)
                        order.sellerLocation!.label,
                      ...order.shipmentRouteStops.map(
                        (BuyerOrderLocation stop) => stop.label,
                      ),
                      order.orderLocation?.label ?? 'Delivery destination',
                    ].join(' -> ')}',
                    style: const TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (order.riderLocation != null && order.orderLocation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                '${order.shipmentRouteStops.isEmpty ? '$_roadRouteSummary\n' : ''}Rider is ${_riderDistanceText ?? 'nearby'} and on the way.',
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
        color: _surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ShopColors.border),
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

  static Color _routeStopColor(int index) {
    const List<Color> colors = <Color>[
      Color(0xFF27806E),
      Color(0xFFD27A36),
      Color(0xFF6756A5),
    ];
    return colors[index % colors.length];
  }

  Widget _buildTimelineCard() {
    final bool isCompleted = order.status == 'completed' ||
        order.backendStatus == 'completed';

    final List<BuyerOrderTimelineEvent> events = order.timeline.isNotEmpty
        ? order.timeline
        : order.isPreview
        ? <BuyerOrderTimelineEvent>[
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
          ]
        : <BuyerOrderTimelineEvent>[
            BuyerOrderTimelineEvent(
              label: order.statusLabel.trim().isEmpty
                  ? 'Order update'
                  : order.statusLabel,
              time: order.createdAt == null
                  ? ''
                  : _formatTrackingTime(order.createdAt!),
              done: true,
              details: order.tracking?.trim().isNotEmpty == true
                  ? 'Parcel tracking updates will appear here as they become available.'
                  : 'Shipment location will appear once the parcel is dispatched.',
            ),
          ];
    final List<BuyerOrderTimelineEvent> newestFirstEvents = events.reversed
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: ShopColors.border),
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
          ...List<Widget>.generate(newestFirstEvents.length, (int index) {
            final BuyerOrderTimelineEvent event = newestFirstEvents[index];
            final bool isLast = index == newestFirstEvents.length - 1;
            final bool isLatest = index == 0;
            final String eventLabel = event.label.toLowerCase();
            final bool isDeliveredEvent =
                eventLabel.contains('delivered') ||
                eventLabel.contains('delivery success') ||
                eventLabel.contains('delivery successful') ||
                eventLabel.contains('delivery complete');
            final bool deliveryComplete =
                const <String>{
                  'delivered',
                  'completed',
                  'complete',
                  'delivery_success',
                  'delivery_successful',
                  'delivery_completed',
                }.contains(order.normalizedStatus);
            final bool showProofButton = index == 0 &&
                (isDeliveredEvent || deliveryComplete);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                SizedBox(
                  width: 84,
                  child: Text(
                    event.time,
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                SizedBox(
                  width: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: isLatest
                              ? _timelineActive
                              : _timelineInactive,
                          shape: BoxShape.circle,
                        ),
                      ),
                      if (!isLast)
                        Container(
                          width: 2,
                          height: showProofButton
                              ? (event.details.trim().isEmpty ? 64 : 96)
                              : event.details.trim().isEmpty
                              ? 34
                              : 54,
                          color: const Color(0xFFE1E1E1),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(top: 0, bottom: isLast ? 0 : 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timelineDescription(event),
                          style: TextStyle(
                            color: isLatest
                                ? _timelineActive
                                : const Color(0xFF858585),
                            fontSize: 14,
                            height: 1.35,
                            fontWeight: isLatest
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        if (showProofButton) ...[
                          const SizedBox(height: 2),
                          TextButton(
                            onPressed: _openDeliveryProof,
                            child: const Text('View Proof of Delivery'),
                            style: TextButton.styleFrom(
                              foregroundColor: _proofLink,
                              alignment: Alignment.centerLeft,
                              padding: EdgeInsets.zero,
                            ),
                          ),
                        ],
                      ],
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

  Future<void> _openDeliveryProof() async {
    if (order.deliveryProofImageUrls.isEmpty) {
      await _loadDeliveryProof(force: true);
    }
    if (!mounted) return;

    final List<String> imageUrls = order.deliveryProofImageUrls;
    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Proof of delivery is not available from the server.'),
        ),
      );
      return;
    }

    await _showDeliveryProof(imageUrls);
  }

  Future<void> _showDeliveryProof(List<String> imageUrls) async {
    if (imageUrls.isEmpty || !mounted) return;

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final double height = MediaQuery.sizeOf(dialogContext).height;
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.maxFinite,
            height: height * 0.78,
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
                  child: Row(
                    children: <Widget>[
                      const Expanded(
                        child: Text(
                          'Proof of delivery',
                          style: TextStyle(
                            color: _text,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () => Navigator.of(dialogContext).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    itemCount: imageUrls.length,
                    itemBuilder: (BuildContext context, int index) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Center(
                          child: Image.network(
                            imageUrls[index],
                            fit: BoxFit.contain,
                            loadingBuilder:
                                (
                                  BuildContext context,
                                  Widget child,
                                  ImageChunkEvent? progress,
                                ) {
                                  if (progress == null) return child;
                                  return const Center(
                                    child: CircularProgressIndicator(),
                                  );
                                },
                            errorBuilder:
                                (
                                  BuildContext context,
                                  Object error,
                                  StackTrace? stackTrace,
                                ) => const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Unable to load the proof image.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                if (imageUrls.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Swipe to view ${imageUrls.length} proof photos',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMapboxMapCreated(mapbox.MapboxMap map) async {
    _mapboxMap = map;
    _mapMarkers = await map.annotations.createCircleAnnotationManager();
    _routeLabels = await map.annotations.createPointAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    _circleAnnotations = <mapbox.CircleAnnotation>[];
    _pointAnnotations = <mapbox.PointAnnotation>[];
    _renderedMapMarkers = <_TrackingMapMarkerSpec>[];
    _roadRouteLine = null;
    await _syncMapboxMarkers();
  }

  Future<void> _syncMapboxMarkers({bool recenter = true}) async {
    if (_mapboxMap == null || _mapMarkers == null || _routeLabels == null) {
      return;
    }
    if (_syncingMapAnnotations) {
      _mapSyncQueued = true;
      _queuedMapSyncRecenters = _queuedMapSyncRecenters || recenter;
      return;
    }

    _syncingMapAnnotations = true;
    var shouldRecenter = recenter;
    try {
      while (mounted) {
        _mapSyncQueued = false;
        _queuedMapSyncRecenters = false;
        await _syncMapboxMarkersOnce(recenter: shouldRecenter);
        if (!mounted || !_mapSyncQueued) break;
        shouldRecenter = _queuedMapSyncRecenters;
      }
    } catch (error) {
      // Keep the existing map visible and let the next location refresh retry.
      if (kDebugMode) debugPrint('Order tracking map update failed: $error');
    } finally {
      _syncingMapAnnotations = false;
    }
  }

  List<_TrackingMapMarkerSpec> _buildMapMarkerSpecs() {
    return _locations.map((_location) {
      final BuyerOrderLocation location = _location;
      final bool isRider = order.riderLocation != null &&
          location.latitude == order.riderLocation!.latitude &&
          location.longitude == order.riderLocation!.longitude;
      final bool isSeller = order.sellerLocation != null &&
          location.latitude == order.sellerLocation!.latitude &&
          location.longitude == order.sellerLocation!.longitude;
      final bool isDestination = order.orderLocation != null &&
          location.latitude == order.orderLocation!.latitude &&
          location.longitude == order.orderLocation!.longitude;
      final int stopIndex = order.shipmentRouteStops.indexWhere(
        (BuyerOrderLocation stop) =>
            stop.latitude == location.latitude &&
            stop.longitude == location.longitude,
      );
      final Color markerColor = isRider
          ? const Color(0xFF1976D2)
          : isSeller
          ? const Color(0xFFB56B32)
          : isDestination
          ? _maroon
          : _routeStopColor(stopIndex < 0 ? 0 : stopIndex);
      return _TrackingMapMarkerSpec(
        latitude: location.latitude,
        longitude: location.longitude,
        color: markerColor.toARGB32(),
        radius: isRider ? 10 : 11,
        isRider: isRider,
        label: isRider ? 'Current rider' : location.label,
      );
    }).toList(growable: false);
  }

  Future<void> _syncMapboxMarkersOnce({required bool recenter}) async {
    final mapbox.MapboxMap? map = _mapboxMap;
    final mapbox.CircleAnnotationManager? manager = _mapMarkers;
    final mapbox.PointAnnotationManager? labels = _routeLabels;

    if (map == null || manager == null || labels == null) {
      return;
    }

    final List<_TrackingMapMarkerSpec> specs = _buildMapMarkerSpecs();
    final bool canUpdateExisting =
        _circleAnnotations.length == specs.length &&
        _pointAnnotations.length == specs.length &&
        _renderedMapMarkers.length == specs.length;

    if (!canUpdateExisting) {
      await manager.deleteAll();
      if (!mounted || !identical(_mapboxMap, map)) return;
      await labels.deleteAll();
      if (!mounted || !identical(_mapboxMap, map)) return;

      // Clear cached IDs before creating replacements so a failed platform
      // call can safely retry on the next location update.
      _circleAnnotations = <mapbox.CircleAnnotation>[];
      _pointAnnotations = <mapbox.PointAnnotation>[];
      _renderedMapMarkers = <_TrackingMapMarkerSpec>[];

      final List<mapbox.CircleAnnotationOptions> circleOptions = specs
          .map(
            (_TrackingMapMarkerSpec spec) => mapbox.CircleAnnotationOptions(
              geometry: _toMapboxPoint(
                LatLng(spec.latitude, spec.longitude),
              ),
              circleColor: spec.color,
              circleRadius: spec.radius,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 3,
              circleSortKey: spec.isRider ? 3 : 2,
            ),
          )
          .toList(growable: false);
      final List<mapbox.PointAnnotationOptions> pointOptions = specs
          .map(
            (_TrackingMapMarkerSpec spec) => mapbox.PointAnnotationOptions(
              geometry: _toMapboxPoint(
                LatLng(spec.latitude, spec.longitude),
              ),
              textField: spec.label,
              textAnchor: mapbox.TextAnchor.BOTTOM,
              textOffset: <double?>[0, -0.7],
              textSize: 11,
              textColor: const Color(0xFF342E2E).toARGB32(),
              textHaloColor: Colors.white.toARGB32(),
              textHaloWidth: 2,
              symbolSortKey: 10,
            ),
          )
          .toList(growable: false);
      final List<mapbox.CircleAnnotation?> createdCircles =
          await manager.createMulti(circleOptions);
      if (!mounted || !identical(_mapboxMap, map)) return;
      final List<mapbox.PointAnnotation?> createdLabels =
          await labels.createMulti(pointOptions);
      if (!mounted || !identical(_mapboxMap, map)) return;
      _circleAnnotations = createdCircles
          .whereType<mapbox.CircleAnnotation>()
          .toList(growable: false);
      _pointAnnotations = createdLabels
          .whereType<mapbox.PointAnnotation>()
          .toList(growable: false);
      _renderedMapMarkers = specs;
    } else {
      for (int index = 0; index < specs.length; index++) {
        final _TrackingMapMarkerSpec previous = _renderedMapMarkers[index];
        final _TrackingMapMarkerSpec next = specs[index];
        final bool geometryChanged = previous.latitude != next.latitude ||
            previous.longitude != next.longitude;
        final mapbox.Point geometry = _toMapboxPoint(
          LatLng(next.latitude, next.longitude),
        );

        if (geometryChanged ||
            previous.color != next.color ||
            previous.radius != next.radius) {
          final mapbox.CircleAnnotation annotation =
              _circleAnnotations[index];
          annotation.geometry = geometry;
          annotation.circleColor = next.color;
          annotation.circleRadius = next.radius;
          annotation.circleSortKey = next.isRider ? 3 : 2;
          await manager.update(annotation);
          if (!mounted || !identical(_mapboxMap, map)) return;
        }

        if (geometryChanged || previous.label != next.label) {
          final mapbox.PointAnnotation annotation = _pointAnnotations[index];
          annotation.geometry = geometry;
          annotation.textField = next.label;
          await labels.update(annotation);
          if (!mounted || !identical(_mapboxMap, map)) return;
        }
      }
      _renderedMapMarkers = specs;
    }

    if (recenter) {
      _lastMapCenter = _center;
      _zoomLevel = _locations.isEmpty ? 11 : 14;
      if (_locations.length > 1) {
        final mapbox.CameraOptions camera = await map.cameraForCoordinatesPadding(
          _locations
              .map(
                (BuyerOrderLocation location) => _toMapboxPoint(
                  LatLng(location.latitude, location.longitude),
                ),
              )
              .toList(growable: false),
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

    unawaited(_syncRoadRouteSafely());
  }

  Future<void> _syncRoadRouteSafely() async {
    try {
      await _syncRoadRoute();
    } catch (error) {
      if (kDebugMode) debugPrint('Order tracking route update failed: $error');
    }
  }

  Future<void> _syncRoadRoute() async {
    final mapbox.PolylineAnnotationManager? manager = _routeLines;
    final BuyerOrderLocation? rider = order.riderLocation;
    final BuyerOrderLocation? destination = order.orderLocation;
    if (manager == null) return;
    final bool delivered = const <String>{'delivered', 'completed', 'complete'}
        .contains(order.normalizedStatus);
    final bool riderIsRouteStop = rider != null &&
        (order.shipmentRouteStops.isEmpty || !delivered);
    String coordinateKey(BuyerOrderLocation location) =>
        '${location.latitude},${location.longitude}';
    final String topologyKey = <String>[
      if (order.sellerLocation != null)
        'seller:${coordinateKey(order.sellerLocation!)}',
      ...order.shipmentRouteStops.map(
        (BuyerOrderLocation stop) => 'hub:${coordinateKey(stop)}',
      ),
      'rider:$riderIsRouteStop',
      if (destination != null) 'buyer:${coordinateKey(destination)}',
    ].join('|');
    final List<BuyerOrderLocation> routeStops = <BuyerOrderLocation>[
      if (order.sellerLocation != null) order.sellerLocation!,
      if (order.shipmentRouteStops.isEmpty && rider != null) rider,
      ...order.shipmentRouteStops,
      if (order.shipmentRouteStops.isNotEmpty && riderIsRouteStop) rider,
      if (destination != null) destination,
    ];
    final List<BuyerOrderLocation> routePoints = <BuyerOrderLocation>[];
    for (final BuyerOrderLocation stop in routeStops) {
      if (!routePoints.any(
        (BuyerOrderLocation existing) =>
            existing.latitude == stop.latitude &&
            existing.longitude == stop.longitude,
      )) {
        routePoints.add(stop);
      }
    }
    if (routePoints.length < 2 || _mapboxAccessToken.isEmpty) {
      final mapbox.PolylineAnnotation? routeLine = _roadRouteLine;
      if (routeLine != null) {
        await manager.delete(routeLine);
        _roadRouteLine = null;
      }
      _lastRouteTopologyKey = topologyKey;
      _lastRouteOrigin = null;
      _lastRouteRequestAt = null;
      if (mounted &&
          (_roadDistanceMeters != null ||
              _roadDurationSeconds != null ||
              _roadRouteUnavailable)) {
        setState(() {
          _roadDistanceMeters = null;
          _roadDurationSeconds = null;
          _roadRouteUnavailable = false;
        });
      }
      return;
    }

    final BuyerOrderLocation routeStart = rider ?? routePoints.first;
    final LatLng requestOrigin =
        LatLng(routeStart.latitude, routeStart.longitude);
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequestAt = _lastRouteRequestAt;
    final bool topologyChanged = _lastRouteTopologyKey != topologyKey;
    final bool routeIntervalElapsed = previousRequestAt == null ||
        DateTime.now().difference(previousRequestAt) >=
            _minimumRouteRefreshInterval;
    final bool riderMovedEnough = previousOrigin == null ||
        Geolocator.distanceBetween(
              previousOrigin.latitude,
              previousOrigin.longitude,
              requestOrigin.latitude,
              requestOrigin.longitude,
            ) >=
            _minimumRerouteDistanceMeters;
    if (_routeRequestInProgress ||
        (!topologyChanged && !routeIntervalElapsed && !riderMovedEnough)) {
      return;
    }

    _routeRequestInProgress = true;
    _lastRouteOrigin = requestOrigin;
    _lastRouteRequestAt = DateTime.now();
    _lastRouteTopologyKey = topologyKey;
    final String coordinates = routePoints
        .map(
          (BuyerOrderLocation stop) =>
              '${stop.longitude},${stop.latitude}',
        )
        .join(';');
    try {
      final Response<Map<String, dynamic>> response =
          await _directionsClient.get(
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
      final Map<String, dynamic> routeGeometryData =
          Map<String, dynamic>.from(route['geometry'] as Map);
      final List<dynamic> rawCoordinates =
          routeGeometryData['coordinates'] as List<dynamic>? ??
              const <dynamic>[];
      final List<mapbox.Position> positions = rawCoordinates
          .whereType<List<dynamic>>()
          .where((List<dynamic> pair) => pair.length >= 2)
          .map((List<dynamic> pair) => mapbox.Position(
                (pair[0] as num).toDouble(),
                (pair[1] as num).toDouble(),
              ))
          .toList(growable: false);
      if (positions.length < 2) {
        throw StateError('The driving route was incomplete.');
      }

      final mapbox.LineString routeLineGeometry =
          mapbox.LineString(coordinates: positions);
      final mapbox.PolylineAnnotation? currentLine = _roadRouteLine;
      if (currentLine == null) {
        _roadRouteLine = await manager.create(
          mapbox.PolylineAnnotationOptions(
            geometry: routeLineGeometry,
            lineColor: _maroon.toARGB32(),
            lineWidth: 5,
            lineOpacity: 0.85,
            lineBorderColor: Colors.white.toARGB32(),
            lineBorderWidth: 1.5,
          ),
        );
      } else {
        currentLine.geometry = routeLineGeometry;
        await manager.update(currentLine);
      }
      if (!mounted) return;

      final double? distance = (route['distance'] as num?)?.toDouble();
      final double? duration = (route['duration'] as num?)?.toDouble();
      if (_roadDistanceMeters != distance ||
          _roadDurationSeconds != duration ||
          _roadRouteUnavailable) {
        setState(() {
          _roadDistanceMeters = distance;
          _roadDurationSeconds = duration;
          _roadRouteUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted && !_roadRouteUnavailable) {
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

class _TrackingMapMarkerSpec {
  const _TrackingMapMarkerSpec({
    required this.latitude,
    required this.longitude,
    required this.color,
    required this.radius,
    required this.isRider,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final int color;
  final double radius;
  final bool isRider;
  final String label;
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
          style: const TextStyle(fontSize: 11, color: ShopColors.muted),
        ),
      ],
    );
  }
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;

import '../../../core/api/api_client.dart';
import '../../../services/buyer_mobile_service.dart';
import '../../../shared/widgets/shop_ui.dart';

class BuyerPublicTrackingScreen extends StatefulWidget {
  final String initialTrackingNumber;
  final VoidCallback? onBack;

  const BuyerPublicTrackingScreen({
    super.key,
    this.initialTrackingNumber = '',
    this.onBack,
  });

  @override
  State<BuyerPublicTrackingScreen> createState() =>
      _BuyerPublicTrackingScreenState();
}

class _BuyerPublicTrackingScreenState extends State<BuyerPublicTrackingScreen> {
  static const Duration _refreshInterval = Duration(seconds: 30);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _trackingNumber;
  Timer? _refreshTimer;
  maplibre.MapLibreSession? _map;
  maplibre.PointAnnotationManager? _mapPoints;
  maplibre.CircleAnnotationManager? _mapCircles;
  maplibre.PolylineAnnotationManager? _routeLines;
  maplibre.PolylineAnnotation? _routeLine;
  String? _roadRouteSignature;
  bool _roadRouteRequestInProgress = false;
  Map<String, dynamic>? _tracking;
  String? _activeTrackingNumber;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _trackingNumber = TextEditingController(text: widget.initialTrackingNumber);
    if (widget.initialTrackingNumber.trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _lookup());
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _trackingNumber.dispose();
    super.dispose();
  }

  Future<void> _lookup() async {
    if (!(_formKey.currentState?.validate() ?? false) || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final String trackingNumber = _trackingNumber.text.trim();
      final Map<String, dynamic> result =
          await BuyerMobileService.fetchPublicTracking(trackingNumber);
      if (mounted) {
        setState(() => _tracking = result);
        _activeTrackingNumber = trackingNumber;
        _startRefreshTimer();
        unawaited(_syncMapMarkers());
      }
    } catch (error) {
      if (mounted) {
        _activeTrackingNumber = null;
        _refreshTimer?.cancel();
        setState(() {
          _tracking = null;
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _startRefreshTimer() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(_refreshInterval, (_) {
      unawaited(_refreshTracking());
    });
  }

  Future<void> _refreshTracking() async {
    final String trackingNumber = _activeTrackingNumber ?? '';
    if (_loading || _tracking == null || trackingNumber.isEmpty) return;
    try {
      final Map<String, dynamic> result =
          await BuyerMobileService.fetchPublicTracking(trackingNumber);
      if (!mounted || trackingNumber != _activeTrackingNumber) return;
      setState(() {
        _tracking = result;
        _error = null;
      });
      await _syncMapMarkers();
    } catch (_) {
      // Keep the last successful status visible while a refresh is offline.
    }
  }

  bool get _supportsNativeMap =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  static const Map<String, String> _timelineLabels = <String, String>{
    'PLACED': 'Order placed',
    'CONFIRMED': 'Seller confirmed order',
    'PREPARING': 'Preparing parcel',
    'READY_FOR_PICKUP': 'Ready for pickup',
    'PICKUP_ASSIGNED': 'Pickup rider assigned',
    'PICKED_UP': 'Picked up from seller',
    'AT_SORTING_CENTER': 'Arrived at sorting center',
    'SORTED': 'Sorted by destination',
    'ASSIGNED_TO_RIDER': 'Delivery rider assigned',
    'OUT_FOR_DELIVERY': 'Out for delivery',
    'DELIVERY_FAILED': 'Delivery attempt unsuccessful',
    'DELIVERED': 'Delivered',
    'COMPLETED': 'Buyer confirmed receipt',
    'RETURNED': 'Parcel returned',
    'CANCELLED': 'Order cancelled',
  };

  List<Map<String, dynamic>> _trackingTimelineEvents(
    Map<String, dynamic> tracking,
  ) {
    final List<Map<String, dynamic>> rows = <Map<String, dynamic>>[];
    final Set<String> representedStatuses = <String>{};
    String? previousStatus;
    String? previousLabel;

    for (final Map<String, dynamic> event in _maps(tracking['events'])) {
      final String notes = (event['notes'] ?? '').toString();
      final bool isCancellation =
          notes.startsWith('BUYER_ORDER_CANCELLED:') ||
          notes.startsWith('SELLER_ORDER_CANCELLED:');
      final String status = isCancellation
          ? 'CANCELLED'
          : (event['status'] ?? '').toString().trim().toUpperCase();
      final String? standardLabel = _timelineLabels[status];
      if (standardLabel == null) continue;

      final String label =
          status == 'COMPLETED' &&
              notes.startsWith(
                'Order automatically confirmed received after 3 days',
              )
          ? 'Automatically confirmed receipt'
          : standardLabel;
      if (previousStatus == status && previousLabel == label) continue;

      rows.add(<String, dynamic>{
        ...event,
        'status': status,
        'label': label,
        if (isCancellation) 'notes': '',
      });
      previousStatus = status;
      previousLabel = label;
      representedStatuses.add(status);
    }

    final String currentStatus = (tracking['current_status'] ?? '')
        .toString()
        .trim()
        .toUpperCase();
    final String? currentLabel = _timelineLabels[currentStatus];
    if (currentLabel != null &&
        !representedStatuses.contains(currentStatus) &&
        !representedStatuses.contains('CANCELLED')) {
      rows.insert(0, <String, dynamic>{
        'status': currentStatus,
        'label': currentLabel,
        'occurred_at': '',
        'notes': '',
      });
    }

    return rows;
  }

  Future<void> _onMapCreated(maplibre.MapLibreSession map) async {
    _map = map;
    _mapPoints = await map.annotations.createPointAnnotationManager();
    _mapCircles = await map.annotations.createCircleAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    _routeLine = null;
    _roadRouteSignature = null;
    await _syncMapMarkers();
  }

  maplibre.Point _mapPoint(double latitude, double longitude) =>
      maplibre.Point(coordinates: maplibre.Position(longitude, latitude));

  List<Map<String, dynamic>> _orderedMapMarkers(dynamic rawMarkers) {
    final List<Map<String, dynamic>> markers = _maps(rawMarkers)
        .where(
          (Map<String, dynamic> marker) =>
              double.tryParse((marker['latitude'] ?? '').toString()) != null &&
              double.tryParse((marker['longitude'] ?? '').toString()) != null,
        )
        .toList(growable: false);
    final List<Map<String, dynamic>> sellers = markers
        .where(
          (Map<String, dynamic> marker) =>
              marker['target_kind'] == 'seller' || marker['kind'] == 'seller',
        )
        .toList(growable: false);
    final List<Map<String, dynamic>> hubs = markers
        .where(
          (Map<String, dynamic> marker) =>
              marker['kind'] == 'center' ||
              marker['target_kind'] == 'logistics',
        )
        .toList(growable: true);
    hubs.sort((Map<String, dynamic> first, Map<String, dynamic> second) {
      int rank(Map<String, dynamic> marker) {
        final int sequence =
            int.tryParse((marker['sequence_no'] ?? '').toString()) ?? 0;
        final int roleRank;
        switch (marker['center_role']?.toString()) {
          case 'origin':
            roleRank = 0;
            break;
          case 'destination':
            roleRank = 1;
            break;
          default:
            roleRank = 2;
        }
        return sequence * 3 + roleRank;
      }

      return rank(first).compareTo(rank(second));
    });
    final List<Map<String, dynamic>> destinations = markers
        .where(
          (Map<String, dynamic> marker) =>
              marker['target_kind'] == 'buyer' ||
              marker['kind'] == 'destination',
        )
        .toList(growable: false);
    final List<Map<String, dynamic>> riders = markers
        .where((Map<String, dynamic> marker) => marker['kind'] == 'rider')
        .toList(growable: false);

    final List<Map<String, dynamic>> ordered = <Map<String, dynamic>>[
      ...sellers,
      ...hubs,
      ...destinations,
      ...riders,
    ];
    final Set<String> seen = <String>{};
    return ordered
        .where((Map<String, dynamic> marker) {
          final String id = (marker['id'] ?? '').toString();
          return id.isEmpty || seen.add(id);
        })
        .toList(growable: false);
  }

  Color _mapMarkerColor(Map<String, dynamic> marker) {
    if (marker['kind'] == 'rider') return const Color(0xFF1976D2);
    if (marker['target_kind'] == 'seller' || marker['kind'] == 'seller') {
      return const Color(0xFFB56B32);
    }
    if (marker['target_kind'] == 'buyer' || marker['kind'] == 'destination') {
      return ShopColors.accent;
    }
    return const Color(0xFF27806E);
  }

  Future<void> _syncMapMarkers() async {
    final maplibre.PointAnnotationManager? manager = _mapPoints;
    final maplibre.CircleAnnotationManager? circleManager = _mapCircles;
    final maplibre.MapLibreSession? map = _map;
    final Map<String, dynamic>? current = _tracking;
    if (manager == null ||
        circleManager == null ||
        map == null ||
        current == null)
      return;
    final List<Map<String, dynamic>> markers = _orderedMapMarkers(
      current['map_markers'] ?? current['markers'],
    );
    await manager.deleteAll();
    await circleManager.deleteAll();
    if (!mounted || !identical(_map, map)) return;
    if (markers.isEmpty) return;
    final List<maplibre.PointAnnotationOptions> options = markers
        .map(
          (Map<String, dynamic> marker) => maplibre.PointAnnotationOptions(
            geometry: _mapPoint(
              double.parse(marker['latitude'].toString()),
              double.parse(marker['longitude'].toString()),
            ),
            textField: (marker['label'] ?? 'Logistics center').toString(),
            textAnchor: maplibre.TextAnchor.bottom,
            textOffset: <double?>[0, -0.7],
            textSize: 11,
            textColor: const Color(0xFF342E2E).toARGB32(),
            textHaloColor: Colors.white.toARGB32(),
            textHaloWidth: 2,
          ),
        )
        .toList(growable: false);
    final List<maplibre.CircleAnnotationOptions> circles = markers
        .map(
          (Map<String, dynamic> marker) => maplibre.CircleAnnotationOptions(
            geometry: _mapPoint(
              double.parse(marker['latitude'].toString()),
              double.parse(marker['longitude'].toString()),
            ),
            circleColor: _mapMarkerColor(marker).toARGB32(),
            circleRadius: 7,
            circleStrokeColor: Colors.white.toARGB32(),
            circleStrokeWidth: 3,
          ),
        )
        .toList(growable: false);
    await circleManager.createMulti(circles);
    await manager.createMulti(options);
    unawaited(_syncRoadRoute(markers));
    final List<maplibre.Point> points = markers
        .map(
          (Map<String, dynamic> marker) => _mapPoint(
            double.parse(marker['latitude'].toString()),
            double.parse(marker['longitude'].toString()),
          ),
        )
        .toList(growable: false);
    if (points.length > 1) {
      final maplibre.CameraOptions camera = await map
          .cameraForCoordinatesPadding(
            points,
            maplibre.CameraOptions(
              padding: maplibre.MbxEdgeInsets(
                top: 48,
                left: 48,
                bottom: 48,
                right: 48,
              ),
            ),
            null,
            6,
            null,
          );
      await map.setCamera(camera);
    } else {
      await map.setCamera(
        maplibre.CameraOptions(center: points.first, zoom: 9),
      );
    }
  }

  Future<void> _syncRoadRoute(List<Map<String, dynamic>> markers) async {
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    if (manager == null) return;
    final List<maplibre.Position> coordinates = <maplibre.Position>[];
    for (final Map<String, dynamic> marker in markers) {
      if (marker['kind'] == 'rider' ||
          !(marker['kind'] == 'seller' ||
              marker['kind'] == 'center' ||
              marker['kind'] == 'destination' ||
              marker['target_kind'] == 'seller' ||
              marker['target_kind'] == 'logistics' ||
              marker['target_kind'] == 'buyer')) {
        continue;
      }
      final double? latitude = double.tryParse(
        (marker['latitude'] ?? '').toString(),
      );
      final double? longitude = double.tryParse(
        (marker['longitude'] ?? '').toString(),
      );
      if (latitude == null || longitude == null) continue;
      if (coordinates.any(
        (maplibre.Position position) =>
            position.lat.toDouble() == latitude &&
            position.lng.toDouble() == longitude,
      )) {
        continue;
      }
      coordinates.add(maplibre.Position(longitude, latitude));
    }

    final String signature = coordinates
        .map((maplibre.Position position) => '${position.lng},${position.lat}')
        .join(';');
    if (coordinates.length < 2) {
      final maplibre.PolylineAnnotation? previous = _routeLine;
      if (previous != null) {
        await manager.delete(previous);
        _routeLine = null;
      }
      _roadRouteSignature = signature;
      return;
    }
    if (_roadRouteRequestInProgress ||
        (signature == _roadRouteSignature && _routeLine != null)) {
      return;
    }

    _roadRouteRequestInProgress = true;
    try {
      final Response<dynamic> response = await ApiClient.get(
        'maps/route',
        queryParameters: <String, dynamic>{'waypoints': signature},
      );
      if (!mounted || !identical(manager, _routeLines)) return;
      final Map<String, dynamic> payload = response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : <String, dynamic>{};
      final List<dynamic> routes = payload['routes'] is List
          ? List<dynamic>.from(payload['routes'] as List)
          : <dynamic>[];
      if (routes.isEmpty || routes.first is! Map) return;
      final Map<String, dynamic> route = Map<String, dynamic>.from(
        routes.first as Map,
      );
      final dynamic rawGeometry = route['geometry'];
      final Map<String, dynamic> geometryData = rawGeometry is Map
          ? Map<String, dynamic>.from(rawGeometry)
          : <String, dynamic>{};
      final List<dynamic> rawPoints = geometryData['coordinates'] is List
          ? List<dynamic>.from(geometryData['coordinates'] as List)
          : <dynamic>[];
      final List<maplibre.Position> routePoints = rawPoints
          .whereType<List<dynamic>>()
          .where((List<dynamic> point) => point.length >= 2)
          .map(
            (List<dynamic> point) => maplibre.Position(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
          )
          .toList(growable: false);
      if (routePoints.length < 2) return;

      final maplibre.LineString routeLineGeometry = maplibre.LineString(
        coordinates: routePoints,
      );
      final maplibre.PolylineAnnotation? previous = _routeLine;
      if (previous == null) {
        _routeLine = await manager.create(
          maplibre.PolylineAnnotationOptions(
            geometry: routeLineGeometry,
            lineColor: ShopColors.accent.toARGB32(),
            lineWidth: 4,
            lineOpacity: 0.85,
            lineBorderColor: Colors.white.toARGB32(),
            lineBorderWidth: 1.5,
          ),
        );
      } else {
        previous.geometry = routeLineGeometry;
        previous.lineColor = ShopColors.accent.toARGB32();
        previous.lineWidth = 4;
        previous.lineOpacity = 0.85;
        await manager.update(previous);
      }
      _roadRouteSignature = signature;
    } catch (_) {
      // The saved seller, hub, and buyer locations remain visible if routing fails.
    } finally {
      _roadRouteRequestInProgress = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ShopColors.canvas,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            ShopPageHeader(
              title: 'Track a shipment',
              subtitle: 'Enter the tracking number from your order.',
              onBack: widget.onBack,
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: _refreshTracking,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                  children: <Widget>[
                    Form(
                      key: _formKey,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Expanded(
                            child: TextFormField(
                              controller: _trackingNumber,
                              textInputAction: TextInputAction.search,
                              onFieldSubmitted: (_) => _lookup(),
                              decoration: const InputDecoration(
                                labelText: 'Tracking number',
                                hintText: 'Enter tracking number',
                                prefixIcon: Icon(Icons.local_shipping_outlined),
                                border: OutlineInputBorder(),
                              ),
                              validator: (String? value) =>
                                  value == null || value.trim().isEmpty
                                  ? 'Enter a tracking number.'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 56,
                            child: FilledButton(
                              onPressed: _loading ? null : _lookup,
                              child: _loading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.search_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_error != null) ...<Widget>[
                      const SizedBox(height: 12),
                      _infoCard(
                        const Icon(
                          Icons.error_outline,
                          color: Color(0xFFB42318),
                        ),
                        _error!,
                      ),
                    ],
                    if (_tracking != null) ...<Widget>[
                      const SizedBox(height: 14),
                      _buildTracking(_tracking!),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTracking(Map<String, dynamic> tracking) {
    final List<Map<String, dynamic>> events = _trackingTimelineEvents(tracking);
    final List<Map<String, dynamic>> attempts = _maps(
      tracking['delivery_attempts'],
    );
    final dynamic rawDestination = tracking['destination'];
    final Map<String, dynamic> destination = rawDestination is Map
        ? Map<String, dynamic>.from(rawDestination)
        : <String, dynamic>{};
    final String destinationLabel = <String>[
      (destination['municipality'] ?? '').toString(),
      (destination['province'] ?? '').toString(),
    ].where((String value) => value.trim().isNotEmpty).join(', ');
    final String shipmentContext = <String>[
      if ((tracking['order_number'] ?? '').toString().trim().isNotEmpty)
        'Order ${tracking['order_number']}',
      if ((tracking['seller_name'] ?? '').toString().trim().isNotEmpty)
        'Seller ${tracking['seller_name']}',
      if (destinationLabel.isNotEmpty) 'Destination $destinationLabel',
    ].join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _infoCard(
          const Icon(Icons.local_shipping_rounded, color: ShopColors.accent),
          'Tracking ${tracking['tracking_number'] ?? _trackingNumber.text.trim()}\n${_status(tracking['current_status'])}${shipmentContext.isEmpty ? '' : '\n$shipmentContext'}',
        ),
        if ((tracking['guidance'] ?? '').toString().isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _infoCard(
            const Icon(Icons.info_outline_rounded, color: ShopColors.accent),
            '${tracking['guidance']}\nNext update: ${tracking['next_actor'] ?? 'Logistics team'}',
          ),
        ],
        const SizedBox(height: 12),
        _buildRouteMap(tracking),
        const SizedBox(height: 12),
        _section(
          'Shipment updates',
          events.isEmpty
              ? const <Widget>[
                  Text(
                    'No tracking updates yet.',
                    style: TextStyle(color: ShopColors.muted),
                  ),
                ]
              : events
                    .map(
                      (Map<String, dynamic> event) => _timelineRow(
                        (event['label'] ?? _status(event['status'])).toString(),
                        event['occurred_at']?.toString() ?? '',
                        event['notes']?.toString() ?? '',
                      ),
                    )
                    .toList(growable: false),
        ),
        if (attempts.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _section(
            'Delivery attempts',
            attempts
                .map(
                  (Map<String, dynamic> attempt) => _timelineRow(
                    'Attempt ${attempt['attempt_number'] ?? ''}: ${_status(attempt['status'])}',
                    attempt['attempted_at']?.toString() ?? '',
                    attempt['failure_reason']?.toString() ?? '',
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildRouteMap(Map<String, dynamic> tracking) {
    final List<Map<String, dynamic>> markers = _orderedMapMarkers(
      tracking['map_markers'] ?? tracking['markers'],
    );
    final bool hasCoordinates = markers.isNotEmpty;
    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: ShopColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(15, 12, 15, 8),
            child: Text(
              'Logistics route map',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            child: !_supportsNativeMap
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        hasCoordinates
                            ? markers
                                  .map(
                                    (Map<String, dynamic> marker) =>
                                        marker['label'] ?? 'Logistics center',
                                  )
                                  .join('  →  ')
                            : 'Map points will appear when the parcel is routed through a logistics center.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                : hasCoordinates
                ? maplibre.MapLibreMapWidget(
                    key: ValueKey<String>(
                      (tracking['tracking_number'] ?? '').toString(),
                    ),
                    viewport: maplibre.MapLibreViewport(
                      center: _mapPoint(
                        double.parse(markers.first['latitude'].toString()),
                        double.parse(markers.first['longitude'].toString()),
                      ),
                      zoom: markers.length == 1 ? 9 : 6,
                    ),
                    onMapCreated: _onMapCreated,
                  )
                : const Center(
                    child: Text(
                      'Map points will appear when the parcel is routed through a logistics center.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: ShopColors.muted, fontSize: 12),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ShopColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );

  Widget _timelineRow(String title, String time, String notes) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(top: 4),
          child: Icon(Icons.circle, size: 8, color: ShopColors.accent),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              if (notes.isNotEmpty)
                Text(
                  notes,
                  style: const TextStyle(color: ShopColors.muted, fontSize: 12),
                ),
              if (time.isNotEmpty)
                Text(
                  time,
                  style: const TextStyle(color: ShopColors.muted, fontSize: 10),
                ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _infoCard(Widget icon, String text) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: ShopColors.border),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        icon,
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );

  List<Map<String, dynamic>> _maps(dynamic value) => value is List
      ? value
            .whereType<Map>()
            .map((Map row) => Map<String, dynamic>.from(row))
            .toList(growable: false)
      : <Map<String, dynamic>>[];

  String _status(dynamic value) => (value ?? 'Pending')
      .toString()
      .replaceAll('_', ' ')
      .toLowerCase()
      .split(' ')
      .where((String word) => word.isNotEmpty)
      .map((String word) => '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
}

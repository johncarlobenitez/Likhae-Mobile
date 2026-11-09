import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;

import '../../../core/api/api_client.dart';
import '../../../core/config/app_config.dart';
import '../../../core/theme/app_theme.dart';
import '../../../services/rider_mobile_service.dart';
import 'rider_delivery_models.dart';

class RiderDeliveryNavigationScreen extends StatefulWidget {
  final RiderDeliveryData delivery;
  final LatLng? destination;

  const RiderDeliveryNavigationScreen({
    super.key,
    required this.delivery,
    required this.destination,
  });

  @override
  State<RiderDeliveryNavigationScreen> createState() =>
      _RiderDeliveryNavigationScreenState();
}

class _RiderDeliveryNavigationScreenState
    extends State<RiderDeliveryNavigationScreen> {
  static const Color _routeColor = Color(0xFF7A2A22);
  static const Color _riderColor = Color(0xFF1976D2);
  static const Color _surface = Color(0xF01D1716);
  static const Color _accent = Color(0xFFDF9D84);
  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  StreamSubscription<Position>? _positionSubscription;
  Position? _latestPosition;
  DateTime? _lastUiRefreshAt;
  DateTime? _lastCameraUpdateAt;
  DateTime? _lastRouteRequestAt;
  DateTime? _lastLocationPostAt;
  LatLng? _lastRouteOrigin;
  LatLng? _lastPostedLocation;

  maplibre.MapLibreSession? _map;
  maplibre.CircleAnnotationManager? _markers;
  maplibre.PolylineAnnotationManager? _routeLines;

  List<LatLng> _routePoints = <LatLng>[];
  List<_DeliveryNavigationStep> _steps = <_DeliveryNavigationStep>[];
  double? _routeDistanceMeters;
  double? _routeDurationSeconds;
  DateTime? _arrivalTime;
  bool _gpsStarting = false;
  bool _gpsActive = false;
  bool _routeRequestInProgress = false;
  bool _routeRefreshQueued = false;
  bool _mapSyncInProgress = false;
  bool _mapSyncQueued = false;
  bool _cameraPositioned = false;
  bool _locationPostErrorShown = false;
  bool _mapErrorShown = false;
  String _status = 'Waiting for rider GPS.';

  bool get _supportsMapLibre =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  LatLng? get _destination {
    final LatLng? explicitDestination = widget.destination;
    if (explicitDestination != null && _isValidPoint(explicitDestination)) {
      return explicitDestination;
    }
    final RiderDeliveryData delivery = widget.delivery;
    if (delivery.hasDeliveryCoordinates) {
      return LatLng(delivery.deliveryLatitude!, delivery.deliveryLongitude!);
    }
    return null;
  }

  LatLng? get _currentLocation {
    final Position? position = _latestPosition;
    if (position == null || !_hasValidCoordinates(position)) return null;
    return LatLng(position.latitude, position.longitude);
  }

  _DeliveryNavigationStep? get _nextStep {
    if (_steps.isEmpty) return null;
    final int nearestIndex = _nearestRouteIndex;
    for (final _DeliveryNavigationStep step in _steps) {
      if (step.routeIndex >= nearestIndex) return step;
    }
    return _steps.last;
  }

  int get _nearestRouteIndex {
    final LatLng? rider = _currentLocation;
    if (rider == null || _routePoints.isEmpty) return 0;
    int closestIndex = 0;
    double closestMeters = double.infinity;
    for (int index = 0; index < _routePoints.length; index++) {
      final LatLng point = _routePoints[index];
      final double meters = Geolocator.distanceBetween(
        rider.latitude,
        rider.longitude,
        point.latitude,
        point.longitude,
      );
      if (meters < closestMeters) {
        closestMeters = meters;
        closestIndex = index;
      }
    }
    return closestIndex;
  }

  double? get _remainingDistanceMeters {
    if (_routePoints.length < 2) return _routeDistanceMeters;
    final int start = _nearestRouteIndex;
    double distance = 0;
    for (int index = start; index < _routePoints.length - 1; index++) {
      final LatLng from = _routePoints[index];
      final LatLng to = _routePoints[index + 1];
      distance += Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
    }
    return distance;
  }

  double? get _metersToNextStep {
    final _DeliveryNavigationStep? step = _nextStep;
    if (step == null || _routePoints.isEmpty) return null;
    final int start = _nearestRouteIndex;
    final int end = step.routeIndex
        .clamp(start, _routePoints.length - 1)
        .toInt();
    double distance = 0;
    for (int index = start; index < end; index++) {
      final LatLng from = _routePoints[index];
      final LatLng to = _routePoints[index + 1];
      distance += Geolocator.distanceBetween(
        from.latitude,
        from.longitude,
        to.latitude,
        to.longitude,
      );
    }
    return distance;
  }

  double? get _remainingDurationSeconds {
    final double? duration = _routeDurationSeconds;
    final double? totalDistance = _routeDistanceMeters;
    final double? remainingDistance = _remainingDistanceMeters;
    if (duration == null ||
        totalDistance == null ||
        totalDistance <= 0 ||
        remainingDistance == null) {
      return duration;
    }
    return duration *
        (remainingDistance / totalDistance).clamp(0, 1).toDouble();
  }

  @override
  void initState() {
    super.initState();
    if (_destination == null) {
      _status = 'The buyer delivery pin is unavailable.';
    } else if (!_supportsMapLibre) {
      _status = 'Full-screen navigation is available on Android and iOS.';
    }
    if (_supportsMapLibre) unawaited(_startGps());
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  Future<void> _startGps() async {
    if (!_supportsMapLibre || _gpsStarting || _positionSubscription != null) {
      return;
    }
    setState(() => _gpsStarting = true);
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _gpsActive = false;
            _status = 'Turn on device location to start navigation.';
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
            _gpsActive = false;
            _status = 'Location permission is required for rider navigation.';
          });
        }
        return;
      }

      if (!mounted) return;
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: _onGpsError);
      setState(() {
        _gpsActive = true;
        _status = 'Waiting for a precise GPS fix.';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _gpsActive = false;
          _status = 'Could not start rider GPS: $error';
        });
      }
    } finally {
      if (mounted) setState(() => _gpsStarting = false);
    }
  }

  Future<void> _toggleGps() async {
    if (_positionSubscription != null) {
      final StreamSubscription<Position> current = _positionSubscription!;
      _positionSubscription = null;
      await current.cancel();
      if (mounted) {
        setState(() {
          _gpsActive = false;
          _status = 'Live GPS paused.';
        });
      }
      return;
    }
    await _startGps();
  }

  void _onGpsError(Object error, [StackTrace? stackTrace]) {
    final StreamSubscription<Position>? current = _positionSubscription;
    _positionSubscription = null;
    if (current != null) unawaited(current.cancel().catchError((Object _) {}));
    if (mounted) {
      setState(() {
        _gpsActive = false;
        _status = 'Device GPS is temporarily unavailable: $error';
      });
    }
  }

  void _onPosition(Position position) {
    if (!mounted || !_hasValidCoordinates(position)) return;
    final Position? previous = _latestPosition;
    _latestPosition = position;
    final DateTime now = DateTime.now();
    final bool shouldRefreshUi =
        _lastUiRefreshAt == null ||
        now.difference(_lastUiRefreshAt!) >= const Duration(seconds: 1) ||
        previous == null ||
        Geolocator.distanceBetween(
              previous.latitude,
              previous.longitude,
              position.latitude,
              position.longitude,
            ) >=
            8;
    if (shouldRefreshUi) {
      _lastUiRefreshAt = now;
      setState(() {
        _gpsActive = true;
        _status = 'Live rider GPS is active.';
      });
    }
    final LatLng location = LatLng(position.latitude, position.longitude);
    unawaited(_syncMap());
    _postLocationIfNeeded(position, location);
    _maybeRefreshRoute(location, now);
  }

  void _maybeRefreshRoute(LatLng origin, DateTime now) {
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequest = _lastRouteRequestAt;
    final bool shouldRequest =
        previousOrigin == null ||
        previousRequest == null ||
        Geolocator.distanceBetween(
              previousOrigin.latitude,
              previousOrigin.longitude,
              origin.latitude,
              origin.longitude,
            ) >=
            100 ||
        now.difference(previousRequest) >= const Duration(seconds: 90);
    if (shouldRequest) unawaited(_requestRoute(origin));
  }

  Future<void> _requestRoute(LatLng origin) async {
    if (_destination == null) {
      if (mounted)
        setState(() => _status = 'The buyer delivery pin is unavailable.');
      return;
    }
    if (_routeRequestInProgress) {
      _routeRefreshQueued = true;
      return;
    }
    if (!AppConfig.apiEnabled) {
      if (mounted) {
        setState(() {
          _status = 'Enable the Laravel API to load road directions.';
          _routePoints = <LatLng>[origin, _destination!];
        });
      }
      unawaited(_drawRouteLine());
      return;
    }

    _routeRequestInProgress = true;
    _lastRouteOrigin = origin;
    _lastRouteRequestAt = DateTime.now();
    final LatLng destination = _destination!;
    try {
      final Response<dynamic> response = await ApiClient.get(
        'maps/route',
        queryParameters: <String, dynamic>{
          'waypoints':
              '${origin.longitude},${origin.latitude};'
              '${destination.longitude},${destination.latitude}',
        },
      );
      final List<dynamic> routes =
          response.data?['routes'] as List<dynamic>? ?? const <dynamic>[];
      if (routes.isEmpty || routes.first is! Map) {
        throw StateError('No road route was returned.');
      }
      final Map<String, dynamic> route = Map<String, dynamic>.from(
        routes.first as Map,
      );
      final dynamic geometryValue = route['geometry'];
      final Map<String, dynamic>? geometry = geometryValue is Map
          ? Map<String, dynamic>.from(geometryValue)
          : null;
      final dynamic rawCoordinates = geometry?['coordinates'];
      final List<LatLng> points = <LatLng>[];
      if (rawCoordinates is List) {
        for (final dynamic coordinate in rawCoordinates) {
          if (coordinate is! List || coordinate.length < 2) continue;
          final double? longitude = _number(coordinate[0]);
          final double? latitude = _number(coordinate[1]);
          if (latitude == null || longitude == null) continue;
          final LatLng point = LatLng(latitude, longitude);
          if (_isValidPoint(point)) points.add(point);
        }
      }
      if (points.length < 2) throw StateError('The road route was incomplete.');

      final List<_DeliveryNavigationStep> steps = _parseSteps(
        route['steps'],
        points.length,
      );
      final double? distance = _number(route['distance']);
      final double? duration = _number(route['duration']);
      if (!mounted) return;
      setState(() {
        _routePoints = points;
        _steps = steps;
        _routeDistanceMeters = distance;
        _routeDurationSeconds = duration;
        _arrivalTime = duration == null || !duration.isFinite
            ? null
            : DateTime.now().add(Duration(seconds: duration.round()));
        _status = steps.isEmpty
            ? 'Road route loaded; turn instructions are unavailable.'
            : 'Road route and turn directions updated.';
      });
      await _drawRouteLine();
      await _syncMap();
    } catch (error) {
      if (mounted) {
        setState(() {
          _status = 'Road directions are temporarily unavailable: $error';
          if (_routePoints.length < 2)
            _routePoints = <LatLng>[origin, destination];
        });
        await _drawRouteLine();
      }
    } finally {
      _routeRequestInProgress = false;
      if (_routeRefreshQueued && mounted) {
        _routeRefreshQueued = false;
        final LatLng? latest = _currentLocation;
        if (latest != null) unawaited(_requestRoute(latest));
      }
    }
  }

  List<_DeliveryNavigationStep> _parseSteps(dynamic raw, int routeLength) {
    if (raw is! List) return <_DeliveryNavigationStep>[];
    final List<_DeliveryNavigationStep> result = <_DeliveryNavigationStep>[];
    for (final dynamic value in raw) {
      if (value is! Map) continue;
      final String text = value['instruction']?.toString().trim() ?? '';
      final int? routeIndex = int.tryParse(
        value['route_index']?.toString() ?? '',
      );
      final String type = value['type']?.toString() ?? '';
      if (text.isEmpty || routeIndex == null || routeIndex < 0) continue;
      result.add(
        _DeliveryNavigationStep(
          instruction: text,
          type: type,
          routeIndex: routeIndex.clamp(0, routeLength - 1).toInt(),
        ),
      );
    }
    result.sort(
      (_DeliveryNavigationStep a, _DeliveryNavigationStep b) =>
          a.routeIndex.compareTo(b.routeIndex),
    );
    return result;
  }

  Future<void> _onMapCreated(maplibre.MapLibreSession map) async {
    try {
      _map = map;
      _markers = await map.annotations.createCircleAnnotationManager();
      _routeLines = await map.annotations.createPolylineAnnotationManager();
      await _syncMap();
      await _drawRouteLine();
    } catch (error) {
      _showMapError(error);
    }
  }

  Future<void> _syncMap() async {
    if (_mapSyncInProgress) {
      _mapSyncQueued = true;
      return;
    }
    _mapSyncInProgress = true;
    try {
      do {
        _mapSyncQueued = false;
        await _syncMapOnce();
      } while (mounted && _mapSyncQueued);
      _mapErrorShown = false;
    } catch (error) {
      _showMapError(error);
    } finally {
      _mapSyncInProgress = false;
    }
  }

  Future<void> _syncMapOnce() async {
    final maplibre.MapLibreSession? map = _map;
    final maplibre.CircleAnnotationManager? markers = _markers;
    if (map == null || markers == null) return;

    await markers.deleteAll();
    final LatLng? destination = _destination;
    final LatLng? rider = _currentLocation;
    final List<maplibre.CircleAnnotationOptions> annotations =
        <maplibre.CircleAnnotationOptions>[
          if (destination != null)
            maplibre.CircleAnnotationOptions(
              geometry: _toMapPoint(destination),
              circleColor: AppTheme.resolve(context, _routeColor).toARGB32(),
              circleRadius: 11,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 3,
              circleSortKey: 1,
            ),
          if (rider != null)
            maplibre.CircleAnnotationOptions(
              geometry: _toMapPoint(rider),
              circleColor: AppTheme.resolve(context, _riderColor).toARGB32(),
              circleRadius: 10,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 3,
              circleSortKey: 2,
            ),
        ];
    if (annotations.isNotEmpty) await markers.createMulti(annotations);

    final DateTime now = DateTime.now();
    final DateTime? lastCameraUpdate = _lastCameraUpdateAt;
    final bool shouldFollow =
        rider != null &&
        (lastCameraUpdate == null ||
            now.difference(lastCameraUpdate) >= const Duration(seconds: 2));
    if (!_cameraPositioned && rider == null && destination != null) {
      await map.setCamera(
        maplibre.CameraOptions(center: _toMapPoint(destination), zoom: 14),
      );
      _cameraPositioned = true;
    } else if (shouldFollow) {
      await map.setCamera(
        maplibre.CameraOptions(center: _toMapPoint(rider), zoom: 16),
      );
      _cameraPositioned = true;
      _lastCameraUpdateAt = now;
    }
  }

  Future<void> _drawRouteLine() async {
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    if (manager == null || _routePoints.length < 2) return;
    final List<maplibre.Position> coordinates = _routePoints
        .map(
          (LatLng point) => maplibre.Position(point.longitude, point.latitude),
        )
        .toList(growable: false);
    try {
      await manager.deleteAll();
      final maplibre.LineString geometry = maplibre.LineString(
        coordinates: coordinates,
      );
      await manager.create(
        maplibre.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: Colors.white.toARGB32(),
          lineWidth: 8,
          lineOpacity: 0.95,
        ),
      );
      await manager.create(
        maplibre.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: AppTheme.resolve(context, _routeColor).toARGB32(),
          lineWidth: 5,
          lineOpacity: 0.96,
        ),
      );
    } catch (error) {
      _showMapError(error);
    }
  }

  void _recenter() {
    final LatLng? rider = _currentLocation;
    final LatLng? destination = _destination;
    final maplibre.MapLibreSession? map = _map;
    if (map == null) return;
    final LatLng? center = rider ?? destination;
    if (center == null) return;
    unawaited(
      map
          .setCamera(
            maplibre.CameraOptions(
              center: _toMapPoint(center),
              zoom: rider == null ? 14 : 16,
            ),
          )
          .catchError((Object error) => _showMapError(error)),
    );
    _lastCameraUpdateAt = DateTime.now();
    _cameraPositioned = true;
  }

  void _postLocationIfNeeded(Position position, LatLng location) {
    if (!AppConfig.apiEnabled || widget.delivery.id <= 0) return;
    if (!position.accuracy.isFinite ||
        position.accuracy < 0 ||
        position.accuracy > 250) {
      return;
    }
    final DateTime now = DateTime.now();
    final DateTime? previousAt = _lastLocationPostAt;
    final LatLng? previousLocation = _lastPostedLocation;
    final bool movedEnough =
        previousLocation == null ||
        Geolocator.distanceBetween(
              previousLocation.latitude,
              previousLocation.longitude,
              location.latitude,
              location.longitude,
            ) >=
            25;
    if (previousAt != null &&
        now.difference(previousAt) < const Duration(seconds: 10) &&
        !movedEnough) {
      return;
    }
    _lastLocationPostAt = now;
    _lastPostedLocation = location;
    unawaited(_uploadLocation(position));
  }

  Future<void> _uploadLocation(Position position) async {
    try {
      await RiderMobileService.updateLiveLocation(
        assignmentId: widget.delivery.id,
        latitude: position.latitude,
        longitude: position.longitude,
        accuracy: position.accuracy,
        recordedAt: position.timestamp,
      );
      _locationPostErrorShown = false;
    } catch (error) {
      if (mounted && !_locationPostErrorShown) {
        _locationPostErrorShown = true;
        _showMessage('GPS could not sync to delivery tracking: $error');
      }
    }
  }

  void _showMapError(Object error) {
    if (!mounted || _mapErrorShown) return;
    _mapErrorShown = true;
    setState(() => _status = 'Map update failed: $error');
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  maplibre.Point _toMapPoint(LatLng point) => maplibre.Point(
    coordinates: maplibre.Position(point.longitude, point.latitude),
  );

  bool _hasValidCoordinates(Position position) =>
      position.latitude.isFinite &&
      position.longitude.isFinite &&
      position.latitude >= -90 &&
      position.latitude <= 90 &&
      position.longitude >= -180 &&
      position.longitude <= 180;

  bool _isValidPoint(LatLng point) =>
      point.latitude.isFinite &&
      point.longitude.isFinite &&
      point.latitude >= -90 &&
      point.latitude <= 90 &&
      point.longitude >= -180 &&
      point.longitude <= 180 &&
      (point.latitude != 0 || point.longitude != 0);

  double? _number(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  IconData _iconForStep(_DeliveryNavigationStep? step) {
    final String type = step?.type.toLowerCase() ?? '';
    if (type.contains('left') || type.contains('uturnleft')) {
      return Icons.turn_left_rounded;
    }
    if (type.contains('right') || type.contains('uturnright')) {
      return Icons.turn_right_rounded;
    }
    if (type.contains('roundabout')) return Icons.alt_route_rounded;
    if (type.contains('destination')) return Icons.flag_rounded;
    if (type.contains('merge')) return Icons.alt_route_rounded;
    if (type.contains('straight') || type.contains('startat')) {
      return Icons.straight_rounded;
    }
    return Icons.navigation_rounded;
  }

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

  String _formatArrival(DateTime? dateTime) {
    if (dateTime == null) return '—';
    return TimeOfDay.fromDateTime(dateTime.toLocal()).format(context);
  }

  @override
  Widget build(BuildContext context) {
    final LatLng initialCenter =
        _currentLocation ?? _destination ?? _defaultCenter;
    final _DeliveryNavigationStep? nextStep = _nextStep;
    final double? metersToNextStep = _metersToNextStep;
    final double? remainingDistance = _remainingDistanceMeters;
    final double? remainingDuration = _remainingDurationSeconds;
    final DateTime? estimatedArrival = remainingDuration == null
        ? _arrivalTime
        : DateTime.now().add(Duration(seconds: remainingDuration.round()));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF171210),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF171210),
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            if (_supportsMapLibre)
              maplibre.MapLibreMapWidget(
                viewport: maplibre.MapLibreViewport(
                  center: _toMapPoint(initialCenter),
                  zoom: _currentLocation == null ? 13 : 16,
                ),
                onMapCreated: _onMapCreated,
              )
            else
              const ColoredBox(color: Color(0xFFF0E9E3)),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    _buildTopBar(),
                    const SizedBox(height: 12),
                    _buildTurnCard(nextStep, metersToNextStep),
                    const Spacer(),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildRecenterButton(),
                    ),
                    const SizedBox(height: 12),
                    _buildBottomPanel(
                      remainingDistance: remainingDistance,
                      remainingDuration: remainingDuration,
                      arrival: estimatedArrival,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: <Widget>[
        _roundButton(
          icon: Icons.arrow_back_rounded,
          label: 'Back',
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: <Widget>[
                Icon(Icons.navigation_rounded, color: _accent, size: 20),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Text(
                        'Delivery navigation',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        widget.delivery.buyerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _gpsActive
                        ? const Color(0xFF147C50)
                        : const Color(0xFF61473E),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _gpsActive ? 'GPS LIVE' : 'GPS OFF',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTurnCard(_DeliveryNavigationStep? step, double? metersToStep) {
    final String instruction =
        step?.instruction ??
        (_routeRequestInProgress
            ? 'Finding the road route to the buyer…'
            : _destination == null
            ? 'Buyer destination pin is unavailable.'
            : _routePoints.isEmpty
            ? 'Waiting for GPS to calculate directions.'
            : 'Follow the highlighted route to the buyer.');
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 54,
            height: 54,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _accent.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(_iconForStep(step), color: _accent, size: 31),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  metersToStep == null
                      ? (step == null ? 'NEXT DIRECTION' : 'FOLLOW ROUTE')
                      : 'IN ${_formatDistance(metersToStep).toUpperCase()}',
                  style: TextStyle(
                    color: _accent,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  instruction,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    height: 1.23,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecenterButton() {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(16),
      elevation: 5,
      child: InkWell(
        onTap: _recenter,
        borderRadius: BorderRadius.circular(16),
        child: const SizedBox(
          width: 52,
          height: 52,
          child: Icon(Icons.my_location_rounded, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildBottomPanel({
    required double? remainingDistance,
    required double? remainingDuration,
    required DateTime? arrival,
  }) {
    final double? totalDistance = _routeDistanceMeters;
    final double progress = totalDistance == null || totalDistance <= 0
        ? 0
        : (1 - ((remainingDistance ?? totalDistance) / totalDistance)).clamp(
            0,
            1,
          );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x44000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: _metric(
                  label: 'ARRIVAL',
                  value: _formatArrival(arrival),
                  valueSize: 25,
                  valueColor: const Color(0xFF8FE0B8),
                ),
              ),
              Expanded(
                child: _metric(
                  label: 'TIME LEFT',
                  value: _formatDuration(remainingDuration),
                  valueSize: 18,
                ),
              ),
              Expanded(
                child: _metric(
                  label: 'DISTANCE',
                  value: _formatDistance(remainingDistance),
                  valueSize: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              backgroundColor: Colors.white.withValues(alpha: 0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(_accent),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Icon(Icons.home_work_outlined, color: _accent, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.delivery.address.trim().isEmpty
                      ? 'Buyer delivery address'
                      : widget.delivery.address,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.84),
                    fontSize: 11,
                    height: 1.25,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _gpsStarting ? null : _toggleGps,
                tooltip: _gpsActive ? 'Pause rider GPS' : 'Resume rider GPS',
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF6D2930),
                  foregroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                icon: Icon(
                  _gpsActive ? Icons.pause_rounded : Icons.play_arrow_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _status,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.64),
              fontSize: 10,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required String label,
    required String value,
    required double valueSize,
    Color valueColor = Colors.white,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 8,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: valueColor,
            fontSize: valueSize,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _roundButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return Material(
      color: _surface,
      borderRadius: BorderRadius.circular(15),
      elevation: 4,
      child: IconButton(
        tooltip: label,
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        constraints: const BoxConstraints.tightFor(width: 48, height: 48),
      ),
    );
  }
}

class _DeliveryNavigationStep {
  final String instruction;
  final String type;
  final int routeIndex;

  const _DeliveryNavigationStep({
    required this.instruction,
    required this.type,
    required this.routeIndex,
  });
}

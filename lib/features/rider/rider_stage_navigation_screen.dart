import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_navigation_sdk/mapbox_navigation_sdk.dart' as navigation;

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
  static const String _mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');
  static const Color _maroon = Color(0xFF7A2430);
  static const Color _riderBlue = Color(0xFF1976D2);
  static const Color _muted = Color(0xFF766C65);
  static const Color _routeColor = Color(0xFF7A2A22);

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  mapbox.MapboxMap? _map;
  mapbox.CircleAnnotationManager? _markers;
  mapbox.PolylineAnnotationManager? _routeLines;
  StreamSubscription<Position>? _positionSubscription;
  Position? _latestPosition;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteRequestAt;
  DateTime? _lastLocationPostAt;
  LatLng? _lastPostedLocation;
  double? _routeMeters;
  double? _routeSeconds;
  bool _routeRequestInProgress = false;
  bool _cameraPositioned = false;
  bool _startingNavigation = false;
  bool _locationPermissionReady = false;
  bool _locationErrorShown = false;
  bool _locationPostErrorShown = false;
  String _status = 'Waiting for rider GPS.';

  bool get _supportsMapbox =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool get _hasMapToken => _mapboxAccessToken.trim().isNotEmpty;

  double? get _destinationLatitude => widget.toLogisticsCenter
      ? widget.pickup.logisticsCenterLatitude
      : widget.pickup.sellerLatitude;

  double? get _destinationLongitude => widget.toLogisticsCenter
      ? widget.pickup.logisticsCenterLongitude
      : widget.pickup.sellerLongitude;

  LatLng? get _destination {
    final double? latitude = _destinationLatitude;
    final double? longitude = _destinationLongitude;
    if (latitude == null || longitude == null ||
        !latitude.isFinite || !longitude.isFinite ||
        latitude < -90 || latitude > 90 ||
        longitude < -180 || longitude > 180 ||
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
    final List<int> batchAssignmentIds = widget.pickup.parcels
        .map((RiderPickupBatchItemData parcel) => parcel.assignmentId)
        .where((int id) => id > 0)
        .toSet()
        .toList(growable: false);
    if (batchAssignmentIds.isNotEmpty) return batchAssignmentIds;
    return widget.pickup.id > 0 ? <int>[widget.pickup.id] : const <int>[];
  }

  @override
  void initState() {
    super.initState();
    unawaited(
      navigation.MapBoxNavigation.instance.registerRouteEventListener(
        _onNavigationEvent,
      ),
    );
    if (_destination == null) {
      _status = widget.toLogisticsCenter
          ? 'Logistics center coordinates are unavailable.'
          : 'The seller has not saved an exact map pin.';
      return;
    }
    if (_supportsMapbox) unawaited(_startLocationTracking());
  }

  @override
  void dispose() {
    unawaited(_positionSubscription?.cancel());
    super.dispose();
  }

  void _onNavigationEvent(navigation.RouteEvent event) {
    if (event.eventType == navigation.MapBoxEvent.route_build_failed ||
        event.eventType == navigation.MapBoxEvent.route_build_no_routes_found) {
      if (mounted) {
        setState(() => _status = 'Mapbox could not find a driving route.');
      }
    }
  }

  Future<void> _startLocationTracking() async {
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _status = 'Turn on device location to share GPS.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) setState(() => _status = 'Location permission is required for rider GPS.');
        return;
      }

      _locationPermissionReady = true;
      if (mounted) setState(() => _status = 'Waiting for a precise GPS fix.');
      await _positionSubscription?.cancel();
      _positionSubscription = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 5,
        ),
      ).listen(_onPosition, onError: (_) {
        if (mounted) setState(() => _status = 'Device GPS is temporarily unavailable.');
      });
    } catch (error) {
      if (mounted) setState(() => _status = 'Could not start rider GPS: $error');
    }
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
    if (!position.accuracy.isFinite || position.accuracy < 0 ||
        position.accuracy > 250) {
      if (mounted) setState(() => _status = 'GPS accuracy is too low; waiting for a better fix.');
      return;
    }

    final DateTime now = DateTime.now();
    final DateTime? lastPost = _lastLocationPostAt;
    final LatLng? lastLocation = _lastPostedLocation;
    if (lastPost != null && now.difference(lastPost) < const Duration(seconds: 15)) {
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
      await Future.wait<void>(assignmentIds.map((int assignmentId) {
        return RiderMobileService.updateLiveLocation(
          assignmentId: assignmentId,
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          recordedAt: position.timestamp,
        );
      }));
      _locationPostErrorShown = false;
    } catch (error) {
      if (mounted && !_locationPostErrorShown) {
        _locationPostErrorShown = true;
        _showMessage('GPS is visible on this device but could not sync: $error');
      }
    }
  }

  Future<void> _onMapCreated(mapbox.MapboxMap map) async {
    _map = map;
    _markers = await map.annotations.createCircleAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    final Position? position = _latestPosition;
    await _syncMap(
      position == null ? null : LatLng(position.latitude, position.longitude),
    );
  }

  Future<void> _syncMap(LatLng? origin) async {
    final mapbox.MapboxMap? map = _map;
    final mapbox.CircleAnnotationManager? markerManager = _markers;
    final LatLng? destination = _destination;
    if (map == null || markerManager == null || destination == null) return;

    await markerManager.deleteAll();
    await markerManager.createMulti(<mapbox.CircleAnnotationOptions>[
      mapbox.CircleAnnotationOptions(
        geometry: _toMapboxPoint(destination),
        circleColor: _maroon.toARGB32(),
        circleRadius: 11,
        circleStrokeColor: Colors.white.toARGB32(),
        circleStrokeWidth: 3,
      ),
      if (origin != null)
        mapbox.CircleAnnotationOptions(
          geometry: _toMapboxPoint(origin),
          circleColor: _riderBlue.toARGB32(),
          circleRadius: 9,
          circleStrokeColor: Colors.white.toARGB32(),
          circleStrokeWidth: 3,
        ),
    ]);

    if (!_cameraPositioned) {
      if (origin != null) {
        final mapbox.CameraOptions camera = await map.cameraForCoordinatesPadding(
          <mapbox.Point>[_toMapboxPoint(origin), _toMapboxPoint(destination)],
          mapbox.CameraOptions(
            padding: mapbox.MbxEdgeInsets(
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
          mapbox.CameraOptions(center: _toMapboxPoint(destination), zoom: 14),
        );
      }
      _cameraPositioned = true;
    }

    if (origin != null) unawaited(_drawRoute(origin, destination));
  }

  Future<void> _drawRoute(LatLng origin, LatLng destination) async {
    final mapbox.PolylineAnnotationManager? manager = _routeLines;
    if (manager == null || !_hasMapToken || _routeRequestInProgress) return;
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequestAt = _lastRouteRequestAt;
    if (previousOrigin != null &&
        previousRequestAt != null &&
        DateTime.now().difference(previousRequestAt) <
            const Duration(seconds: 15) &&
        Geolocator.distanceBetween(
              previousOrigin.latitude,
              previousOrigin.longitude,
              origin.latitude,
              origin.longitude,
            ) <
            50) {
      return;
    }

    _routeRequestInProgress = true;
    _lastRouteOrigin = origin;
    _lastRouteRequestAt = DateTime.now();
    final String coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';
    try {
      final Response<Map<String, dynamic>> response =
          await _dio.get<Map<String, dynamic>>(
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
      final List<dynamic> coordinatesList =
          geometry['coordinates'] as List<dynamic>? ?? const <dynamic>[];
      final List<mapbox.Position> positions = coordinatesList
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
          lineColor: _routeColor.toARGB32(),
          lineWidth: 5,
          lineOpacity: 0.85,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.5,
        ),
      );
      if (mounted) {
        setState(() {
          _routeMeters = (route['distance'] as num?)?.toDouble();
          _routeSeconds = (route['duration'] as num?)?.toDouble();
          _status = 'Road route updated from rider GPS.';
        });
      }
    } catch (error) {
      if (mounted) setState(() => _status = 'Map route is temporarily unavailable: $error');
    } finally {
      _routeRequestInProgress = false;
    }
  }

  Future<void> _startNavigation() async {
    final LatLng? destination = _destination;
    if (destination == null) {
      _showMessage('The saved destination coordinates are unavailable.');
      return;
    }
    if (!_supportsMapbox) {
      _showMessage('Mapbox navigation is available on Android and iOS.');
      return;
    }
    if (!_hasMapToken) {
      _showMessage('Add MAPBOX_ACCESS_TOKEN before starting navigation.');
      return;
    }
    if (_startingNavigation) return;
    setState(() => _startingNavigation = true);

    try {
      if (!_locationPermissionReady) await _startLocationTracking();
      Position? position = _latestPosition;
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final LatLng origin = LatLng(position.latitude, position.longitude);
      if (Geolocator.distanceBetween(
            origin.latitude,
            origin.longitude,
            destination.latitude,
            destination.longitude,
          ) <
          10) {
        throw StateError('You are already at this destination.');
      }

      final navigation.MapBoxOptions options = navigation.MapBoxOptions(
        initialLatitude: origin.latitude,
        initialLongitude: origin.longitude,
        zoom: 12.5,
        tilt: 0,
        alternatives: false,
        enableRefresh: true,
        voiceInstructionsEnabled: true,
        bannerInstructionsEnabled: true,
        allowsUTurnAtWayPoints: false,
        longPressDestinationEnabled: false,
        enableOnMapTapCallback: false,
        mode: navigation.MapBoxNavigationMode.drivingWithTraffic,
        units: navigation.VoiceUnits.metric,
        simulateRoute: false,
        language: 'en',
      );
      final bool? started = await navigation.MapBoxNavigation.instance
          .startNavigation(
            wayPoints: <navigation.WayPoint>[
              navigation.WayPoint(
                name: 'Rider location',
                latitude: origin.latitude,
                longitude: origin.longitude,
              ),
              navigation.WayPoint(
                name: _destinationName,
                latitude: destination.latitude,
                longitude: destination.longitude,
              ),
            ],
            options: options,
          )
          .timeout(const Duration(seconds: 7));
      if (started == false) throw StateError('Mapbox could not start the route.');
    } catch (error) {
      if (mounted) _showMessage('Unable to start navigation: $error');
    } finally {
      if (mounted) setState(() => _startingNavigation = false);
    }
  }

  mapbox.Point _toMapboxPoint(LatLng point) => mapbox.Point(
        coordinates: mapbox.Position(point.longitude, point.latitude),
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
        title: Text(widget.toLogisticsCenter ? 'Navigate to Logistics' : 'Navigate to Seller'),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: _supportsMapbox && _hasMapToken && destination != null
                  ? mapbox.MapWidget(
                      viewport: mapbox.CameraViewportState(
                        center: _toMapboxPoint(destination),
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
                            !_supportsMapbox
                                ? 'Mapbox navigation is available on Android and iOS.'
                                : !_hasMapToken
                                    ? 'Add MAPBOX_ACCESS_TOKEN to load the map.'
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
                  const SizedBox(height: 12),
                  Text(_status, style: const TextStyle(color: _muted, fontSize: 12)),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: _startingNavigation || destination == null
                          ? null
                          : _startNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _maroon,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                      icon: const Icon(Icons.navigation_rounded),
                      label: Text(
                        _startingNavigation
                            ? 'Starting navigation…'
                            : 'Start turn-by-turn navigation',
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
          Text(label, style: const TextStyle(color: _RiderStageNavigationScreenState._muted, fontSize: 10)),
          const SizedBox(height: 3),
          Text(value, style: const TextStyle(color: _RiderStageNavigationScreenState._maroon, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

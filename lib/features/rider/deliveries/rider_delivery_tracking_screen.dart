import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mapbox;
import 'package:mapbox_navigation_sdk/mapbox_navigation_sdk.dart' as navigation;

import '../../../core/config/app_config.dart';
import '../../../services/auth_service.dart';
import '../../../services/rider_mobile_service.dart';
import 'rider_delivery_models.dart';
import 'rider_proof_watermark.dart';

class RiderDeliveryTrackingScreen extends StatefulWidget {
  final RiderDeliveryData? delivery;

  final bool showPreviewWhenNull;

  /// Real delivery destination from Laravel/API.
  final LatLng? deliveryLocation;

  /// Current rider GPS position when available.
  final LatLng? riderLocation;

  final VoidCallback? onBack;

  final RiderDeliveryCallback? onOpenDetails;

  final RiderExternalActionCallback? onOpenNavigation;

  final RiderExternalActionCallback? onContactCustomer;

  /// Sends the requested shipment transition to your API/service.
  final RiderDeliveryTransitionCallback? onTransition;

  const RiderDeliveryTrackingScreen({
    super.key,
    this.delivery,
    this.showPreviewWhenNull = true,
    this.deliveryLocation,
    this.riderLocation,
    this.onBack,
    this.onOpenDetails,
    this.onOpenNavigation,
    this.onContactCustomer,
    this.onTransition,
  });

  @override
  State<RiderDeliveryTrackingScreen> createState() =>
      _RiderDeliveryTrackingScreenState();
}

class _RiderDeliveryTrackingScreenState
    extends State<RiderDeliveryTrackingScreen> {
  static const String _mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);
  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);
  static const Color _riderColor = Color(0xFF1976D2);

  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _mutedLight = Color(0xFFA99386);

  static const Color _success = Color(0xFF168548);
  static const Color _danger = Color(0xFFB42318);

  static const LatLng _defaultCenter = LatLng(14.5995, 120.9842);

  /// PREVIEW ONLY.
  static const LatLng _sampleDeliveryLocation = LatLng(14.2326, 121.3648);

  /// PREVIEW ONLY.
  static const LatLng _sampleRiderLocation = LatLng(14.2298, 121.3599);

  static const RiderDeliveryData _sampleDelivery = RiderDeliveryData(
    id: 39,
    trackingCode: 'LKH-DLV-2026-0039',
    buyerName: 'Angela Reyes',
    contact: '0919 765 4321',
    address: '1 Sample Street, Masico, Pila, Laguna, 4010',
    amount: 965,
    status: 'out_for_delivery',
    statusLabel: 'Out For Delivery',
    isPreview: true,
  );

  final ImagePicker _imagePicker = ImagePicker();
  final Dio _dio = Dio();

  final TextEditingController _receiverController = TextEditingController();

  final TextEditingController _failedReasonController = TextEditingController();

  XFile? _proofPhoto;

  bool _takingPhoto = false;
  bool _submitting = false;
  bool _startingNavigation = false;
  bool _geocodingBuyerLocation = false;
  Completer<void>? _buyerLocationResolution;

  LatLng? _geocodedBuyerLocation;
  LatLng? _liveRiderLocation;
  DateTime? _liveRiderLocationUpdatedAt;
  DateTime? _lastUiLocationUpdateAt;
  DateTime? _lastLocationSyncAttemptAt;
  LatLng? _lastSyncedRiderLocation;
  bool _locationSyncErrorShown = false;
  bool _locationSyncEnabled = false;
  LatLng? _lastRouteOrigin;
  LatLng? _lastRouteDestination;

  StreamSubscription<Position>? _positionSubscription;
  bool _routeRequestInProgress = false;

  double _zoomLevel = 14;
  LatLng _lastMapCenter = _defaultCenter;

  mapbox.MapboxMap? _mapboxMap;
  mapbox.CircleAnnotationManager? _mapMarkers;
  mapbox.PointAnnotationManager? _riderMarkers;
  mapbox.PolylineAnnotationManager? _routeLines;
  Uint8List? _riderMarkerImage;

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

  bool get _usingPreview {
    return widget.delivery == null && widget.showPreviewWhenNull;
  }

  bool get _isPreviewDelivery {
    return _displayDelivery?.isPreview == true;
  }

  bool get _canSyncRiderLocation {
    final RiderDeliveryData? delivery = widget.delivery;
    return AppConfig.apiEnabled &&
        delivery != null &&
        delivery.id > 0 &&
        _locationSyncEnabled;
  }

  bool _isActiveDeliveryStatus(String status) {
    final String normalized = status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
    return <String>{'in_transit', 'out_for_delivery'}.contains(normalized);
  }

  RiderDeliveryData? get _displayDelivery {
    if (widget.delivery != null) {
      return widget.delivery;
    }

    if (_usingPreview) {
      return _sampleDelivery;
    }

    return null;
  }

  LatLng? get _displayDeliveryLocation {
    if (widget.deliveryLocation != null) {
      return widget.deliveryLocation;
    }

    final RiderDeliveryData? delivery = widget.delivery;
    if (delivery?.hasDeliveryCoordinates == true) {
      return LatLng(delivery!.deliveryLatitude!, delivery.deliveryLongitude!);
    }

    if (_geocodedBuyerLocation != null) {
      return _geocodedBuyerLocation;
    }

    if (_usingPreview) {
      return _sampleDeliveryLocation;
    }

    return null;
  }

  LatLng? get _displayRiderLocation {
    if (_liveRiderLocation != null) {
      return _liveRiderLocation;
    }

    if (widget.riderLocation != null) {
      return widget.riderLocation;
    }

    if (_isPreviewDelivery) {
      return _sampleRiderLocation;
    }

    return null;
  }

  LatLng get _mapCenter {
    final LatLng? destination = _displayDeliveryLocation;
    final LatLng? rider = _displayRiderLocation;

    if (destination != null && rider != null) {
      return LatLng(
        (destination.latitude + rider.latitude) / 2,
        (destination.longitude + rider.longitude) / 2,
      );
    }

    if (destination != null) {
      return destination;
    }

    if (rider != null) {
      return rider;
    }

    return _defaultCenter;
  }

  @override
  void initState() {
    super.initState();
    _locationSyncEnabled =
        widget.delivery != null &&
        _isActiveDeliveryStatus(widget.delivery!.normalizedStatus);
    unawaited(
      navigation.MapBoxNavigation.instance.registerRouteEventListener(
        _onMapboxNavigationEvent,
      ),
    );
    _resolveBuyerLocation();
    if (!_isPreviewDelivery) {
      _startRiderLocationTracking();
    }
  }

  void _onMapboxNavigationEvent(navigation.RouteEvent event) {
    switch (event.eventType) {
      case navigation.MapBoxEvent.route_build_failed:
        unawaited(
          _closeFailedNavigation(
            'Mapbox could not build the route. Check the rider and buyer locations.',
          ),
        );
        break;
      case navigation.MapBoxEvent.route_build_no_routes_found:
        unawaited(
          _closeFailedNavigation(
            'No drivable route was found between the rider and buyer.',
          ),
        );
        break;
      default:
        break;
    }
  }

  Future<void> _closeFailedNavigation(String message) async {
    try {
      await navigation.MapBoxNavigation.instance.finishNavigation().timeout(
        const Duration(seconds: 1),
      );
    } catch (_) {
      // The Android plugin closes the native activity before completing the
      // method-channel result.
    }

    if (mounted) {
      _showMessage(message);
    }
  }

  @override
  void didUpdateWidget(covariant RiderDeliveryTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.delivery != widget.delivery) {
      _locationSyncEnabled =
          widget.delivery != null &&
          _isActiveDeliveryStatus(widget.delivery!.normalizedStatus);
      _lastLocationSyncAttemptAt = null;
      _lastSyncedRiderLocation = null;
    }

    if (oldWidget.deliveryLocation != widget.deliveryLocation ||
        oldWidget.riderLocation != widget.riderLocation ||
        oldWidget.delivery != widget.delivery) {
      _geocodedBuyerLocation = null;
      _lastRouteDestination = null;
      _syncMapboxMarkers();
      _resolveBuyerLocation();
    }
  }

  Future<void> _startRiderLocationTracking() async {
    if (!_supportsMapbox) {
      return;
    }

    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }

    await _positionSubscription?.cancel();
    _positionSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 5,
          ),
        ).listen((Position position) {
          if (!mounted) {
            return;
          }

          final LatLng nextLocation = LatLng(
            position.latitude,
            position.longitude,
          );
          final DateTime now = DateTime.now();
          final DateTime? lastUiUpdate = _lastUiLocationUpdateAt;

          final bool shouldRefreshUi =
              _liveRiderLocation == null ||
              lastUiUpdate == null ||
              now.difference(lastUiUpdate) >=
                  const Duration(milliseconds: 1200) ||
              Geolocator.distanceBetween(
                    _liveRiderLocation!.latitude,
                    _liveRiderLocation!.longitude,
                    nextLocation.latitude,
                    nextLocation.longitude,
                  ) >=
                  8;

          if (shouldRefreshUi) {
            setState(() {
              _liveRiderLocation = nextLocation;
              _liveRiderLocationUpdatedAt = now;
              _lastUiLocationUpdateAt = now;
            });
          } else {
            setState(() {
              _liveRiderLocation = nextLocation;
              _liveRiderLocationUpdatedAt = now;
            });
          }

          _syncRiderLocationIfNeeded(position, nextLocation, now);
          _syncMapboxMarkers();
        });
  }

  void _syncRiderLocationIfNeeded(
    Position position,
    LatLng location,
    DateTime now,
  ) {
    final RiderDeliveryData? delivery = widget.delivery;
    if (!_canSyncRiderLocation || delivery == null) {
      return;
    }

    final DateTime? lastAttempt = _lastLocationSyncAttemptAt;
    if (lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 15)) {
      return;
    }

    final LatLng? lastSynced = _lastSyncedRiderLocation;
    if (lastSynced != null &&
        lastAttempt != null &&
        now.difference(lastAttempt) < const Duration(seconds: 60) &&
        Geolocator.distanceBetween(
              lastSynced.latitude,
              lastSynced.longitude,
              location.latitude,
              location.longitude,
            ) <
            25) {
      return;
    }

    _lastLocationSyncAttemptAt = now;
    unawaited(_uploadRiderLocation(delivery.id, position, location));
  }

  Future<void> _uploadRiderLocation(
    int assignmentId,
    Position position,
    LatLng location,
  ) async {
    try {
      await RiderMobileService.updateLiveLocation(
        assignmentId: assignmentId,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      _lastSyncedRiderLocation = location;
      _locationSyncErrorShown = false;
    } catch (error) {
      if (mounted && !_locationSyncErrorShown) {
        _locationSyncErrorShown = true;
        _showMessage('Unable to sync live location: $error');
      }
    }
  }

  Future<void> _resolveBuyerLocation() async {
    if (_geocodingBuyerLocation) {
      await _buyerLocationResolution?.future;
      return;
    }

    if (_displayDeliveryLocation != null ||
        _usingPreview ||
        _mapboxAccessToken.isEmpty) {
      return;
    }

    final String address = widget.delivery?.address.trim() ?? '';
    if (address.isEmpty) {
      return;
    }

    final Completer<void> resolution = Completer<void>();
    _buyerLocationResolution = resolution;

    if (mounted) {
      setState(() {
        _geocodingBuyerLocation = true;
      });
    }

    try {
      final Response<Map<String, dynamic>> response = await _dio
          .get<Map<String, dynamic>>(
            'https://api.mapbox.com/search/geocode/v6/forward',
            queryParameters: <String, dynamic>{
              'q': address,
              'country': 'ph',
              'autocomplete': false,
              'limit': 1,
              'access_token': _mapboxAccessToken,
            },
          );

      final List<dynamic> features =
          response.data?['features'] as List<dynamic>? ?? <dynamic>[];
      if (features.isEmpty) {
        return;
      }

      final Map<String, dynamic> feature = Map<String, dynamic>.from(
        features.first as Map,
      );
      final Map<String, dynamic> geometry = Map<String, dynamic>.from(
        feature['geometry'] as Map,
      );
      final List<dynamic> coordinates =
          geometry['coordinates'] as List<dynamic>;

      if (coordinates.length < 2) {
        return;
      }

      final double? longitude = double.tryParse(coordinates[0].toString());
      final double? latitude = double.tryParse(coordinates[1].toString());

      if (latitude == null ||
          longitude == null ||
          !mounted ||
          widget.delivery?.address.trim() != address) {
        return;
      }

      setState(() {
        _geocodedBuyerLocation = LatLng(latitude, longitude);
      });
      await _syncMapboxMarkers();
    } catch (_) {
      // The map keeps its unavailable state when an address cannot be resolved.
    } finally {
      if (!resolution.isCompleted) {
        resolution.complete();
      }
      if (identical(_buyerLocationResolution, resolution)) {
        _buyerLocationResolution = null;
      }
      if (mounted) {
        setState(() {
          _geocodingBuyerLocation = false;
        });
      }
    }
  }

  Future<void> _onMapboxMapCreated(mapbox.MapboxMap map) async {
    _mapboxMap = map;
    _mapMarkers = await map.annotations.createCircleAnnotationManager();
    _riderMarkers = await map.annotations.createPointAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();

    try {
      _riderMarkerImage ??= await _createRiderMarkerImage();
    } catch (_) {
      // A blue location dot is used if the rider icon cannot be rendered.
    }

    await _syncMapboxMarkers();
  }

  Future<Uint8List> _createRiderMarkerImage() async {
    const int imageSize = 112;
    const double center = imageSize / 2;
    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final ui.Canvas canvas = ui.Canvas(recorder);

    canvas.drawCircle(
      const ui.Offset(center, center + 4),
      47,
      ui.Paint()..color = Colors.black.withAlpha(45),
    );
    canvas.drawCircle(
      const ui.Offset(center, center),
      45,
      ui.Paint()..color = Colors.white,
    );
    canvas.drawCircle(
      const ui.Offset(center, center),
      39,
      ui.Paint()..color = _riderColor,
    );

    const IconData riderIcon = Icons.two_wheeler_rounded;
    final TextPainter iconPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(riderIcon.codePoint),
        style: TextStyle(
          color: Colors.white,
          fontFamily: riderIcon.fontFamily,
          fontSize: 58,
          height: 1,
          package: riderIcon.fontPackage,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    iconPainter.paint(
      canvas,
      ui.Offset(
        center - (iconPainter.width / 2),
        center - (iconPainter.height / 2),
      ),
    );

    final ui.Image image = await recorder.endRecording().toImage(
      imageSize,
      imageSize,
    );
    final ByteData? imageData = await image.toByteData(
      format: ui.ImageByteFormat.png,
    );
    image.dispose();

    if (imageData == null) {
      throw StateError('Unable to render the rider marker.');
    }

    return imageData.buffer.asUint8List(
      imageData.offsetInBytes,
      imageData.lengthInBytes,
    );
  }

  Future<void> _syncMapboxMarkers() async {
    final mapbox.MapboxMap? map = _mapboxMap;
    final mapbox.CircleAnnotationManager? manager = _mapMarkers;
    final mapbox.PointAnnotationManager? riderManager = _riderMarkers;

    if (map == null || manager == null) {
      return;
    }

    await manager.deleteAll();
    await riderManager?.deleteAll();

    final LatLng? destination = _displayDeliveryLocation;
    final LatLng? rider = _displayRiderLocation;
    final Uint8List? riderMarkerImage = _riderMarkerImage;
    final bool canShowRiderIcon =
        rider != null && riderManager != null && riderMarkerImage != null;
    final List<mapbox.CircleAnnotationOptions> annotations =
        <mapbox.CircleAnnotationOptions>[
          if (destination != null)
            mapbox.CircleAnnotationOptions(
              geometry: _toMapboxPoint(destination),
              circleColor: _maroon.toARGB32(),
              circleRadius: 11,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 3,
              circleSortKey: 2,
            ),
          if (rider != null && !canShowRiderIcon)
            mapbox.CircleAnnotationOptions(
              geometry: _toMapboxPoint(rider),
              circleColor: _riderColor.toARGB32(),
              circleRadius: 10,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 3,
              circleSortKey: 3,
            ),
        ];

    if (annotations.isNotEmpty) {
      await manager.createMulti(annotations);
    }

    if (rider != null && riderManager != null && riderMarkerImage != null) {
      await riderManager.create(
        mapbox.PointAnnotationOptions(
          geometry: _toMapboxPoint(rider),
          image: riderMarkerImage,
          iconAnchor: mapbox.IconAnchor.CENTER,
          iconSize: 0.55,
          symbolSortKey: 3,
        ),
      );
    }

    if (destination != null && rider != null) {
      final mapbox.CameraOptions camera = await map.cameraForCoordinatesPadding(
        <mapbox.Point>[_toMapboxPoint(rider), _toMapboxPoint(destination)],
        mapbox.CameraOptions(
          padding: mapbox.MbxEdgeInsets(
            top: 42,
            left: 42,
            bottom: 42,
            right: 42,
          ),
        ),
        null,
        15,
        null,
      );
      _lastMapCenter = _mapCenter;
      _zoomLevel = camera.zoom ?? 14;
      await map.setCamera(camera);
    } else {
      _lastMapCenter = _mapCenter;
      _zoomLevel = annotations.isEmpty ? 11 : 14;
      await map.setCamera(
        mapbox.CameraOptions(
          center: _toMapboxPoint(_lastMapCenter),
          zoom: _zoomLevel,
        ),
      );
    }

    await _syncRoute(rider: rider, destination: destination);
  }

  Future<void> _zoomMap(double step) async {
    final mapbox.MapboxMap? map = _mapboxMap;
    if (map == null) {
      return;
    }

    _zoomLevel = (_zoomLevel + step).clamp(3.0, 18.0);
    await map.setCamera(
      mapbox.CameraOptions(
        center: _toMapboxPoint(_lastMapCenter),
        zoom: _zoomLevel,
      ),
    );
  }

  Future<void> _syncRoute({
    required LatLng? rider,
    required LatLng? destination,
  }) async {
    final mapbox.PolylineAnnotationManager? manager = _routeLines;
    if (manager == null) {
      return;
    }

    if (rider == null || destination == null || _mapboxAccessToken.isEmpty) {
      await manager.deleteAll();
      return;
    }

    final bool originUnchanged =
        _lastRouteOrigin != null &&
        Geolocator.distanceBetween(
              _lastRouteOrigin!.latitude,
              _lastRouteOrigin!.longitude,
              rider.latitude,
              rider.longitude,
            ) <
            50;
    final bool destinationUnchanged =
        _lastRouteDestination != null &&
        Geolocator.distanceBetween(
              _lastRouteDestination!.latitude,
              _lastRouteDestination!.longitude,
              destination.latitude,
              destination.longitude,
            ) <
            5;

    if (_routeRequestInProgress || (originUnchanged && destinationUnchanged)) {
      return;
    }

    _routeRequestInProgress = true;
    try {
      final String coordinates =
          '${rider.longitude},${rider.latitude};'
          '${destination.longitude},${destination.latitude}';
      final Response<Map<String, dynamic>>
      response = await _dio.get<Map<String, dynamic>>(
        'https://api.mapbox.com/directions/v5/mapbox/driving-traffic/$coordinates',
        queryParameters: <String, dynamic>{
          'access_token': _mapboxAccessToken,
          'geometries': 'geojson',
          'overview': 'full',
          'steps': false,
        },
      );

      final List<dynamic> routes =
          response.data?['routes'] as List<dynamic>? ?? <dynamic>[];
      if (routes.isEmpty) {
        await manager.deleteAll();
        return;
      }

      final Map<String, dynamic> route = Map<String, dynamic>.from(
        routes.first as Map,
      );
      final Map<String, dynamic> geometry = Map<String, dynamic>.from(
        route['geometry'] as Map,
      );
      final List<dynamic> rawCoordinates =
          geometry['coordinates'] as List<dynamic>;
      final List<mapbox.Position> positions = rawCoordinates.map((
        dynamic value,
      ) {
        final List<dynamic> coordinate = value as List<dynamic>;
        return mapbox.Position(
          (coordinate[0] as num).toDouble(),
          (coordinate[1] as num).toDouble(),
        );
      }).toList();

      if (positions.length < 2) {
        return;
      }

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
      _lastRouteOrigin = rider;
      _lastRouteDestination = destination;
    } catch (_) {
      // Keep the markers visible when Mapbox cannot calculate a route.
    } finally {
      _routeRequestInProgress = false;
    }
  }

  mapbox.Point _toMapboxPoint(LatLng point) {
    return mapbox.Point(
      coordinates: mapbox.Position(point.longitude, point.latitude),
    );
  }

  Future<LatLng> _getNavigationOrigin() async {
    final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw StateError('Turn on location services to start navigation.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw StateError('Location permission is required for rider navigation.');
    }

    try {
      final Position current = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          timeLimit: Duration(seconds: 20),
        ),
      );
      final LatLng origin = LatLng(current.latitude, current.longitude);

      if (mounted) {
        final DateTime now = DateTime.now();
        setState(() {
          _liveRiderLocation = origin;
          _liveRiderLocationUpdatedAt = now;
          _lastUiLocationUpdateAt = now;
        });
      }
      return origin;
    } on TimeoutException {
      final DateTime? liveLocationTime = _liveRiderLocationUpdatedAt;
      final LatLng? liveLocation = _liveRiderLocation;
      if (liveLocation != null &&
          liveLocationTime != null &&
          DateTime.now().difference(liveLocationTime) <
              const Duration(minutes: 2)) {
        return liveLocation;
      }

      final Position? lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null &&
          DateTime.now().difference(lastKnown.timestamp) <
              const Duration(minutes: 2)) {
        final LatLng origin = LatLng(lastKnown.latitude, lastKnown.longitude);
        if (mounted) {
          final DateTime now = lastKnown.timestamp;
          setState(() {
            _liveRiderLocation = origin;
            _liveRiderLocationUpdatedAt = now;
            _lastUiLocationUpdateAt = now;
          });
        }
        return origin;
      }
      throw StateError(
        'Unable to pinpoint your current location. Try again with GPS enabled.',
      );
    }
  }

  Future<void> _startMapboxNavigation(RiderDeliveryData delivery) async {
    if (_startingNavigation) {
      return;
    }

    if (!_supportsMapbox) {
      _showMessage('Mapbox navigation is available on Android and iOS.');
      return;
    }

    if (_mapboxAccessToken.isEmpty) {
      _showMessage('Add your Mapbox access token before starting navigation.');
      return;
    }

    setState(() {
      _startingNavigation = true;
    });

    try {
      await _resolveBuyerLocation();
      final LatLng? destination = _displayDeliveryLocation;
      if (destination == null) {
        throw StateError('The buyer delivery location could not be found.');
      }

      final LatLng origin;
      if (delivery.isPreview) {
        origin = _sampleRiderLocation;
        if (mounted) {
          final DateTime now = DateTime.now();
          setState(() {
            _liveRiderLocation = origin;
            _liveRiderLocationUpdatedAt = now;
            _lastUiLocationUpdateAt = now;
          });
        }
      } else {
        origin = await _getNavigationOrigin();
      }
      final double distanceToBuyer = Geolocator.distanceBetween(
        origin.latitude,
        origin.longitude,
        destination.latitude,
        destination.longitude,
      );
      if (distanceToBuyer < 10) {
        throw StateError('You are already at the buyer delivery location.');
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
        simulateRoute: delivery.isPreview,
        language: 'en',
      );

      final bool? navigationStarted = await navigation.MapBoxNavigation.instance
          .startNavigation(
            wayPoints: <navigation.WayPoint>[
              navigation.WayPoint(
                name: 'Rider location',
                latitude: origin.latitude,
                longitude: origin.longitude,
              ),
              navigation.WayPoint(
                name: delivery.buyerName.trim().isEmpty
                    ? 'Buyer delivery location'
                    : delivery.buyerName.trim(),
                latitude: destination.latitude,
                longitude: destination.longitude,
              ),
            ],
            options: options,
          )
          .timeout(const Duration(seconds: 5), onTimeout: () => true);
      if (navigationStarted == false) {
        throw StateError('Mapbox could not build a route to the buyer.');
      }
    } catch (error) {
      if (mounted) {
        final String message = error.toString().replaceFirst('Bad state: ', '');
        _showMessage('Unable to start navigation: $message');
      }
    } finally {
      if (mounted) {
        setState(() {
          _startingNavigation = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _dio.close();
    _receiverController.dispose();
    _failedReasonController.dispose();

    super.dispose();
  }

  Future<void> _takeProofPhoto() async {
    if (_takingPhoto) {
      return;
    }

    setState(() {
      _takingPhoto = true;
    });

    try {
      final String riderName = (await AuthService.getCurrentUser()).name.trim();
      if (riderName.isEmpty) {
        throw Exception('Unable to load the rider name for the watermark.');
      }
      final Position position =
          await RiderProofWatermark.requireCurrentPosition();

      if (!mounted) {
        return;
      }

      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,

        /// Keep delivery proof reasonably sized
        /// before multipart upload.
        imageQuality: 82,

        maxWidth: 1920,
        maxHeight: 1920,

        preferredCameraDevice: CameraDevice.rear,
      );

      if (!mounted) {
        return;
      }

      if (photo == null) {
        return;
      }

      final String stampedPath = await RiderProofWatermark.stamp(
        imagePath: photo.path,
        riderName: riderName,
        capturedAt: DateTime.now(),
        position: position,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _proofPhoto = XFile(stampedPath);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to capture watermarked proof: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _takingPhoto = false;
        });
      }
    }
  }

  void _removeProofPhoto() {
    setState(() {
      _proofPhoto = null;
    });
  }

  Future<void> _markInTransit(RiderDeliveryData delivery) async {
    await _submitTransition(
      RiderDeliveryTransitionRequest(delivery: delivery, status: 'in_transit'),
    );
  }

  Future<void> _acceptAssignment(RiderDeliveryData delivery) async {
    await _submitTransition(
      RiderDeliveryTransitionRequest(delivery: delivery, status: 'accepted'),
    );
  }

  Future<void> _markOutForDelivery(RiderDeliveryData delivery) async {
    await _submitTransition(
      RiderDeliveryTransitionRequest(
        delivery: delivery,
        status: 'out_for_delivery',
      ),
    );
  }

  Future<void> _markDelivered(RiderDeliveryData delivery) async {
    final String receiverName = _receiverController.text.trim();

    if (receiverName.isEmpty) {
      _showMessage('Enter the receiver name.');

      return;
    }

    if (_proofPhoto == null) {
      _showMessage('Take a proof of delivery photo first.');

      return;
    }

    final RiderDeliveryTransitionRequest request =
        RiderDeliveryTransitionRequest(
          delivery: delivery,
          status: 'delivered',
          receiverName: receiverName,
          proofPath: _proofPhoto!.path,
        );

    await _submitTransition(request);
  }

  Future<void> _recordFailedDelivery(RiderDeliveryData delivery) async {
    final String reason = _failedReasonController.text.trim();

    if (reason.isEmpty) {
      _showMessage('Enter the reason for the failed delivery.');

      return;
    }

    final RiderDeliveryTransitionRequest request =
        RiderDeliveryTransitionRequest(
          delivery: delivery,
          status: 'failed',
          note: reason,
        );

    await _submitTransition(request);
  }

  Future<void> _submitTransition(RiderDeliveryTransitionRequest request) async {
    if (_submitting) {
      return;
    }

    if (!request.isValid) {
      _showMessage('Please complete the required delivery information.');

      return;
    }

    if (_usingPreview) {
      _showMessage('Preview only. This action is not saved to Laravel.');

      return;
    }

    final RiderDeliveryTransitionCallback? callback = widget.onTransition;

    if (callback == null) {
      _showMessage('The Rider delivery API is not connected yet.');

      return;
    }

    setState(() {
      _submitting = true;
    });

    try {
      await callback(request);

      if (!mounted) {
        return;
      }
      setState(() {
        _locationSyncEnabled = _isActiveDeliveryStatus(request.status);
      });

      _showMessage('Delivery status updated successfully.');
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to update delivery: $error');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final RiderDeliveryData? parcel = _displayDelivery;

    if (parcel == null) {
      return _buildMissingDelivery();
    }

    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed:
              widget.onBack ??
              () {
                Navigator.of(context).maybePop();
              },
          icon: const Icon(Icons.arrow_back_rounded, color: _text),
        ),
        title: const Text(
          'Delivery Tracking',
          style: TextStyle(
            color: _text,
            fontSize: 19,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
          children: <Widget>[
            if (_usingPreview) ...<Widget>[
              const _TrackingPreviewNotice(),
              const SizedBox(height: 14),
            ],
            _buildHero(parcel),
            const SizedBox(height: 14),
            _buildLiveMap(parcel),
            const SizedBox(height: 14),
            _buildTimeline(parcel),
            const SizedBox(height: 14),
            _buildRecipient(parcel),
            const SizedBox(height: 14),

            /// DELIVERY ACTIONS INCLUDING
            /// CAMERA PROOF OF DELIVERY.
            _buildDeliveryActions(parcel),

            const SizedBox(height: 14),

            _buildGeneralActions(parcel),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingDelivery() {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        elevation: 0,
        leading: IconButton(
          onPressed:
              widget.onBack ??
              () {
                Navigator.of(context).maybePop();
              },
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: const Text('Delivery Tracking'),
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.location_off_outlined, color: _mutedLight, size: 52),
              SizedBox(height: 14),
              Text(
                'Delivery not available',
                style: TextStyle(
                  color: _text,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 6),
              Text(
                'Open a valid rider delivery to view its tracking information.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero(RiderDeliveryData parcel) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'LIVE DELIVERY',
            style: TextStyle(
              color: _maroon,
              fontSize: 11.5,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            parcel.trackingCode,
            style: const TextStyle(
              color: _text,
              fontSize: 25,
              height: 1.1,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${parcel.statusLabel} · ${parcel.address}',
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveMap(RiderDeliveryData parcel) {
    final bool hasDestination = _displayDeliveryLocation != null;
    final bool hasRider = _displayRiderLocation != null;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 13),
            child: Row(
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1E4D7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.map_outlined,
                    color: _maroon,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Live Delivery Map',
                        style: TextStyle(
                          color: _text,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Live rider location and route to the buyer.',
                        style: TextStyle(color: _muted, fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 310,
            child: Stack(
              children: <Widget>[
                if (_canShowMapbox)
                  Positioned.fill(
                    child: mapbox.MapWidget(
                      viewport: mapbox.CameraViewportState(
                        center: _toMapboxPoint(_lastMapCenter),
                        zoom: _zoomLevel,
                      ),
                      onMapCreated: _onMapboxMapCreated,
                    ),
                  )
                else
                  Positioned.fill(
                    child: ColoredBox(
                      color: _soft,
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
                        Container(
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
                            onPressed: () => _zoomMap(1),
                            icon: const Icon(Icons.add, color: _text),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
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
                            onPressed: () => _zoomMap(-1),
                            icon: const Icon(Icons.remove, color: _text),
                            splashRadius: 20,
                            padding: EdgeInsets.zero,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (_canShowMapbox && !hasDestination)
                  Positioned.fill(
                    child: IgnorePointer(
                      child: Center(
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              _geocodingBuyerLocation
                                  ? 'Finding buyer location...'
                                  : 'Waiting for buyer location',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              children: <Widget>[
                _MapLegendDot(
                  color: _maroon,
                  label: hasDestination
                      ? 'Buyer location'
                      : 'Buyer location unavailable',
                ),
                _MapLegendRider(
                  color: _riderColor,
                  label: hasRider
                      ? 'Current rider location'
                      : 'Rider GPS unavailable',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(RiderDeliveryData parcel) {
    final List<_TrackingStep> steps = <_TrackingStep>[
      const _TrackingStep('assigned', 'Assigned To Rider'),
      const _TrackingStep('accepted', 'Accepted'),
      const _TrackingStep('out_for_delivery', 'Out For Delivery'),
      const _TrackingStep('delivered', 'Delivered'),
      const _TrackingStep('delivery_failed', 'Delivery Failed'),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          ...List<Widget>.generate(steps.length, (int index) {
            final _TrackingStep step = steps[index];
            final bool isLast = index == steps.length - 1;
            final String current = parcel.normalizedStatus;
            final bool isFailed =
                current == 'failed' || current == 'delivery_failed';
            final bool isCurrent =
                current == step.status ||
                (step.status == 'delivery_failed' && isFailed);
            final bool isDone = _TrackingStepCard._isStepDone(
              step.status,
              current,
            );

            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 26,
                    child: Column(
                      children: <Widget>[
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: isCurrent || isDone
                                ? _maroon
                                : const Color(0xFFEDE4DC),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isCurrent || isDone
                                  ? _maroon
                                  : const Color(0xFFD9CFC3),
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      step.label,
                      style: TextStyle(
                        color: isCurrent || isDone ? _text : _muted,
                        fontSize: 15,
                        fontWeight: isCurrent || isDone
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildRecipient(RiderDeliveryData parcel) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'Recipient',
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 13),
          _InfoRow(label: 'Buyer', value: parcel.buyerName),
          const SizedBox(height: 10),
          _InfoRow(label: 'Contact', value: parcel.contact),
          const SizedBox(height: 10),
          _InfoRow(label: 'Delivery Address', value: parcel.address),
          const SizedBox(height: 10),
          _InfoRow(
            label: 'Order Amount',
            value: formatRiderMoney(parcel.amount),
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryActions(RiderDeliveryData parcel) {
    final String status = parcel.normalizedStatus;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Delivery Actions',
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 15),

          if (status == 'picked_up') ...<Widget>[
            _PrimaryActionButton(
              label: 'Mark In Transit',
              icon: Icons.local_shipping_outlined,
              loading: _submitting,
              onPressed: () {
                _markInTransit(parcel);
              },
            ),
          ],

          if (status == 'assigned') ...<Widget>[
            _PrimaryActionButton(
              label: 'Accept Assignment',
              icon: Icons.assignment_turned_in_outlined,
              loading: _submitting,
              onPressed: () => _acceptAssignment(parcel),
            ),
          ],

          if (status == 'accepted') ...<Widget>[
            _PrimaryActionButton(
              label: 'Start Delivery',
              icon: Icons.near_me_outlined,
              loading: _submitting,
              onPressed: () => _markOutForDelivery(parcel),
            ),
          ],

          if (status == 'in_transit') ...<Widget>[
            _PrimaryActionButton(
              label: 'Out For Delivery',
              icon: Icons.near_me_outlined,
              loading: _submitting,
              onPressed: () {
                _markOutForDelivery(parcel);
              },
            ),
          ],

          if (status == 'out_for_delivery') ...<Widget>[
            TextField(
              controller: _receiverController,
              enabled: !_submitting,
              textInputAction: TextInputAction.next,
              decoration: _inputDecoration(
                hintText: 'Receiver name',
                prefixIcon: Icons.person_outline_rounded,
              ),
            ),

            const SizedBox(height: 12),

            _buildProofSection(),

            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _submitting
                    ? null
                    : () {
                        _markDelivered(parcel);
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _success,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _submitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded),
                label: const Text(
                  'Mark Delivered',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),

            const SizedBox(height: 18),

            const Divider(color: _border, height: 1),

            const SizedBox(height: 18),

            TextField(
              controller: _failedReasonController,
              enabled: !_submitting,
              minLines: 3,
              maxLines: 5,
              decoration: _inputDecoration(
                hintText: 'Reason for failed delivery',
                prefixIcon: Icons.report_problem_outlined,
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () {
                        _recordFailedDelivery(parcel);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _danger,
                  backgroundColor: const Color(0xFFFFF3F2),
                  side: const BorderSide(color: Color(0xFFF5B7B1)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.cancel_outlined),
                label: const Text(
                  'Record Delivery Failed',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ),
          ],

          if (status == 'assigned' ||
              status == 'delivered' ||
              status == 'failed' ||
              status == 'delivery_failed')
            _buildNoCurrentAction(status),
        ],
      ),
    );
  }

  Widget _buildProofSection() {
    final XFile? photo = _proofPhoto;

    if (photo == null) {
      return InkWell(
        onTap: _takingPhoto ? null : _takeProofPhoto,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFFCF9F5),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: <Widget>[
              Container(
                width: 54,
                height: 54,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFF1E4D7),
                  shape: BoxShape.circle,
                ),
                child: _takingPhoto
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _maroon,
                        ),
                      )
                    : const Icon(
                        Icons.photo_camera_outlined,
                        color: _maroon,
                        size: 27,
                      ),
              ),
              const SizedBox(height: 11),
              Text(
                _takingPhoto ? 'Opening Camera...' : 'Take Proof of Delivery',
                style: const TextStyle(
                  color: _text,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Take a clear photo showing that the parcel was delivered.',
                textAlign: TextAlign.center,
                style: TextStyle(color: _muted, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _takingPhoto ? null : _takeProofPhoto,
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Open Camera'),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AspectRatio(
            aspectRatio: 4 / 3,
            child: Image.file(
              File(photo.path),
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 40,
                        color: _mutedLight,
                      ),
                    );
                  },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.check_circle_rounded,
                  color: _success,
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Proof of delivery photo captured',
                    style: TextStyle(
                      color: _text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Take another photo',
                  onPressed: _submitting ? null : _takeProofPhoto,
                  icon: const Icon(Icons.photo_camera_outlined, color: _maroon),
                ),
                IconButton(
                  tooltip: 'Remove proof',
                  onPressed: _submitting ? null : _removeProofPhoto,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: _danger,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoCurrentAction(String status) {
    String message = 'No delivery action is available for this parcel.';

    if (status == 'assigned') {
      message = 'Accept this delivery assignment before starting the delivery.';
    }

    if (status == 'delivered') {
      message = 'This parcel has already been marked as delivered.';
    }

    if (status == 'failed' || status == 'delivery_failed') {
      message = 'This delivery has been recorded as failed.';
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: const TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
      ),
    );
  }

  Widget _buildGeneralActions(RiderDeliveryData parcel) {
    final bool hasContact =
        parcel.contact.trim().isNotEmpty &&
        parcel.contact.trim().toLowerCase() != 'no contact recorded' &&
        parcel.contact.trim().toLowerCase() != 'not available';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            'Actions',
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 49,
            child: ElevatedButton.icon(
              onPressed: widget.onOpenDetails == null
                  ? null
                  : () {
                      widget.onOpenDetails!(parcel);
                    },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text(
                'Open Delivery Details',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          const SizedBox(height: 9),
          _TrackingActionButton(
            icon: Icons.navigation_outlined,
            label: _startingNavigation
                ? 'Starting Navigation...'
                : 'Start Mapbox Navigation',
            onPressed: _startingNavigation
                ? null
                : () async {
                    if (widget.onOpenNavigation != null) {
                      await widget.onOpenNavigation!(parcel);
                      return;
                    }

                    await _startMapboxNavigation(parcel);
                  },
          ),
          if (hasContact) ...<Widget>[
            const SizedBox(height: 9),
            _TrackingActionButton(
              icon: Icons.phone_outlined,
              label: 'Contact Customer',
              onPressed: widget.onContactCustomer == null
                  ? null
                  : () async {
                      await widget.onContactCustomer!(parcel);
                    },
            ),
          ],
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _mutedLight, fontSize: 13),
      prefixIcon: Icon(prefixIcon, color: _muted, size: 20),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _maroon, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger),
      ),
    );
  }
}

class _TrackingStep {
  final String status;
  final String label;

  const _TrackingStep(this.status, this.label);
}

class _TrackingStepCard extends StatelessWidget {
  static const Color _accent = Color(0xFF561C17);
  static const Color _muted = Color(0xFF987865);
  static const Color _text = Color(0xFF3B211B);
  static const Color _inactive = Color(0xFFEDE4DC);
  static const Color _line = Color(0xFFD9CFC3);

  final _TrackingStep step;

  final RiderDeliveryData delivery;

  const _TrackingStepCard({required this.step, required this.delivery});

  @override
  Widget build(BuildContext context) {
    final String current = delivery.normalizedStatus;
    final String stepStatus = step.status;
    final bool isFailed = current == 'failed' || current == 'delivery_failed';
    final bool isCurrent =
        current == stepStatus || (stepStatus == 'delivery_failed' && isFailed);
    final bool isDone = _isStepDone(stepStatus, current);
    final bool active = isCurrent || isDone;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(top: 3),
          decoration: BoxDecoration(
            color: active ? _accent : _inactive,
            shape: BoxShape.circle,
            border: Border.all(color: active ? _accent : _line, width: 2),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                step.label,
                style: TextStyle(
                  color: active ? _text : _muted,
                  fontSize: 15,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
              if (stepStatus == 'delivery_failed' &&
                  isFailed &&
                  delivery.failureReason?.trim().isNotEmpty ==
                      true) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  delivery.failureReason!,
                  style: const TextStyle(
                    color: _muted,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static bool _isStepDone(String stepStatus, String current) {
    const List<String> progression = <String>[
      'assigned',
      'accepted',
      'out_for_delivery',
      'delivered',
    ];

    if (stepStatus == 'delivery_failed') {
      return false;
    }

    final int stepIndex = progression.indexOf(stepStatus);
    final int currentIndex = progression.indexOf(
      current == 'in_transit' ? 'out_for_delivery' : current,
    );

    if (stepIndex < 0 || currentIndex < 0) {
      return false;
    }

    return currentIndex > stepIndex;
  }
}

class _PrimaryActionButton extends StatelessWidget {
  final String label;

  final IconData icon;

  final bool loading;

  final VoidCallback onPressed;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ElevatedButton.icon(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: const Color(0xFF561C17),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
      ),
    );
  }
}

class _TrackingActionButton extends StatelessWidget {
  final IconData icon;

  final String label;

  final Future<void> Function()? onPressed;

  const _TrackingActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF3B211B),
          side: const BorderSide(color: Color(0xFFEADCCC)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;

  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF987865),
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF3B211B),
            fontSize: 13.5,
            height: 1.45,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _MapLegendDot extends StatelessWidget {
  final Color color;

  final String label;

  const _MapLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF766C65), fontSize: 11),
        ),
      ],
    );
  }
}

class _MapLegendRider extends StatelessWidget {
  final Color color;

  final String label;

  const _MapLegendRider({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 19,
          height: 19,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: const Icon(
            Icons.two_wheeler_rounded,
            color: Colors.white,
            size: 13,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF766C65), fontSize: 11),
        ),
      ],
    );
  }
}

class _TrackingPreviewNotice extends StatelessWidget {
  const _TrackingPreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF6EFE7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.visibility_outlined, color: Color(0xFF561C17), size: 19),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Sample tracking preview only. Sample locations are not stored in Laravel. Real shipment data and GPS coordinates will come from the backend.',
              style: TextStyle(
                color: Color(0xFF987865),
                fontSize: 12.5,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

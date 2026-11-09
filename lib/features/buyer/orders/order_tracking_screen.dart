import 'package:likhae/core/theme/app_theme.dart';

import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart' show LatLng;
import 'package:likhae/shared/map/maplibre_compat.dart' as maplibre;

import '../../../core/config/app_config.dart';
import '../../../core/api/api_client.dart';
import '../../../services/buyer_mobile_service.dart';
import '../../../services/realtime_service.dart';
import 'orders_screen.dart';
import 'buyer_tracking_navigation.dart';
import 'buyer_map_marker_icons.dart';

class OrderTrackingScreen extends StatefulWidget {
  final BuyerOrderData order;

  final VoidCallback? onBack;
  final Widget? previewMap;

  const OrderTrackingScreen({
    super.key,
    required this.order,
    this.onBack,
    this.previewMap,
  });

  @override
  State<OrderTrackingScreen> createState() => _OrderTrackingScreenState();
}

class _OrderTrackingScreenState extends State<OrderTrackingScreen> {
  static const Duration _locationRefreshInterval = Duration(seconds: 10);
  static const Duration _minimumRouteRefreshInterval = Duration(seconds: 45);
  static const double _minimumRerouteDistanceMeters = 100;
  static const Duration _maximumRiderRouteAge = Duration(minutes: 2);
  static const Duration _riderRouteRetryDelay = Duration(seconds: 30);
  static const double _riderRouteOffPathMeters = 100;
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

  maplibre.MapLibreSession? _mapLibreMap;
  maplibre.CircleAnnotationManager? _mapMarkers;
  maplibre.PointAnnotationManager? _routeLabels;
  maplibre.PolylineAnnotationManager? _routeLines;
  final Map<String, maplibre.PolylineAnnotation> _roadRouteSegments =
      <String, maplibre.PolylineAnnotation>{};
  final BuyerMapMarkerIcons _markerIcons = BuyerMapMarkerIcons();
  List<maplibre.Position> _roadRoutePositions = <maplibre.Position>[];
  List<BuyerOrderLocation> _roadRouteStops = <BuyerOrderLocation>[];
  double _confirmedRouteProgress = 0;
  BuyerTrackingNavigation? _navigation;
  String? _guidanceKey;
  LatLng? _lastGuidanceOrigin;
  DateTime? _guidanceFetchedAt;
  DateTime? _guidanceFailedAt;
  List<maplibre.Position> _guidanceRoutePositions = <maplibre.Position>[];
  double? _guidanceDistance;
  double? _guidanceDuration;
  DateTime? _guidanceArrivalAt;
  bool _guidanceUnavailable = false;
  bool _guidanceInProgress = false;
  int _mapGeneration = 0;
  List<maplibre.CircleAnnotation> _circleAnnotations =
      <maplibre.CircleAnnotation>[];
  List<maplibre.PointAnnotation> _pointAnnotations =
      <maplibre.PointAnnotation>[];
  List<_TrackingMapMarkerSpec> _renderedMapMarkers = <_TrackingMapMarkerSpec>[];

  late BuyerOrderData _trackedOrder;
  String? _selectedParcelId;
  Timer? _locationRefreshTimer;
  RealtimeSubscription? _shipmentRealtime;
  bool _refreshingLocation = false;
  bool _refreshingShipmentMap = false;
  bool _hasLoadedShipmentMap = false;
  bool _sellerPinUnavailable = false;
  bool _riderGpsPending = false;
  bool _shipmentMapUnavailable = false;
  bool _locationRefreshErrorShown = false;
  bool _syncingMapAnnotations = false;
  bool _mapSyncQueued = false;
  bool _queuedMapSyncRecenters = false;
  bool _routeRequestInProgress = false;
  LatLng? _lastRouteOrigin;
  DateTime? _lastRouteRequestAt;
  String? _lastRouteTopologyKey;
  bool _roadRouteUnavailable = false;
  bool _straightRouteFallback = false;
  bool _mapExpanded = false;
  double? _roadDistanceMeters;
  double? _roadDurationSeconds;

  double _zoomLevel = 14;
  LatLng _lastMapCenter = _defaultCenter;

  BuyerOrderParcelData? get _selectedParcel {
    if (_trackedOrder.parcels.isEmpty) return null;
    for (final BuyerOrderParcelData parcel in _trackedOrder.parcels) {
      if (parcel.id == _selectedParcelId) return parcel;
    }
    return _trackedOrder.parcels.firstWhere(
      (BuyerOrderParcelData parcel) => parcel.status == 'OUT_FOR_DELIVERY',
      orElse: () => _trackedOrder.parcels.first,
    );
  }

  BuyerOrderData get order {
    final BuyerOrderParcelData? parcel = _selectedParcel;
    if (parcel == null) return _trackedOrder;
    final List<String> proofUrls = parcel.id == _trackedOrder.shipmentId
        ? _trackedOrder.deliveryProofImageUrls
        : const <String>[];
    return _trackedOrder.copyWith(
      tracking: parcel.trackingNumber,
      clearTracking: parcel.trackingNumber == null,
      shipmentId: parcel.id,
      backendStatus: parcel.status.toLowerCase(),
      statusLabel: parcel.statusLabel,
      riderLocation: parcel.riderLocation,
      clearRiderLocation: parcel.riderLocation == null,
      timeline: parcel.timeline,
      deliveryProofImageUrls: proofUrls,
    );
  }

  static String _humanizeStatus(String value) {
    return value
        .replaceAll(RegExp(r'[_-]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .split(' ')
        .where((String word) => word.isNotEmpty)
        .map(
          (String word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
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
    final String key = event.label.toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
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
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
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
    _selectedParcelId = _requestedParcelId(widget.order);
    if (AppConfig.apiEnabled &&
        !widget.order.isPreview &&
        widget.previewMap == null) {
      unawaited(_loadDeliveryProof().then<void>((bool _) {}));
      unawaited(_refreshShipmentMap());
      _locationRefreshTimer = Timer.periodic(_locationRefreshInterval, (_) {
        if (mounted &&
            WidgetsBinding.instance.lifecycleState ==
                AppLifecycleState.resumed &&
            ModalRoute.of(context)?.isCurrent != false) {
          setState(() {});
          unawaited(_refreshOrderLocation());
          unawaited(_refreshShipmentMap());
        }
      });
      unawaited(_connectShipmentRealtime());
    }
  }

  static String? _defaultParcelId(List<BuyerOrderParcelData> parcels) {
    for (final BuyerOrderParcelData parcel in parcels) {
      if (parcel.status == 'OUT_FOR_DELIVERY') return parcel.id;
    }
    return parcels.isEmpty ? null : parcels.first.id;
  }

  static String? _requestedParcelId(BuyerOrderData order) {
    if (order.shipmentId != null &&
        order.parcels.any(
          (BuyerOrderParcelData parcel) => parcel.id == order.shipmentId,
        )) {
      return order.shipmentId;
    }
    return _defaultParcelId(order.parcels);
  }

  Future<bool> _loadDeliveryProof({bool force = false}) async {
    final BuyerOrderData initialOrder = order;
    if ((!force && initialOrder.deliveryProofImageUrls.isNotEmpty) ||
        _selectedParcel?.deliveryProofAttemptIds.isNotEmpty == true) {
      return true;
    }
    if (!AppConfig.apiEnabled ||
        initialOrder.isPreview ||
        initialOrder.id.trim().isEmpty) {
      return false;
    }

    final bool deliveryComplete =
        const <String>{
          'delivered',
          'completed',
          'complete',
        }.contains(initialOrder.normalizedStatus) ||
        initialOrder.timeline.any((BuyerOrderTimelineEvent event) {
          final String label = event.label.toLowerCase();
          return label.contains('delivered') ||
              label.contains('delivery successful') ||
              label.contains('delivery complete');
        });
    if (!deliveryComplete) return true;

    try {
      final BuyerOrderData detail = await BuyerMobileService.fetchOrder(
        initialOrder.id,
      );
      if (!mounted || detail.id != initialOrder.id) return false;

      final List<String> proofUrls = List<String>.from(
        _trackedOrder.deliveryProofImageUrls,
      );
      for (final String proofUrl in detail.deliveryProofImageUrls) {
        if (!proofUrls.contains(proofUrl)) proofUrls.add(proofUrl);
      }

      final List<BuyerOrderParcelData> sourceParcels = detail.parcels.isEmpty
          ? _trackedOrder.parcels
          : detail.parcels;
      final List<BuyerOrderParcelData> parcels = sourceParcels
          .map((BuyerOrderParcelData parcel) {
            if (parcel.id == _selectedParcelId &&
                parcel.riderLocation == null &&
                order.riderLocation != null) {
              return parcel.copyWith(riderLocation: order.riderLocation);
            }
            return parcel;
          })
          .toList(growable: false);

      setState(() {
        _trackedOrder = _trackedOrder.copyWith(
          parcels: parcels,
          riderLocation: order.riderLocation ?? detail.riderLocation,
          deliveryProofImageUrls: proofUrls,
        );
      });
      return true;
    } catch (_) {
      // The tracking screen still works if the optional proof lookup fails.
      return false;
    }
  }

  @override
  void didUpdateWidget(covariant OrderTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.id != widget.order.id) {
      _trackedOrder = widget.order;
      _selectedParcelId = _requestedParcelId(widget.order);
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
          final double? latitude = double.tryParse(
            (event.data['latitude'] ?? '').toString(),
          );
          final double? longitude = double.tryParse(
            (event.data['longitude'] ?? '').toString(),
          );
          if (latitude == null || longitude == null) continue;
          await _applyRiderLocation(
            BuyerOrderLocation(
              latitude: latitude,
              longitude: longitude,
              label: 'Rider location',
            ),
          );
        } else if (event.name == 'shipment.tracking.updated') {
          final String status =
              (event.data['current_status'] ??
                      event.data['status'] ??
                      event.data['status_code'] ??
                      '')
                  .toString()
                  .trim();
          if (status.isEmpty) continue;
          final String label =
              (event.data['label'] ??
                      event.data['status_label'] ??
                      _humanizeStatus(status))
                  .toString()
                  .trim();
          final dynamic rawDetails =
              event.data['notes'] ??
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
          final List<String> deliveryProofImageUrls = List<String>.from(
            order.deliveryProofImageUrls,
          );
          for (final String proofUrl in parseBuyerDeliveryProofUrls(
            <Map<String, dynamic>>[event.data],
          )) {
            if (!deliveryProofImageUrls.contains(proofUrl)) {
              deliveryProofImageUrls.add(proofUrl);
            }
          }
          setState(() {
            final BuyerOrderParcelData? selected = _selectedParcel;
            if (selected == null) {
              _trackedOrder = _trackedOrder.copyWith(
                backendStatus: status,
                statusLabel: label.isEmpty ? _humanizeStatus(status) : label,
                timeline: timeline,
                deliveryProofImageUrls: deliveryProofImageUrls,
              );
            } else {
              _replaceSelectedParcel(
                selected.copyWith(
                  status: status,
                  statusLabel: label.isEmpty ? _humanizeStatus(status) : label,
                  timeline: timeline,
                ),
              );
              _trackedOrder = _trackedOrder.copyWith(
                deliveryProofImageUrls: deliveryProofImageUrls,
              );
            }
          });
          unawaited(_refreshShipmentDetails());
          await _syncMapLibreMarkers(recenter: false);
        }
      }
    } catch (_) {
      // The existing location request remains the safe fallback.
    }
  }

  Future<void> _refreshShipmentDetails() async {
    final String orderId = order.id;
    try {
      final BuyerOrderData detail = await BuyerMobileService.fetchOrder(
        orderId,
      );
      if (!mounted || detail.id != orderId) return;

      final List<String> proofUrls = List<String>.from(
        _trackedOrder.deliveryProofImageUrls,
      );
      for (final String proofUrl in detail.deliveryProofImageUrls) {
        if (!proofUrls.contains(proofUrl)) proofUrls.add(proofUrl);
      }
      final List<BuyerOrderParcelData> parcels = detail.parcels
          .map((BuyerOrderParcelData parcel) {
            if (parcel.id == _selectedParcelId &&
                parcel.riderLocation == null &&
                order.riderLocation != null) {
              return parcel.copyWith(riderLocation: order.riderLocation);
            }
            return parcel;
          })
          .toList(growable: false);
      setState(() {
        _trackedOrder = detail.copyWith(
          parcels: parcels,
          riderLocation: order.riderLocation ?? detail.riderLocation,
          deliveryProofImageUrls: proofUrls,
        );
      });
      await _syncMapLibreMarkers(recenter: false);
    } catch (_) {
      // Keep the last route visible until the order API is reachable again.
    }
  }

  Future<void> _refreshOrderLocation() async {
    if (_refreshingLocation || order.id.isEmpty) {
      return;
    }
    _refreshingLocation = true;
    final shipmentId = order.shipmentId;
    try {
      final BuyerRiderSnapshot riderSnapshot =
          await BuyerMobileService.fetchRiderSnapshot(
            order.id,
            shipmentId: order.shipmentId,
          );
      if (!mounted || order.shipmentId != shipmentId) {
        return;
      }
      await _applyRiderLocation(riderSnapshot.location);
      _applyRiderInfo(riderSnapshot.rider);
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

  Future<void> _refreshShipmentMap() async {
    final String trackingNumber = order.tracking?.trim() ?? '';
    if (_refreshingShipmentMap ||
        !AppConfig.apiEnabled ||
        order.isPreview ||
        trackingNumber.isEmpty) {
      return;
    }

    _refreshingShipmentMap = true;
    final generation = _mapGeneration;
    try {
      final Map<String, dynamic> trackingData =
          await BuyerMobileService.fetchShipmentMap(trackingNumber);
      if (!mounted ||
          generation != _mapGeneration ||
          order.tracking?.trim() != trackingNumber) {
        return;
      }

      final Map<String, dynamic> mapPayload =
          BuyerTrackingNavigation.normalizePayload(trackingData);
      final bool firstMapLoad = !_hasLoadedShipmentMap;
      final dynamic rawMarkers =
          mapPayload['map_markers'] ?? mapPayload['markers'];
      if (rawMarkers is! List) {
        if (mounted) setState(() => _shipmentMapUnavailable = true);
        return;
      }
      final List<Map<String, dynamic>> markers = rawMarkers
          .whereType<Map>()
          .map((Map marker) => Map<String, dynamic>.from(marker))
          .toList(growable: false);

      BuyerOrderLocation? markerLocation(Map<String, dynamic> marker) =>
          parseBuyerOrderLogisticsStop({
            ...marker,
            'label': <String>[
              (marker['label'] ?? '').toString(),
              (marker['popup'] ?? '').toString(),
            ].where((value) => value.isNotEmpty).join(' · '),
          });
      bool isSeller(Map<String, dynamic> marker) =>
          marker['target_kind'] == 'seller' || marker['kind'] == 'seller';
      bool isBuyer(Map<String, dynamic> marker) =>
          marker['target_kind'] == 'buyer' || marker['kind'] == 'destination';
      bool isHub(Map<String, dynamic> marker) =>
          marker['target_kind'] == 'logistics' || marker['kind'] == 'center';

      Map<String, dynamic>? firstMarkerWhere(
        bool Function(Map<String, dynamic>) predicate,
      ) {
        for (final Map<String, dynamic> marker in markers) {
          if (predicate(marker)) return marker;
        }
        return null;
      }

      BuyerOrderLocation? locationFor(
        bool Function(Map<String, dynamic>) predicate,
      ) {
        final Map<String, dynamic>? marker = firstMarkerWhere(predicate);
        return marker == null ? null : markerLocation(marker);
      }

      final BuyerOrderLocation? sellerLocation = locationFor(isSeller);
      final BuyerOrderLocation? buyerLocation = locationFor(isBuyer);
      final navigation = BuyerTrackingNavigation.fromPayload(mapPayload);
      final BuyerOrderLocation? riderLocation = navigation.rider;
      final bool sellerPinUnavailable =
          sellerLocation == null && order.sellerLocation == null;
      final bool riderGpsPending = markers.any(
        (Map<String, dynamic> marker) =>
            marker['kind'] == 'rider' && marker['location_pending'] == true,
      );
      setState(() {
        _hasLoadedShipmentMap = true;
        _shipmentMapUnavailable = false;
        _navigation = navigation;
        _sellerPinUnavailable = sellerPinUnavailable;
        _riderGpsPending = riderGpsPending;
      });
      final List<Map<String, dynamic>> hubMarkers = markers
          .where(isHub)
          .toList(growable: true);
      int centerRoleOrder(Map<String, dynamic> marker) {
        final int sequence =
            int.tryParse((marker['sequence_no'] ?? '').toString()) ?? 0;
        final int roleOrder;
        switch (marker['center_role']?.toString()) {
          case 'origin':
            roleOrder = 0;
            break;
          case 'destination':
            roleOrder = 1;
            break;
          default:
            roleOrder = 2;
        }
        return sequence * 3 + roleOrder;
      }

      hubMarkers.sort(
        (Map<String, dynamic> first, Map<String, dynamic> second) =>
            centerRoleOrder(first).compareTo(centerRoleOrder(second)),
      );
      final List<BuyerOrderLocation> routeStops = <BuyerOrderLocation>[];
      for (final Map<String, dynamic> marker in hubMarkers) {
        final BuyerOrderLocation? stop = markerLocation(marker);
        if (stop == null) continue;
        final int existingIndex = routeStops.indexWhere(
          (BuyerOrderLocation existing) =>
              sameBuyerOrderLogisticsStop(existing, stop),
        );
        if (existingIndex < 0) {
          routeStops.add(stop);
        } else {
          final BuyerOrderLocation existing = routeStops[existingIndex];
          routeStops[existingIndex] = deduplicateBuyerOrderLogisticsStops(
            <BuyerOrderLocation>[existing, stop],
          ).first;
        }
      }
      // Keep route pins already supplied with the buyer's order when an older
      // map endpoint returns buyer/rider markers but omits sorting centers.
      if (routeStops.isEmpty) {
        routeStops.addAll(order.shipmentRouteStops);
      }
      routeStops.sort((BuyerOrderLocation first, BuyerOrderLocation second) {
        final int sequence = (first.sequenceNo ?? 1 << 30).compareTo(
          second.sequenceNo ?? 1 << 30,
        );
        if (sequence != 0) return sequence;
        int roleOrder(BuyerOrderLocation stop) =>
            switch (stop.centerRole?.toLowerCase()) {
              'origin' => 0,
              'destination' => 1,
              _ => 2,
            };
        return roleOrder(first).compareTo(roleOrder(second));
      });

      final BuyerOrderLocation? nextSeller =
          sellerLocation ?? order.sellerLocation;
      final BuyerOrderLocation? nextBuyer =
          buyerLocation ?? order.orderLocation;
      final BuyerOrderLocation? nextRider = riderLocation;
      bool sameLocation(BuyerOrderLocation? first, BuyerOrderLocation? second) {
        if (first == null || second == null)
          return first == null && second == null;
        return first.latitude == second.latitude &&
            first.longitude == second.longitude &&
            first.label == second.label &&
            first.id == second.id &&
            listEquals(first.transferLegIds, second.transferLegIds) &&
            first.sequenceNo == second.sequenceNo &&
            first.centerRole == second.centerRole &&
            first.progressStatus == second.progressStatus;
      }

      final bool routeChanged =
          !sameLocation(order.sellerLocation, nextSeller) ||
          !sameLocation(order.orderLocation, nextBuyer) ||
          order.shipmentRouteStops.length != routeStops.length ||
          List<bool>.generate(
            order.shipmentRouteStops.length < routeStops.length
                ? order.shipmentRouteStops.length
                : routeStops.length,
            (int index) => sameLocation(
              order.shipmentRouteStops[index],
              routeStops[index],
            ),
          ).contains(false);
      final bool riderChanged = !_sameRiderLocation(
        order.riderLocation,
        nextRider,
      );

      if (routeChanged || riderChanged) {
        setState(() {
          _trackedOrder = _trackedOrder.copyWith(
            sellerLocation: nextSeller,
            orderLocation: nextBuyer,
            riderLocation: nextRider,
            clearRiderLocation: nextRider == null,
            shipmentRouteStops: routeStops,
          );
          final BuyerOrderParcelData? selected = _selectedParcel;
          if (selected != null && riderChanged) {
            _replaceSelectedParcel(
              selected.copyWith(
                riderLocation: nextRider,
                clearRiderLocation: nextRider == null,
              ),
            );
          }
        });
      }

      final bool recenter = firstMapLoad || routeChanged;
      await _syncMapLibreMarkers(recenter: recenter);
    } catch (_) {
      // The live map keeps the last known route if tracking data is offline.
      if (mounted && !_shipmentMapUnavailable) {
        setState(() => _shipmentMapUnavailable = true);
      }
    } finally {
      _refreshingShipmentMap = false;
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

  bool _sameRiderInfo(BuyerRiderInfo? current, BuyerRiderInfo? next) {
    if (current == null || next == null) return current == null && next == null;
    return current.name == next.name &&
        current.photoUrl == next.photoUrl &&
        current.vehicleType == next.vehicleType &&
        current.plateNumber == next.plateNumber;
  }

  void _applyRiderInfo(BuyerRiderInfo? rider) {
    final BuyerOrderParcelData? selected = _selectedParcel;
    if (!mounted ||
        selected == null ||
        rider == null ||
        _sameRiderInfo(selected.rider, rider)) {
      return;
    }

    setState(() {
      _replaceSelectedParcel(selected.copyWith(rider: rider));
    });
  }

  Future<void> _applyRiderLocation(BuyerOrderLocation? riderLocation) async {
    if (!mounted ||
        _navigation != null ||
        _sameRiderLocation(order.riderLocation, riderLocation)) {
      return;
    }
    setState(() {
      final BuyerOrderParcelData? selected = _selectedParcel;
      if (selected == null) {
        _trackedOrder = _trackedOrder.copyWith(
          riderLocation: riderLocation,
          clearRiderLocation: riderLocation == null,
        );
      } else {
        _replaceSelectedParcel(
          selected.copyWith(
            riderLocation: riderLocation,
            clearRiderLocation: riderLocation == null,
          ),
        );
      }
    });
    await _syncMapLibreMarkers(recenter: false);
  }

  void _replaceSelectedParcel(BuyerOrderParcelData updated) {
    final List<BuyerOrderParcelData> parcels = _trackedOrder.parcels
        .map(
          (BuyerOrderParcelData parcel) =>
              parcel.id == updated.id ? updated : parcel,
        )
        .toList(growable: false);
    _trackedOrder = _trackedOrder.copyWith(parcels: parcels);
  }

  Future<void> _selectParcel(String? parcelId) async {
    if (parcelId == null || parcelId == _selectedParcelId) return;
    final RealtimeSubscription? previous = _shipmentRealtime;
    _shipmentRealtime = null;
    await previous?.cancel();
    if (!mounted) return;
    setState(() {
      _selectedParcelId = parcelId;
      _sellerPinUnavailable = false;
      _riderGpsPending = false;
      _shipmentMapUnavailable = false;
      _trackedOrder = _trackedOrder.copyWith(
        clearSellerLocation: true,
        shipmentRouteStops: const <BuyerOrderLocation>[],
      );
      final BuyerOrderParcelData? selected = _selectedParcel;
      if (selected != null) {
        _replaceSelectedParcel(selected.copyWith(clearRiderLocation: true));
      }
    });
    _hasLoadedShipmentMap = false;
    _mapGeneration++;
    _navigation = null;
    _guidanceKey = null;
    _lastGuidanceOrigin = null;
    _guidanceFetchedAt = null;
    _guidanceFailedAt = null;
    _guidanceRoutePositions = <maplibre.Position>[];
    _guidanceDistance = null;
    _guidanceDuration = null;
    _guidanceArrivalAt = null;
    _guidanceUnavailable = false;
    _roadRouteUnavailable = false;
    _straightRouteFallback = false;
    _roadDistanceMeters = null;
    _roadDurationSeconds = null;
    _roadRoutePositions = <maplibre.Position>[];
    _roadRouteStops = <BuyerOrderLocation>[];
    _confirmedRouteProgress = 0;
    _lastRouteOrigin = null;
    _lastRouteRequestAt = null;
    _lastRouteTopologyKey = null;
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    if (manager != null) await _clearRoadRouteSegments(manager);
    await _syncMapLibreMarkers();
    if (!AppConfig.apiEnabled || order.isPreview) return;
    unawaited(_refreshShipmentMap());
    unawaited(_refreshOrderLocation());
    unawaited(_connectShipmentRealtime());
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

  bool get _supportsMapLibre {
    return kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }

  bool get _canShowMap {
    return widget.previewMap == null && _supportsMapLibre;
  }

  LatLng get _center {
    final List<BuyerOrderLocation> locations = _locations;
    if (locations.isNotEmpty) {
      return LatLng(
        locations
                .map((BuyerOrderLocation location) => location.latitude)
                .reduce((double sum, double value) => sum + value) /
            locations.length,
        locations
                .map((BuyerOrderLocation location) => location.longitude)
                .reduce((double sum, double value) => sum + value) /
            locations.length,
      );
    }
    return _defaultCenter;
  }

  static const List<String> _monthAbbreviations = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  String _formatPhilippineArrival(DateTime utcArrival) {
    final DateTime phTime = utcArrival.toUtc().add(const Duration(hours: 8));
    final int hour = phTime.hour % 12 == 0 ? 12 : phTime.hour % 12;
    final String minute = phTime.minute.toString().padLeft(2, '0');
    final String period = phTime.hour >= 12 ? 'PM' : 'AM';
    return '${_monthAbbreviations[phTime.month - 1]} ${phTime.day}, '
        '$hour:$minute $period PHT';
  }

  String get _riderGuidanceText {
    final navigation = _navigation;
    if (navigation == null) {
      return 'Rider location is shown. Waiting for the active route details.';
    }
    final String freshness = navigation.isLive ? 'Live GPS' : 'Last known GPS';
    if (navigation.destination == null) {
      return '$freshness • Active destination coordinates unavailable.';
    }
    final distance = _guidanceDistance;
    final duration = _guidanceDuration;
    final target = navigation.destination!.label;
    if (_guidanceUnavailable) {
      return '$freshness • Road route ETA unavailable; saved map locations remain visible.';
    }
    if (distance == null || duration == null || _guidanceArrivalAt == null) {
      return '${navigation.navigationLabel} • $freshness • Calculating road route to $target.';
    }
    final distanceText = distance < 1000
        ? '${distance.round()} m'
        : '${(distance / 1000).toStringAsFixed(1)} km';
    final double remainingSeconds = math.max(
      0,
      _guidanceArrivalAt!.difference(DateTime.now()).inSeconds.toDouble(),
    );
    final int remainingMinutes = (remainingSeconds / 60).ceil();
    final String timeText = remainingMinutes < 60
        ? '$remainingMinutes min'
        : '${remainingMinutes ~/ 60}h ${remainingMinutes % 60}m';
    return '${navigation.navigationLabel} • $freshness • $distanceText to $target'
        ' • about $timeText • ETA ${_formatPhilippineArrival(_guidanceArrivalAt!)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.resolve(context, _canvas, fill: true),
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
        backgroundColor: AppTheme.resolve(context, _canvas, fill: true),
        foregroundColor: AppTheme.resolve(context, _text),
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: ListView(
            children: <Widget>[
              _buildParcelPicker(),
              if (_trackedOrder.parcels.length > 1) const SizedBox(height: 12),
              _buildMapCard(),
              if (_shouldShowRiderInfo) ...<Widget>[
                const SizedBox(height: 12),
                _buildRiderInfoCard(),
              ],
              const SizedBox(height: 16),
              _buildTimelineCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildParcelPicker() {
    final List<BuyerOrderParcelData> parcels = _trackedOrder.parcels;
    if (parcels.length <= 1) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'TRACK A PARCEL',
            style: TextStyle(
              color: AppTheme.resolve(context, _muted),
              fontSize: 10,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          DropdownButtonFormField<String>(
            initialValue:
                parcels.any(
                  (BuyerOrderParcelData parcel) =>
                      parcel.id == _selectedParcelId,
                )
                ? _selectedParcelId
                : parcels.first.id,
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
            isExpanded: true,
            items: parcels
                .map((BuyerOrderParcelData parcel) {
                  final String seller =
                      parcel.sellerName?.trim().isNotEmpty == true
                      ? parcel.sellerName!.trim()
                      : parcel.sellerOrderNumber?.trim().isNotEmpty == true
                      ? 'Order ${parcel.sellerOrderNumber}'
                      : 'Parcel ${parcel.id}';
                  final String tracking =
                      parcel.trackingNumber?.trim().isNotEmpty == true
                      ? ' • ${parcel.trackingNumber}'
                      : '';
                  return DropdownMenuItem<String>(
                    value: parcel.id,
                    child: Text(
                      '$seller • ${parcel.statusLabel}$tracking',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.resolve(context, _text),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                })
                .toList(growable: false),
            onChanged: _selectParcel,
          ),
          if (_selectedParcel?.destination?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Text(
                'Destination: ${_selectedParcel!.destination}',
                style: TextStyle(
                  color: AppTheme.resolve(context, _muted),
                  fontSize: 11.5,
                ),
              ),
            ),
        ],
      ),
    );
  }

  bool get _shouldShowRiderInfo {
    final BuyerOrderParcelData? parcel = _selectedParcel;
    if (parcel == null) return false;
    if (parcel.rider != null) return true;

    return const <String>{
      'ASSIGNED_TO_RIDER',
      'OUT_FOR_DELIVERY',
    }.contains(parcel.status.trim().toUpperCase());
  }

  Widget _buildRiderInfoCard() {
    final BuyerRiderInfo? rider = _selectedParcel?.rider;
    final String name = rider?.name?.trim().isNotEmpty == true
        ? rider!.name!.trim()
        : 'Delivery rider';
    final List<String> riderDetails = <String>[
      if (rider?.vehicleType?.trim().isNotEmpty == true)
        _humanizeStatus(rider!.vehicleType!),
      if (rider?.plateNumber?.trim().isNotEmpty == true)
        'Plate ${rider!.plateNumber!.trim()}',
    ];
    final List<String> nameParts = name.split(RegExp(r'\s+'));
    final String initials = nameParts
        .take(2)
        .map((String part) => part.isEmpty ? '' : part[0].toUpperCase())
        .join();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
      ),
      child: Row(
        children: <Widget>[
          ClipOval(
            child: SizedBox(
              width: 54,
              height: 54,
              child: rider?.photoUrl?.isNotEmpty == true
                  ? Image.network(
                      rider!.photoUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          _riderAvatarFallback(initials),
                    )
                  : _riderAvatarFallback(initials),
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'DELIVERY RIDER',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 10,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  riderDetails.isEmpty
                      ? 'Rider details will appear here when available.'
                      : riderDetails.join('  •  '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.delivery_dining_rounded,
            color: AppTheme.resolve(context, _maroon),
          ),
        ],
      ),
    );
  }

  Widget _riderAvatarFallback(String initials) {
    return Container(
      alignment: Alignment.center,
      color: AppTheme.resolve(context, ShopColors.accentSoft, fill: true),
      child: initials.trim().isEmpty
          ? Icon(
              Icons.person_rounded,
              color: AppTheme.resolve(context, _maroon),
              size: 28,
            )
          : Text(
              initials,
              style: TextStyle(
                color: AppTheme.resolve(context, _maroon),
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
    );
  }

  Widget _buildMapCard() {
    final bool hasRider = order.riderLocation != null;
    final double mapHeight = _mapExpanded
        ? MediaQuery.sizeOf(context).height * 0.66
        : order.isPreview
        ? 220
        : 300;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
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
                    color: AppTheme.resolve(
                      context,
                      ShopColors.accentSoft,
                      fill: true,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.map_outlined,
                    color: AppTheme.resolve(context, _maroon),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'LOCATION MAP',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
                          fontSize: 9,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Order route',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _text),
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        order.shipmentRouteStops.isNotEmpty
                            ? 'Follow the parcel from the seller through its logistics hubs.'
                            : hasRider
                            ? 'See the rider’s live position and route to your address.'
                            : order.tracking?.trim().isNotEmpty == true
                            ? 'Route updates appear as the parcel moves through delivery.'
                            : 'The route will appear after the parcel is dispatched.',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    setState(() => _mapExpanded = !_mapExpanded);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) unawaited(_syncMapLibreMarkers());
                    });
                  },
                  icon: Icon(
                    _mapExpanded ? Icons.close_fullscreen : Icons.open_in_full,
                    size: 15,
                  ),
                  label: Text(_mapExpanded ? 'Close map' : 'Full map'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.resolve(context, _maroon),
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    textStyle: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            height: mapHeight,
            child: Stack(
              children: <Widget>[
                if (widget.previewMap != null)
                  Positioned.fill(child: widget.previewMap!)
                else if (_canShowMap)
                  Positioned.fill(
                    child: maplibre.MapLibreMapWidget(
                      viewport: maplibre.MapLibreViewport(
                        center: _toMapLibrePoint(_center),
                        zoom: _zoomLevel,
                      ),
                      onMapCreated: _onMapLibreSessionCreated,
                    ),
                  )
                else
                  Positioned.fill(
                    child: Container(
                      color: AppTheme.resolve(context, _canvas, fill: true),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'The interactive map is available on Android and iOS.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppTheme.resolve(context, _muted),
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                if (_canShowMap)
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
                        const SizedBox(height: 8),
                        _buildZoomButton(
                          icon: Icons.fit_screen,
                          onPressed: () => _syncMapLibreMarkers(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: const <Widget>[
                    _RouteLineLegend(
                      color: Color(0xFF800000),
                      label: 'Confirmed / traveled',
                    ),
                    _RouteLineLegend(
                      color: Color(0xFFC2410C),
                      label: 'Hub transfer active',
                    ),
                    _RouteLineLegend(
                      color: Color(0xFF9CA3AF),
                      label: 'Remaining road',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Route updates refresh every 10 seconds while this screen is open.',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 10.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Locations',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (order.sellerLocation != null)
                  _buildRouteLocation(
                    'Pickup address',
                    order.sellerLocation!,
                    const Color(0xFFB56B32),
                  ),
                for (final stop in order.shipmentRouteStops)
                  _buildRouteLocation(
                    'Sorting center',
                    stop,
                    const Color(0xFF15803D),
                  ),
                if (order.orderLocation != null)
                  _buildRouteLocation(
                    'Delivery address',
                    order.orderLocation!,
                    const Color(0xFF2563EB),
                  ),
                if (!AppConfig.apiEnabled) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Live parcel, sorting-center, and rider locations are disabled in this build. Run or build with --dart-define=API_ENABLED=true.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.resolve(context, _muted),
                    ),
                  ),
                ],
                if (_shipmentMapUnavailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Live seller and rider locations could not be loaded. Showing saved order locations only.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.resolve(context, _muted),
                    ),
                  ),
                ],
                if (_hasLoadedShipmentMap && _sellerPinUnavailable) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Seller pickup pin is missing from tracking data. Check that the business address has saved map coordinates and that Laravel returns seller markers.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.resolve(context, _muted),
                    ),
                  ),
                ],
                if (_hasLoadedShipmentMap &&
                    order.shipmentRouteStops.isEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'No sorting-center coordinates were returned for this parcel yet.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.resolve(context, _muted),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                Text(
                  _locations.length >= 2
                      ? _roadRouteSummary
                      : 'Waiting for saved route locations.',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.resolve(context, _muted),
                  ),
                ),
                if (!hasRider) ...[
                  const SizedBox(height: 6),
                  Text(
                    _riderGpsPending
                        ? 'Rider assigned. Waiting for the rider to share GPS.'
                        : 'Rider GPS appears during active delivery when the rider is sharing a location.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppTheme.resolve(context, _muted),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Wrap(
                  spacing: 14,
                  runSpacing: 8,
                  children: <Widget>[
                    const _RouteLegend(
                      color: Color(0xFF800000),
                      label: 'Traveled',
                    ),
                    const _RouteLegend(
                      color: Color(0xFFC2410C),
                      label: 'Active hub transfer',
                    ),
                    const _RouteLegend(
                      color: Color(0xFF9CA3AF),
                      label: 'Remaining',
                    ),
                    if (order.sellerLocation != null)
                      _LegendDot(
                        color: AppTheme.resolve(context, Color(0xFFB56B32)),
                        label: 'Seller',
                      ),
                    ...List<Widget>.generate(
                      order.shipmentRouteStops.length,
                      (int index) => _LegendDot(
                        color: const Color(0xFF15803D),
                        label: order.shipmentRouteStops[index].label,
                      ),
                    ),
                    _LegendDot(
                      color: AppTheme.resolve(context, _maroon),
                      label: 'Buyer',
                    ),
                    if (hasRider)
                      _LegendDot(
                        color: AppTheme.resolve(context, _maroon),
                        label:
                            _navigation?.riderLabel ??
                            'Last known rider location',
                      ),
                  ],
                ),
                if (order.shipmentRouteStops.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Route: ${<String>[if (order.sellerLocation != null) order.sellerLocation!.label, ...order.shipmentRouteStops.map((BuyerOrderLocation stop) => stop.label), order.orderLocation?.label ?? 'Delivery destination'].join(' -> ')}',
                    style: TextStyle(
                      color: AppTheme.resolve(context, _text),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (order.riderLocation != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Text(
                _riderGuidanceText,
                style: TextStyle(
                  color: AppTheme.resolve(context, _text),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRouteLocation(
    String title,
    BuyerOrderLocation location,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.location_on_outlined, color: color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.resolve(context, _text),
                  ),
                ),
                Text(
                  location.label,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppTheme.resolve(context, _muted),
                  ),
                ),
              ],
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
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
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
        icon: Icon(icon, color: AppTheme.resolve(context, _text)),
        splashRadius: 20,
        padding: EdgeInsets.zero,
      ),
    );
  }

  static const Map<String, String> _timelineStatusLabels = <String, String>{
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

  static const Map<String, String> _timelineStatusAliases = <String, String>{
    'placed': 'PLACED',
    'orderplaced': 'PLACED',
    'confirmed': 'CONFIRMED',
    'sellerconfirmedorder': 'CONFIRMED',
    'preparing': 'PREPARING',
    'preparingparcel': 'PREPARING',
    'readyforpickup': 'READY_FOR_PICKUP',
    'pickupassigned': 'PICKUP_ASSIGNED',
    'pickupriderassigned': 'PICKUP_ASSIGNED',
    'pickedup': 'PICKED_UP',
    'pickedupfromseller': 'PICKED_UP',
    'atsortingcenter': 'AT_SORTING_CENTER',
    'arrivedatsortingcenter': 'AT_SORTING_CENTER',
    'sorted': 'SORTED',
    'sortedbydestination': 'SORTED',
    'assignedtorider': 'ASSIGNED_TO_RIDER',
    'deliveryriderassigned': 'ASSIGNED_TO_RIDER',
    'assignedtodeliveryrider': 'ASSIGNED_TO_RIDER',
    'outfordelivery': 'OUT_FOR_DELIVERY',
    'deliveryfailed': 'DELIVERY_FAILED',
    'deliveryattemptunsuccessful': 'DELIVERY_FAILED',
    'delivered': 'DELIVERED',
    'completed': 'COMPLETED',
    'buyerconfirmedreceipt': 'COMPLETED',
    'automaticallyconfirmedreceipt': 'COMPLETED',
    'returned': 'RETURNED',
    'parcelreturned': 'RETURNED',
    'cancelled': 'CANCELLED',
    'canceled': 'CANCELLED',
    'ordercancelled': 'CANCELLED',
    'ordercanceled': 'CANCELLED',
  };

  static String _timelineKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  List<BuyerOrderTimelineEvent> _trackingTimelineEvents() {
    if (order.isPreview) return order.timeline;

    final List<BuyerOrderTimelineEvent> rows = <BuyerOrderTimelineEvent>[];
    String? previousStatus;
    String? previousLabel;
    final Set<String> representedStatuses = <String>{};

    for (final BuyerOrderTimelineEvent event in order.timeline) {
      final String details = event.details.trim();
      final bool isCancellation =
          details.startsWith('BUYER_ORDER_CANCELLED:') ||
          details.startsWith('SELLER_ORDER_CANCELLED:');
      final String? status = isCancellation
          ? 'CANCELLED'
          : _timelineStatusAliases[_timelineKey(event.label)];
      if (status == null) continue;

      final bool isAutomaticReceipt =
          status == 'COMPLETED' &&
          (_timelineKey(event.label) == 'automaticallyconfirmedreceipt' ||
              details.startsWith(
                'Order automatically confirmed received after 3 days',
              ));
      final String label = isAutomaticReceipt
          ? 'Automatically confirmed receipt'
          : _timelineStatusLabels[status]!;

      // Match Laravel's timeline behavior: ignore unrecognized events and
      // collapse adjacent repeats of the same step.
      if (previousStatus == status && previousLabel == label) continue;

      rows.add(
        BuyerOrderTimelineEvent(
          label: label,
          time: event.time,
          done: event.done,
          details: isCancellation ? '' : event.details,
        ),
      );
      previousStatus = status;
      previousLabel = label;
      representedStatuses.add(status);
    }

    final String? currentStatus =
        _timelineStatusAliases[_timelineKey(order.normalizedStatus)];
    if (currentStatus != null &&
        currentStatus != 'CANCELLED' &&
        !representedStatuses.contains(currentStatus) &&
        !representedStatuses.contains('CANCELLED')) {
      rows.add(
        BuyerOrderTimelineEvent(
          label: _timelineStatusLabels[currentStatus]!,
          time: '',
          done: false,
        ),
      );
    }

    return rows;
  }

  Widget _buildTimelineCard() {
    final bool isCompleted =
        order.status == 'completed' || order.backendStatus == 'completed';

    final List<BuyerOrderTimelineEvent> events = order.isPreview
        ? order.timeline.isNotEmpty
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
                ]
        : _trackingTimelineEvents();
    final List<BuyerOrderTimelineEvent> newestFirstEvents = events.reversed
        .toList(growable: false);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.resolve(context, ShopColors.border)),
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
          Text(
            'Tracking Timeline',
            style: TextStyle(
              color: AppTheme.resolve(context, _text),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          if (newestFirstEvents.isEmpty)
            Text(
              'No tracking updates yet.',
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                fontSize: 13,
              ),
            )
          else
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
              final bool deliveryComplete = const <String>{
                'delivered',
                'completed',
                'complete',
                'delivery_success',
                'delivery_successful',
                'delivery_completed',
              }.contains(order.normalizedStatus);
              final bool showProofButton =
                  index == 0 && (isDeliveredEvent || deliveryComplete);

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  SizedBox(
                    width: 84,
                    child: Text(
                      event.time,
                      style: TextStyle(
                        color: AppTheme.resolve(context, Color(0xFF999999)),
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
                                ? AppTheme.resolve(
                                    context,
                                    _timelineActive,
                                    fill: true,
                                  )
                                : AppTheme.resolve(
                                    context,
                                    _timelineInactive,
                                    fill: true,
                                  ),
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
                            color: AppTheme.resolve(
                              context,
                              const Color(0xFFE1E1E1),
                              fill: true,
                            ),
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
                                  ? AppTheme.resolve(context, _timelineActive)
                                  : AppTheme.resolve(
                                      context,
                                      const Color(0xFF858585),
                                    ),
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
                              style: TextButton.styleFrom(
                                foregroundColor: AppTheme.resolve(
                                  context,
                                  _proofLink,
                                ),
                                alignment: Alignment.centerLeft,
                                padding: EdgeInsets.zero,
                              ),
                              child: const Text('View Proof of Delivery'),
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

  Future<bool> _showSelectedParcelProofAttempts() async {
    final List<String> attemptIds =
        _selectedParcel?.deliveryProofAttemptIds ?? const <String>[];
    if (attemptIds.isEmpty) return false;

    try {
      final List<Uint8List> files = await Future.wait<Uint8List>(
        attemptIds.map(BuyerMobileService.fetchDeliveryAttemptProof),
      );
      if (mounted && files.isNotEmpty) {
        await _showDeliveryProofFiles(files);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to open delivery proof: $error')),
        );
      }
    }
    return true;
  }

  Future<void> _openDeliveryProof() async {
    if (await _showSelectedParcelProofAttempts()) return;
    if (order.deliveryProofImageUrls.isEmpty) {
      final bool loaded = await _loadDeliveryProof(force: true);
      if (!loaded && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not check delivery proof. Check your connection and try again.',
            ),
          ),
        );
        return;
      }
    }
    if (!mounted) return;
    if (await _showSelectedParcelProofAttempts()) return;

    final List<String> imageUrls = order.deliveryProofImageUrls;
    if (imageUrls.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No proof photo is saved for this delivery on the server.',
          ),
        ),
      );
      return;
    }

    await _showDeliveryProof(imageUrls);
  }

  Future<void> _showDeliveryProofFiles(List<Uint8List> files) async {
    if (files.isEmpty || !mounted) return;
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
                      Expanded(
                        child: Text(
                          'Proof of delivery',
                          style: TextStyle(
                            color: AppTheme.resolve(context, _text),
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
                    itemCount: files.length,
                    itemBuilder: (BuildContext context, int index) =>
                        InteractiveViewer(
                          minScale: 0.8,
                          maxScale: 4,
                          child: Center(
                            child: Image.memory(
                              files[index],
                              fit: BoxFit.contain,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) => const Center(
                                    child: Text(
                                      'Unable to display the proof image.',
                                    ),
                                  ),
                            ),
                          ),
                        ),
                  ),
                ),
                if (files.length > 1)
                  Padding(
                    padding: const EdgeInsets.all(10),
                    child: Text(
                      'Swipe to view ${files.length} proof photos',
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
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
                      Expanded(
                        child: Text(
                          'Proof of delivery',
                          style: TextStyle(
                            color: AppTheme.resolve(context, _text),
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
                      style: TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMapLibreSessionCreated(maplibre.MapLibreSession map) async {
    _mapLibreMap = map;
    _mapMarkers = await map.annotations.createCircleAnnotationManager();
    _routeLabels = await map.annotations.createPointAnnotationManager();
    _routeLines = await map.annotations.createPolylineAnnotationManager();
    _circleAnnotations = <maplibre.CircleAnnotation>[];
    _pointAnnotations = <maplibre.PointAnnotation>[];
    _renderedMapMarkers = <_TrackingMapMarkerSpec>[];
    _roadRouteSegments.clear();
    await _syncMapLibreMarkers();
  }

  Future<void> _syncMapLibreMarkers({bool recenter = true}) async {
    if (_mapLibreMap == null || _mapMarkers == null || _routeLabels == null) {
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
        await _syncMapLibreMarkersOnce(recenter: shouldRecenter);
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
    _TrackingMapMarkerSpec marker(
      BuyerOrderLocation location,
      String label,
      Color color, {
      required BuyerMapMarkerKind kind,
    }) => _TrackingMapMarkerSpec(
      latitude: location.latitude,
      longitude: location.longitude,
      color: AppTheme.resolve(context, color).toARGB32(),
      radius: kind == BuyerMapMarkerKind.rider ? 10 : 11,
      kind: kind,
      label: label,
    );
    return [
      if (order.sellerLocation != null)
        marker(
          order.sellerLocation!,
          'Seller: ${order.sellerLocation!.label}',
          const Color(0xFFB56B32),
          kind: BuyerMapMarkerKind.seller,
        ),
      for (final BuyerOrderLocation stop in deduplicateBuyerOrderLogisticsStops(
        order.shipmentRouteStops,
      ))
        marker(
          stop,
          stop.label,
          const Color(0xFF15803D),
          kind: BuyerMapMarkerKind.hub,
        ),
      if (order.orderLocation != null)
        marker(
          order.orderLocation!,
          'Buyer: ${order.orderLocation!.label}',
          const Color(0xFF2563EB),
          kind: BuyerMapMarkerKind.buyer,
        ),
      if (order.riderLocation != null)
        marker(
          order.riderLocation!,
          _navigation?.riderLabel ?? 'Last known rider location',
          _maroon,
          kind: _navigation?.assignmentType == 'INTER_LOGISTICS'
              ? BuyerMapMarkerKind.interHubRider
              : BuyerMapMarkerKind.rider,
        ),
    ];
  }

  Future<void> _syncMapLibreMarkersOnce({required bool recenter}) async {
    final maplibre.MapLibreSession? map = _mapLibreMap;
    final maplibre.CircleAnnotationManager? manager = _mapMarkers;
    final maplibre.PointAnnotationManager? labels = _routeLabels;

    if (map == null || manager == null || labels == null) {
      return;
    }

    final List<_TrackingMapMarkerSpec> specs = _buildMapMarkerSpecs();
    final bool sameMarkerKinds =
        _renderedMapMarkers.length == specs.length &&
        List<bool>.generate(
          specs.length,
          (int index) => _renderedMapMarkers[index].kind == specs[index].kind,
        ).every((bool matches) => matches);
    final bool canUpdateExisting =
        sameMarkerKinds &&
        _circleAnnotations.length == specs.length &&
        _pointAnnotations.length == specs.length &&
        _renderedMapMarkers.length == specs.length;

    if (!canUpdateExisting) {
      await manager.deleteAll();
      if (!mounted || !identical(_mapLibreMap, map)) return;
      await labels.deleteAll();
      if (!mounted || !identical(_mapLibreMap, map)) return;

      // Clear cached IDs before creating replacements so a failed platform
      // call can safely retry on the next location update.
      _circleAnnotations = <maplibre.CircleAnnotation>[];
      _pointAnnotations = <maplibre.PointAnnotation>[];
      _renderedMapMarkers = <_TrackingMapMarkerSpec>[];

      final List<maplibre.CircleAnnotationOptions> circleOptions = specs
          .map(
            (_TrackingMapMarkerSpec spec) => maplibre.CircleAnnotationOptions(
              geometry: _toMapLibrePoint(LatLng(spec.latitude, spec.longitude)),
              circleColor: spec.color,
              circleRadius: spec.radius,
              circleOpacity: 0.9,
              circleStrokeColor: Colors.white.toARGB32(),
              circleStrokeWidth: 2,
              circleSortKey: spec.isRider ? 3 : 2,
            ),
          )
          .toList(growable: false);
      final List<maplibre.PointAnnotationOptions> pointOptions =
          <maplibre.PointAnnotationOptions>[];
      final int markerTextColor = AppTheme.resolve(
        context,
        const Color(0xFF342E2E),
      ).toARGB32();
      for (final _TrackingMapMarkerSpec spec in specs) {
        pointOptions.add(
          maplibre.PointAnnotationOptions(
            geometry: _toMapLibrePoint(LatLng(spec.latitude, spec.longitude)),
            textField: spec.label,
            textAnchor: maplibre.TextAnchor.bottom,
            textOffset: <double?>[0, -0.7],
            textSize: 11,
            textColor: markerTextColor,
            textHaloColor: Colors.white.toARGB32(),
            textHaloWidth: 2,
            image: await _markerIcons.image(spec.kind),
            iconSize: 0.48,
            iconAnchor: maplibre.IconAnchor.center,
            symbolSortKey: 10,
          ),
        );
      }
      final List<maplibre.CircleAnnotation?> createdCircles = await manager
          .createMulti(circleOptions);
      if (!mounted || !identical(_mapLibreMap, map)) return;
      final List<maplibre.PointAnnotation?> createdLabels =
          <maplibre.PointAnnotation?>[];
      for (final maplibre.PointAnnotationOptions options in pointOptions) {
        createdLabels.add(await labels.create(options));
        if (!mounted || !identical(_mapLibreMap, map)) return;
      }
      if (!mounted || !identical(_mapLibreMap, map)) return;
      _circleAnnotations = createdCircles
          .whereType<maplibre.CircleAnnotation>()
          .toList(growable: false);
      _pointAnnotations = createdLabels
          .whereType<maplibre.PointAnnotation>()
          .toList(growable: false);
      _renderedMapMarkers = specs;
    } else {
      for (int index = 0; index < specs.length; index++) {
        final _TrackingMapMarkerSpec previous = _renderedMapMarkers[index];
        final _TrackingMapMarkerSpec next = specs[index];
        final bool geometryChanged =
            previous.latitude != next.latitude ||
            previous.longitude != next.longitude;
        final maplibre.Point geometry = _toMapLibrePoint(
          LatLng(next.latitude, next.longitude),
        );

        if (geometryChanged ||
            previous.color != next.color ||
            previous.radius != next.radius) {
          final maplibre.CircleAnnotation annotation =
              _circleAnnotations[index];
          annotation.geometry = geometry;
          annotation.circleColor = next.color;
          annotation.circleRadius = next.radius;
          annotation.circleOpacity = 0.9;
          annotation.circleStrokeColor = Colors.white.toARGB32();
          annotation.circleStrokeWidth = 2;
          annotation.circleSortKey = next.isRider ? 3 : 2;
          await manager.update(annotation);
          if (!mounted || !identical(_mapLibreMap, map)) return;
        }

        if (geometryChanged || previous.label != next.label) {
          final maplibre.PointAnnotation annotation = _pointAnnotations[index];
          annotation.geometry = geometry;
          annotation.textField = next.label;
          await labels.update(annotation);
          if (!mounted || !identical(_mapLibreMap, map)) return;
        }
      }
      _renderedMapMarkers = specs;
    }

    if (recenter) {
      _lastMapCenter = _center;
      _zoomLevel = _locations.isEmpty ? 11 : 14;
      if (_locations.length > 1) {
        final maplibre.CameraOptions camera = await map
            .cameraForCoordinatesPadding(
              _locations
                  .map(
                    (BuyerOrderLocation location) => _toMapLibrePoint(
                      LatLng(location.latitude, location.longitude),
                    ),
                  )
                  .toList(growable: false),
              maplibre.CameraOptions(
                padding: maplibre.MbxEdgeInsets(
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
          maplibre.CameraOptions(
            center: _toMapLibrePoint(_lastMapCenter),
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
      await _syncRiderGuidance();
    } catch (error) {
      if (kDebugMode) debugPrint('Order tracking route update failed: $error');
    }
  }

  Future<void> _syncRoadRoute() async {
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    final BuyerOrderLocation? destination = order.orderLocation;
    if (manager == null) return;
    String coordinateKey(BuyerOrderLocation location) =>
        '${location.latitude},${location.longitude}';
    final String topologyKey = <String>[
      if (order.sellerLocation != null)
        'seller:${coordinateKey(order.sellerLocation!)}',
      ...order.shipmentRouteStops.map(
        (BuyerOrderLocation stop) =>
            'hub:${stop.transferLegIds.join(',')}:${coordinateKey(stop)}',
      ),
      if (destination != null) 'buyer:${coordinateKey(destination)}',
    ].join('|');
    final routePoints = buyerShipmentRouteStops(order);
    if (routePoints.length < 2) {
      _roadRoutePositions = <maplibre.Position>[];
      _roadRouteStops = <BuyerOrderLocation>[];
      _straightRouteFallback = false;
      await _clearRoadRouteSegments(manager);
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

    final BuyerOrderLocation routeStart = routePoints.first;
    final LatLng requestOrigin = LatLng(
      routeStart.latitude,
      routeStart.longitude,
    );
    final LatLng? previousOrigin = _lastRouteOrigin;
    final DateTime? previousRequestAt = _lastRouteRequestAt;
    final bool topologyChanged = _lastRouteTopologyKey != topologyKey;
    if (topologyChanged) {
      _roadRoutePositions = [];
      _roadRouteStops = [];
      _straightRouteFallback = false;
      _confirmedRouteProgress = 0;
      await _clearRoadRouteSegments(manager);
      _guidanceKey = null;
    }
    final bool fallbackRetryDue =
        _straightRouteFallback &&
        (previousRequestAt == null ||
            DateTime.now().difference(previousRequestAt) >=
                _minimumRouteRefreshInterval);
    if (!topologyChanged &&
        _roadRoutePositions.isNotEmpty &&
        !fallbackRetryDue) {
      await _renderRoadRouteSegments();
      return;
    }
    final bool routeIntervalElapsed =
        previousRequestAt == null ||
        DateTime.now().difference(previousRequestAt) >=
            _minimumRouteRefreshInterval;
    final bool riderMovedEnough =
        previousOrigin == null ||
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

    final generation = _mapGeneration;
    _routeRequestInProgress = true;
    _lastRouteOrigin = requestOrigin;
    _lastRouteRequestAt = DateTime.now();
    _lastRouteTopologyKey = topologyKey;
    final String coordinates = routePoints
        .map((BuyerOrderLocation stop) => '${stop.longitude},${stop.latitude}')
        .join(';');
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
      final Map<String, dynamic> routeGeometryData = Map<String, dynamic>.from(
        route['geometry'] as Map,
      );
      final List<dynamic> rawCoordinates =
          routeGeometryData['coordinates'] as List<dynamic>? ??
          const <dynamic>[];
      final List<maplibre.Position> positions = rawCoordinates
          .whereType<List<dynamic>>()
          .where((List<dynamic> pair) => pair.length >= 2)
          .map(
            (List<dynamic> pair) => maplibre.Position(
              (pair[0] as num).toDouble(),
              (pair[1] as num).toDouble(),
            ),
          )
          .toList(growable: false);
      if (positions.length < 2) {
        throw StateError('The driving route was incomplete.');
      }

      if (!mounted ||
          generation != _mapGeneration ||
          !identical(manager, _routeLines)) {
        return;
      }
      _roadRoutePositions = positions;
      _roadRouteStops = List<BuyerOrderLocation>.from(routePoints);
      _straightRouteFallback = false;
      await _renderRoadRouteSegments();
      if (!mounted || generation != _mapGeneration) return;

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
      if (mounted && generation == _mapGeneration) {
        // Keep a visible waypoint-to-waypoint guide when the road-routing
        // provider is offline. This is deliberately labeled approximate.
        _roadRoutePositions = routePoints
            .map(
              (BuyerOrderLocation stop) =>
                  maplibre.Position(stop.longitude, stop.latitude),
            )
            .toList(growable: false);
        _roadRouteStops = List<BuyerOrderLocation>.from(routePoints);
        _straightRouteFallback = _roadRoutePositions.length >= 2;
        await _renderRoadRouteSegments();
        if (mounted && generation == _mapGeneration) {
          setState(() => _roadRouteUnavailable = true);
        }
      }
    } finally {
      _routeRequestInProgress = false;
    }
  }

  double _distanceToGuidanceRouteMeters(
    BuyerOrderLocation location,
    List<maplibre.Position> positions,
  ) {
    if (positions.length < 2) return double.infinity;
    final double latitudeScale = 110540;
    final double longitudeScale =
        111320 * math.cos(location.latitude * math.pi / 180);
    double nearest = double.infinity;
    for (int index = 1; index < positions.length; index++) {
      final maplibre.Position start = positions[index - 1];
      final maplibre.Position end = positions[index];
      final double ax = (start.lng - location.longitude) * longitudeScale;
      final double ay = (start.lat - location.latitude) * latitudeScale;
      final double bx = (end.lng - location.longitude) * longitudeScale;
      final double by = (end.lat - location.latitude) * latitudeScale;
      final double vx = bx - ax;
      final double vy = by - ay;
      final double lengthSquared = vx * vx + vy * vy;
      final double ratio = lengthSquared == 0
          ? 0
          : ((-(ax * vx + ay * vy)) / lengthSquared).clamp(0, 1);
      nearest = math.min(
        nearest,
        math.sqrt(math.pow(ax + vx * ratio, 2) + math.pow(ay + vy * ratio, 2)),
      );
    }
    return nearest;
  }

  Future<void> _syncRiderGuidance() async {
    final manager = _routeLines;
    if (manager == null) return;
    final navigation = _navigation;
    final rider = navigation?.rider;
    final destination = navigation?.destination;
    if (navigation == null || rider == null || destination == null) {
      if (_guidanceRoutePositions.isNotEmpty) {
        await _setRoadRouteSegment(
          manager,
          'rider-guidance',
          const <maplibre.Position>[],
          _maroon,
        );
      }
      _guidanceKey = null;
      _lastGuidanceOrigin = null;
      _guidanceFetchedAt = null;
      _guidanceFailedAt = null;
      _guidanceRoutePositions = <maplibre.Position>[];
      if (mounted &&
          (_guidanceDistance != null ||
              _guidanceDuration != null ||
              _guidanceArrivalAt != null ||
              !_guidanceUnavailable)) {
        setState(() {
          _guidanceDistance = null;
          _guidanceDuration = null;
          _guidanceArrivalAt = null;
          _guidanceUnavailable = rider != null && destination == null;
        });
      }
      return;
    }
    final key =
        '${order.tracking}:${navigation.assignmentId}:${navigation.destinationKind}:${destination.latitude},${destination.longitude}';
    if (_guidanceInProgress) return;
    final DateTime now = DateTime.now();
    final bool sameRoute = _guidanceKey == key;
    if (sameRoute &&
        _guidanceFailedAt != null &&
        now.difference(_guidanceFailedAt!) < _riderRouteRetryDelay) {
      return;
    }
    final LatLng origin = LatLng(rider.latitude, rider.longitude);
    final LatLng? previousOrigin = sameRoute ? _lastGuidanceOrigin : null;
    final bool movedEnough =
        previousOrigin == null ||
        Geolocator.distanceBetween(
              previousOrigin.latitude,
              previousOrigin.longitude,
              origin.latitude,
              origin.longitude,
            ) >=
            _minimumRerouteDistanceMeters;
    final bool routeIsOld =
        !sameRoute ||
        _guidanceFetchedAt == null ||
        now.difference(_guidanceFetchedAt!) >= _maximumRiderRouteAge;
    final bool riderIsOffRoute =
        !sameRoute ||
        _distanceToGuidanceRouteMeters(rider, _guidanceRoutePositions) >
            _riderRouteOffPathMeters;
    if (sameRoute && !movedEnough && !routeIsOld && !riderIsOffRoute) {
      return;
    }

    final generation = _mapGeneration;
    _guidanceInProgress = true;
    try {
      if (!sameRoute) {
        await _setRoadRouteSegment(
          manager,
          'rider-guidance',
          const <maplibre.Position>[],
          _maroon,
        );
        _guidanceRoutePositions = <maplibre.Position>[];
        _guidanceFetchedAt = null;
        _guidanceFailedAt = null;
        if (mounted) {
          setState(() {
            _guidanceDistance = null;
            _guidanceDuration = null;
            _guidanceArrivalAt = null;
            _guidanceUnavailable = false;
          });
        }
      }
      final response = await ApiClient.get(
        'maps/route',
        queryParameters: {
          'waypoints':
              '${origin.longitude},${origin.latitude};${destination.longitude},${destination.latitude}',
        },
      );
      if (!mounted ||
          generation != _mapGeneration ||
          !identical(manager, _routeLines) ||
          navigation.assignmentId != _navigation?.assignmentId ||
          navigation.assignmentType != _navigation?.assignmentType ||
          destination.latitude != _navigation?.destination?.latitude ||
          destination.longitude != _navigation?.destination?.longitude) {
        return;
      }
      final route = (response.data['routes'] as List).first as Map;
      final positions = ((route['geometry'] as Map)['coordinates'] as List)
          .whereType<List>()
          .where((p) => p.length >= 2)
          .map(
            (p) => maplibre.Position(
              (p[0] as num).toDouble(),
              (p[1] as num).toDouble(),
            ),
          )
          .toList();
      if (positions.length < 2) throw StateError('Incomplete rider route');
      final double? distance = (route['distance'] as num?)?.toDouble();
      final double? duration = (route['duration'] as num?)?.toDouble();
      if (distance == null ||
          duration == null ||
          !distance.isFinite ||
          !duration.isFinite) {
        throw StateError('Rider route distance and duration are unavailable.');
      }
      await _setRoadRouteSegment(manager, 'rider-guidance', positions, _maroon);
      if (!mounted ||
          generation != _mapGeneration ||
          !identical(manager, _routeLines) ||
          navigation.assignmentId != _navigation?.assignmentId ||
          destination.latitude != _navigation?.destination?.latitude ||
          destination.longitude != _navigation?.destination?.longitude) {
        await _setRoadRouteSegment(
          manager,
          'rider-guidance',
          const <maplibre.Position>[],
          _maroon,
        );
        return;
      }
      _guidanceKey = key;
      _lastGuidanceOrigin = origin;
      _guidanceFetchedAt = DateTime.now();
      _guidanceFailedAt = null;
      _guidanceRoutePositions = positions;
      if (mounted) {
        setState(() {
          _guidanceDistance = distance;
          _guidanceDuration = duration;
          _guidanceArrivalAt = DateTime.now().add(
            Duration(seconds: duration.ceil()),
          );
          _guidanceUnavailable = false;
        });
      }
    } catch (_) {
      if (mounted &&
          generation == _mapGeneration &&
          identical(manager, _routeLines)) {
        await _setRoadRouteSegment(
          manager,
          'rider-guidance',
          const <maplibre.Position>[],
          _maroon,
        );
        _guidanceKey = key;
        _guidanceRoutePositions = <maplibre.Position>[];
        _guidanceFailedAt = DateTime.now();
        setState(() {
          _guidanceDistance = null;
          _guidanceDuration = null;
          _guidanceArrivalAt = null;
          _guidanceUnavailable = true;
        });
      }
    } finally {
      _guidanceInProgress = false;
    }
  }

  List<double> _roadRouteCumulativeDistances(
    List<maplibre.Position> positions,
  ) {
    final List<double> distances = <double>[0];
    for (int index = 1; index < positions.length; index++) {
      final maplibre.Position previous = positions[index - 1];
      final maplibre.Position current = positions[index];
      distances.add(
        distances.last +
            Geolocator.distanceBetween(
              previous.lat,
              previous.lng,
              current.lat,
              current.lng,
            ),
      );
    }
    return distances;
  }

  ({double distanceMeters, double progress})? _nearestRoadProgress(
    List<maplibre.Position> positions,
    List<double> cumulativeDistances,
    double totalDistance,
    BuyerOrderLocation location, {
    double minimumProgress = 0,
  }) {
    if (positions.isEmpty || totalDistance <= 0) return null;
    double nearestDistance = double.infinity;
    double nearestProgress = 0;
    for (int index = 0; index < positions.length; index++) {
      if (cumulativeDistances[index] / totalDistance < minimumProgress)
        continue;
      final maplibre.Position point = positions[index];
      final double distance = Geolocator.distanceBetween(
        location.latitude,
        location.longitude,
        point.lat,
        point.lng,
      );
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestProgress = cumulativeDistances[index] / totalDistance;
      }
    }
    if (!nearestDistance.isFinite) return null;
    return (distanceMeters: nearestDistance, progress: nearestProgress);
  }

  List<maplibre.Position> _sliceRoadRoute(
    List<maplibre.Position> positions,
    List<double> cumulativeDistances,
    double totalDistance,
    double startProgress,
    double endProgress,
  ) {
    if (positions.length < 2 || totalDistance <= 0) {
      return <maplibre.Position>[];
    }
    final double startDistance = startProgress.clamp(0, 1) * totalDistance;
    final double endDistance = endProgress.clamp(0, 1) * totalDistance;
    if (endDistance - startDistance < 1) return <maplibre.Position>[];

    maplibre.Position pointAtDistance(double target) {
      for (int index = 1; index < positions.length; index++) {
        if (cumulativeDistances[index] < target) continue;
        final double segmentStart = cumulativeDistances[index - 1];
        final double segmentLength = cumulativeDistances[index] - segmentStart;
        final double ratio = segmentLength <= 0
            ? 0
            : ((target - segmentStart) / segmentLength).clamp(0, 1);
        final maplibre.Position start = positions[index - 1];
        final maplibre.Position end = positions[index];
        return maplibre.Position(
          start.lng + (end.lng - start.lng) * ratio,
          start.lat + (end.lat - start.lat) * ratio,
        );
      }
      return positions.last;
    }

    return <maplibre.Position>[
      pointAtDistance(startDistance),
      for (int index = 1; index < positions.length - 1; index++)
        if (cumulativeDistances[index] > startDistance &&
            cumulativeDistances[index] < endDistance)
          positions[index],
      pointAtDistance(endDistance),
    ];
  }

  Future<void> _clearRoadRouteSegments(
    maplibre.PolylineAnnotationManager manager,
  ) async {
    for (final maplibre.PolylineAnnotation line
        in _roadRouteSegments.values.toList(growable: false)) {
      await manager.delete(line);
    }
    _roadRouteSegments.clear();
  }

  Future<void> _setRoadRouteSegment(
    maplibre.PolylineAnnotationManager manager,
    String key,
    List<maplibre.Position> positions,
    Color color,
  ) async {
    final maplibre.PolylineAnnotation? existing = _roadRouteSegments[key];
    if (positions.length < 2) {
      if (existing != null) {
        await manager.delete(existing);
        _roadRouteSegments.remove(key);
      }
      return;
    }
    final maplibre.LineString geometry = maplibre.LineString(
      coordinates: positions,
    );
    if (existing == null) {
      _roadRouteSegments[key] = await manager.create(
        maplibre.PolylineAnnotationOptions(
          geometry: geometry,
          lineColor: color.toARGB32(),
          lineWidth: key == 'active-transfer' ? 4 : 5,
          lineOpacity: 0.88,
          lineBorderColor: Colors.white.toARGB32(),
          lineBorderWidth: 1.5,
        ),
      );
      return;
    }
    existing.geometry = geometry;
    existing.lineColor = color.toARGB32();
    existing.lineWidth = key == 'active-transfer' ? 4 : 5;
    existing.lineOpacity = 0.88;
    await manager.update(existing);
  }

  Future<void> _renderRoadRouteSegments() async {
    final maplibre.PolylineAnnotationManager? manager = _routeLines;
    final List<maplibre.Position> positions = _roadRoutePositions;
    if (manager == null || positions.length < 2) return;
    final List<double> cumulativeDistances = _roadRouteCumulativeDistances(
      positions,
    );
    final double totalDistance = cumulativeDistances.last;
    if (totalDistance <= 0) return;

    double progressAtStop(BuyerOrderLocation stop) =>
        _nearestRoadProgress(
          positions,
          cumulativeDistances,
          totalDistance,
          stop,
        )?.progress ??
        0;
    final List<({BuyerOrderLocation stop, double progress})> centerStops =
        <({BuyerOrderLocation stop, double progress})>[];
    for (final BuyerOrderLocation hub in order.shipmentRouteStops) {
      final bool routeIncludesHub = _roadRouteStops.any(
        (BuyerOrderLocation routeStop) =>
            routeStop.latitude == hub.latitude &&
            routeStop.longitude == hub.longitude,
      );
      if (routeIncludesHub) {
        centerStops.add((stop: hub, progress: progressAtStop(hub)));
      }
    }

    final double firstCenterProgress = centerStops.isEmpty
        ? 0
        : centerStops.first.progress;
    final double lastCenterProgress = centerStops.isEmpty
        ? 0
        : centerStops.last.progress;
    final List<({BuyerOrderLocation stop, double progress})> receivedCenters =
        centerStops
            .where(
              (({BuyerOrderLocation stop, double progress}) center) =>
                  center.stop.centerRole?.toLowerCase() == 'destination' &&
                  center.stop.progressStatus?.toUpperCase() == 'RECEIVED',
            )
            .toList(growable: false);

    double progress = 0;
    final String status = order.normalizedStatus.toUpperCase().replaceAll(
      RegExp(r'[^A-Z0-9]'),
      '',
    );
    switch (status) {
      case 'PICKEDUP':
        progress = firstCenterProgress;
        break;
      case 'ATSORTINGCENTER':
      case 'SORTED':
        progress = receivedCenters.isNotEmpty
            ? receivedCenters.last.progress
            : firstCenterProgress;
        break;
      case 'ASSIGNEDTORIDER':
      case 'OUTFORDELIVERY':
      case 'DELIVERYFAILED':
        progress = lastCenterProgress;
        break;
      case 'DELIVERED':
      case 'COMPLETED':
        progress = 1;
        break;
      case 'RETURNED':
      case 'CANCELLED':
      case 'CANCELED':
        progress = 0;
        break;
    }

    if ((status == 'OUTFORDELIVERY' || status == 'DELIVERYFAILED') &&
        _navigation?.isLive == true &&
        order.riderLocation != null) {
      final ({double distanceMeters, double progress})? riderProgress =
          _nearestRoadProgress(
            positions,
            cumulativeDistances,
            totalDistance,
            order.riderLocation!,
            minimumProgress: lastCenterProgress,
          );
      if (riderProgress != null && riderProgress.distanceMeters <= 300) {
        progress = progress < riderProgress.progress
            ? riderProgress.progress
            : progress;
      }
    }

    if (status == 'RETURNED' || status == 'CANCELLED' || status == 'CANCELED') {
      _confirmedRouteProgress = 0;
    } else if (progress > _confirmedRouteProgress) {
      _confirmedRouteProgress = progress;
    }
    progress = _confirmedRouteProgress.clamp(0, 1).toDouble();

    ({double start, double end})? activeTransfer;
    for (final ({BuyerOrderLocation stop, double progress}) origin
        in centerStops.where(
          (({BuyerOrderLocation stop, double progress}) center) =>
              center.stop.centerRole?.toLowerCase() == 'origin' &&
              center.stop.progressStatus?.toUpperCase() == 'IN_TRANSIT',
        )) {
      for (final ({BuyerOrderLocation stop, double progress}) destination
          in centerStops) {
        final bool sameLeg =
            origin.stop.transferLegIds.isEmpty ||
            destination.stop.transferLegIds.any(
              origin.stop.transferLegIds.contains,
            );
        if (destination.stop.centerRole?.toLowerCase() == 'destination' &&
            sameLeg &&
            destination.progress > origin.progress) {
          activeTransfer = (start: origin.progress, end: destination.progress);
          break;
        }
      }
      if (activeTransfer != null) break;
    }

    if (activeTransfer != null && activeTransfer.end > activeTransfer.start) {
      await _setRoadRouteSegment(
        manager,
        'remaining',
        _sliceRoadRoute(
          positions,
          cumulativeDistances,
          totalDistance,
          activeTransfer.end,
          1,
        ),
        const Color(0xFF9CA3AF),
      );
      await _setRoadRouteSegment(
        manager,
        'active-transfer',
        _sliceRoadRoute(
          positions,
          cumulativeDistances,
          totalDistance,
          activeTransfer.start,
          activeTransfer.end,
        ),
        const Color(0xFFC2410C),
      );
      await _setRoadRouteSegment(
        manager,
        'traveled',
        _sliceRoadRoute(
          positions,
          cumulativeDistances,
          totalDistance,
          0,
          activeTransfer.start,
        ),
        AppTheme.resolve(context, _maroon),
      );
    } else {
      await _setRoadRouteSegment(
        manager,
        'remaining',
        _sliceRoadRoute(
          positions,
          cumulativeDistances,
          totalDistance,
          progress,
          1,
        ),
        const Color(0xFF9CA3AF),
      );
      await _setRoadRouteSegment(
        manager,
        'active-transfer',
        const <maplibre.Position>[],
        const Color(0xFFC2410C),
      );
      await _setRoadRouteSegment(
        manager,
        'traveled',
        _sliceRoadRoute(
          positions,
          cumulativeDistances,
          totalDistance,
          0,
          progress,
        ),
        AppTheme.resolve(context, _maroon),
      );
    }
  }

  String get _roadRouteSummary {
    final double? distance = _roadDistanceMeters;
    final double? duration = _roadDurationSeconds;
    if (_straightRouteFallback) {
      return 'Approximate guide between saved stops; road directions unavailable.';
    }
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
    final maplibre.MapLibreSession? map = _mapLibreMap;
    if (map == null) {
      return;
    }

    _zoomLevel = (_zoomLevel + step).clamp(3.0, 18.0);
    _lastMapCenter = _center;

    await map.setCamera(
      maplibre.CameraOptions(
        center: _toMapLibrePoint(_lastMapCenter),
        zoom: _zoomLevel,
      ),
    );
  }

  maplibre.Point _toMapLibrePoint(LatLng point) {
    return maplibre.Point(
      coordinates: maplibre.Position(point.longitude, point.latitude),
    );
  }
}

class _TrackingMapMarkerSpec {
  const _TrackingMapMarkerSpec({
    required this.latitude,
    required this.longitude,
    required this.color,
    required this.radius,
    required this.kind,
    required this.label,
  });

  final double latitude;
  final double longitude;
  final int color;
  final double radius;
  final BuyerMapMarkerKind kind;
  final String label;

  bool get isRider =>
      kind == BuyerMapMarkerKind.rider ||
      kind == BuyerMapMarkerKind.interHubRider;
}

class _RouteLegend extends StatelessWidget {
  const _RouteLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Container(
        width: 18,
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(99),
        ),
      ),
      const SizedBox(width: 5),
      Text(label, style: const TextStyle(fontSize: 10)),
    ],
  );
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
          style: TextStyle(
            fontSize: 11,
            color: AppTheme.resolve(context, ShopColors.muted),
          ),
        ),
      ],
    );
  }
}

class _RouteLineLegend extends StatelessWidget {
  final Color color;
  final String label;

  const _RouteLineLegend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 20,
          height: 4,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 10.5,
            color: AppTheme.resolve(context, ShopColors.muted),
          ),
        ),
      ],
    );
  }
}

import 'orders_screen.dart';

/// Navigation metadata supplied by Laravel's buyer shipment map endpoint.
/// A previous assignment must never stand in for the active rider.
class BuyerTrackingNavigation {
  const BuyerTrackingNavigation({
    this.rider,
    this.destination,
    this.destinationKind,
    this.assignmentType,
    this.live = false,
    this.assignmentId,
    this.locationRecordedAt,
  });

  final BuyerOrderLocation? rider;
  final BuyerOrderLocation? destination;
  final String? destinationKind;
  final String? assignmentType;
  final bool live;
  final String? assignmentId;
  final DateTime? locationRecordedAt;

  /// Mobile API deployments may return the controller payload directly or
  /// wrap it once or more in Laravel's conventional `data` envelope.
  static Map<String, dynamic> normalizePayload(Map<String, dynamic> payload) {
    var normalized = Map<String, dynamic>.from(payload);
    for (var depth = 0; depth < 3; depth++) {
      final bool alreadyContainsTrackingData =
          normalized['map_markers'] is List ||
          normalized['markers'] is List ||
          normalized['tracking'] is Map;
      final dynamic nested = normalized['data'];
      if (alreadyContainsTrackingData || nested is! Map) break;
      normalized = Map<String, dynamic>.from(nested);
    }
    return normalized;
  }

  bool get isLive => locationRecordedAt == null
      ? live
      : DateTime.now().difference(locationRecordedAt!.toLocal()) <=
            const Duration(minutes: 2);

  factory BuyerTrackingNavigation.fromPayload(Map<String, dynamic> payload) {
    final Map<String, dynamic> normalized = normalizePayload(payload);
    final tracking = normalized['tracking'] is Map
        ? Map<String, dynamic>.from(normalized['tracking'] as Map)
        : <String, dynamic>{};
    final raw = normalized['map_markers'] ?? normalized['markers'];
    final markers = raw is List
        ? raw.whereType<Map>().map((m) => Map<String, dynamic>.from(m)).toList()
        : <Map<String, dynamic>>[];
    final riders = markers.where((m) => m['kind'] == 'rider').toList();
    final activeId = tracking['active_assignment_id']?.toString();
    Map<String, dynamic>? active;
    for (final marker in riders) {
      if (activeId != null
          ? marker['assignment_id']?.toString() == activeId
          : marker['active_rider'] == true) {
        active = marker;
        break;
      }
    }
    // Compatibility with older endpoints without assignment metadata.
    if (active == null &&
        tracking.isEmpty &&
        riders.length == 1 &&
        !riders.single.containsKey('active_rider')) {
      active = riders.single;
    }
    final kind = tracking['active_destination_kind']?.toString();
    final assignmentType =
        (active?['assignment_type'] ?? tracking['active_assignment_type'])
            ?.toString()
            .toUpperCase();
    final destination = tracking['destination'];
    final lastLocation = tracking['last_location'] is Map
        ? Map<String, dynamic>.from(tracking['last_location'] as Map)
        : const <String, dynamic>{};
    final recordedAt = DateTime.tryParse(
      (active?['location_recorded_at'] ?? lastLocation['recorded_at'] ?? '')
          .toString(),
    );
    final bool markerReportsLive =
        active?['location_fresh'] == true ||
        active?['location_state'] == 'live';
    final bool locationIsFresh = recordedAt == null
        ? markerReportsLive
        : DateTime.now().difference(recordedAt.toLocal()) <=
              const Duration(minutes: 2);
    return BuyerTrackingNavigation(
      assignmentId: activeId ?? active?['assignment_id']?.toString(),
      locationRecordedAt: recordedAt,
      rider: active == null || active['location_pending'] == true
          ? null
          : parseBuyerOrderLogisticsStop(active),
      destination: destination is Map
          ? parseBuyerOrderLogisticsStop({
              ...Map<String, dynamic>.from(destination),
              'label': switch (kind) {
                'seller' => 'Seller pickup address',
                'logistics' => 'Sorting center',
                _ => 'Buyer delivery address',
              },
            })
          : null,
      destinationKind: kind,
      assignmentType: assignmentType,
      live:
          active != null &&
          active['location_pending'] != true &&
          locationIsFresh,
    );
  }

  String get riderLabel {
    final String freshness = isLive ? 'Live' : 'Last known';
    return switch (assignmentType) {
      'INTER_LOGISTICS' => '$freshness inter-hub rider',
      'PICKUP' => '$freshness pickup rider',
      _ => '$freshness delivery rider',
    };
  }

  String get navigationLabel => switch (assignmentType) {
    'INTER_LOGISTICS' => 'Inter-hub navigation',
    'PICKUP' => 'Pickup navigation',
    _ => 'Delivery navigation',
  };
}

/// Saved shipment stops define the parcel route; moving GPS is a separate line.
List<BuyerOrderLocation> buyerShipmentRouteStops(BuyerOrderData order) {
  final result = <BuyerOrderLocation>[];
  for (final stop in <BuyerOrderLocation>[
    if (order.sellerLocation != null) order.sellerLocation!,
    ...deduplicateBuyerOrderLogisticsStops(order.shipmentRouteStops),
    if (order.orderLocation != null) order.orderLocation!,
  ]) {
    if (result.isEmpty ||
        result.last.latitude != stop.latitude ||
        result.last.longitude != stop.longitude) {
      result.add(stop);
    }
  }
  return result;
}

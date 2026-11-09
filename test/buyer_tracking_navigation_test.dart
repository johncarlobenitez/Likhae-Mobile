import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/orders/buyer_tracking_navigation.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  test('saved route stays seller to hubs to buyer when rider moves', () {
    const seller = BuyerOrderLocation(
      latitude: 14.1,
      longitude: 121.1,
      label: 'Seller',
    );
    const hub = BuyerOrderLocation(
      latitude: 14.2,
      longitude: 121.2,
      label: 'Hub',
    );
    const buyer = BuyerOrderLocation(
      latitude: 14.3,
      longitude: 121.3,
      label: 'Buyer',
    );
    final order = BuyerOrderData.fromApi({'id': 1}).copyWith(
      sellerLocation: seller,
      orderLocation: buyer,
      shipmentRouteStops: [hub],
      riderLocation: const BuyerOrderLocation(
        latitude: 15,
        longitude: 122,
        label: 'Rider',
      ),
    );
    expect(buyerShipmentRouteStops(order), [seller, hub, buyer]);
    expect(buyerShipmentRouteStops(order.copyWith(riderLocation: seller)), [
      seller,
      hub,
      buyer,
    ]);
  });

  Map<String, dynamic> rider(
    int id, {
    bool live = true,
    bool pending = false,
  }) => {
    'kind': 'rider',
    'assignment_id': id,
    'latitude': 14.2,
    'longitude': 121.3,
    'label': 'Delivery rider',
    'location_fresh': live,
    'location_pending': pending,
  };
  Map<String, dynamic> payload({
    String kind = 'buyer',
    bool live = true,
    bool pending = false,
  }) => {
    'markers': [rider(1), rider(2, live: live, pending: pending)],
    'tracking': {
      'active_assignment_id': 2,
      'active_destination_kind': kind,
      'destination': {'latitude': 14.4, 'longitude': 121.5},
    },
  };

  test('uses active assignment instead of the first rider', () {
    final data = payload();
    (data['markers'] as List).first['latitude'] = 15.0;
    final navigation = BuyerTrackingNavigation.fromPayload(data);
    expect(navigation.rider?.latitude, 14.2);
    expect(navigation.live, isTrue);
    expect(navigation.destination?.latitude, 14.4);
  });

  test('unwraps nested Laravel data before reading markers and tracking', () {
    final navigation = BuyerTrackingNavigation.fromPayload({
      'success': true,
      'data': {'data': payload(kind: 'seller')},
    });
    expect(navigation.assignmentId, '2');
    expect(navigation.rider?.latitude, 14.2);
    expect(navigation.destinationKind, 'seller');
  });

  for (final kind in ['seller', 'logistics', 'buyer']) {
    test('uses Laravel destination for $kind guidance', () {
      final navigation = BuyerTrackingNavigation.fromPayload(
        payload(kind: kind),
      );
      expect(navigation.destinationKind, kind);
      expect(navigation.destination?.longitude, 121.5);
    });
  }

  test('keeps stale position but never calls it live', () {
    final navigation = BuyerTrackingNavigation.fromPayload(
      payload(live: false),
    );
    expect(navigation.rider, isNotNull);
    expect(navigation.live, isFalse);
    expect(navigation.riderLabel, 'Last known rider location');
  });

  test('pending active rider does not fall back to previous assignment', () {
    final navigation = BuyerTrackingNavigation.fromPayload(
      payload(pending: true),
    );
    expect(navigation.rider, isNull);
    expect(navigation.live, isFalse);
  });

  test('missing active rider never falls back to another rider', () {
    final data = payload();
    (data['tracking'] as Map)['active_assignment_id'] = 99;
    expect(BuyerTrackingNavigation.fromPayload(data).rider, isNull);
  });

  test('empty map clears rider and destination', () {
    final navigation = BuyerTrackingNavigation.fromPayload({
      'markers': [],
      'tracking': {},
    });
    expect(navigation.rider, isNull);
    expect(navigation.destination, isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/orders/order_tracking_screen.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  test('does not repeat a flat sorting-center label in the map marker', () {
    final stop = parseBuyerOrderLogisticsStop({
      'kind': 'center',
      'latitude': 14.58,
      'longitude': 120.98,
      'label': 'Origin sorting center',
      'center_role': 'origin',
    });

    expect(stop?.label, 'Origin sorting center');
  });

  test(
    'parses and orders sorting-center pins from the buyer orders payload',
    () {
      final order = BuyerOrderData.fromApi({
        'id': '42',
        'shipment_route_stops': [
          {
            'kind': 'center',
            'latitude': 14.6,
            'longitude': 121.0,
            'label': 'Destination sorting center',
            'sequence_no': 2,
            'center_role': 'destination',
          },
          {
            'kind': 'center',
            'latitude': 14.58,
            'longitude': 120.98,
            'label': 'Origin sorting center',
            'sequence_no': 0,
            'center_role': 'origin',
            'center_id': 501,
            'id': 'logistics-center-501-shipment-42-planned-origin',
          },
          {
            'kind': 'center',
            'latitude': 14.58001,
            'longitude': 120.98001,
            'label': 'Origin sorting center',
            'sequence_no': 1,
            'center_role': 'origin',
            'center_id': 501,
            'id': 'logistics-center-501-shipment-42-transfer-19-origin',
          },
          {
            'kind': 'center',
            'latitude': 14.5801,
            'longitude': 120.9801,
            'label': 'Origin sorting center',
            'sequence_no': 1,
            'center_role': 'origin',
            'center_id': 502,
          },
        ],
      });

      expect(order.shipmentRouteStops, hasLength(2));
      expect(order.shipmentRouteStops.first.label, 'Origin sorting center');
      expect(order.shipmentRouteStops.last.label, 'Destination sorting center');
    },
  );

  testWidgets('shows saved sorting center and destination without a rider', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 1500));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final order = BuyerOrderData.fromApi({'id': '42', 'status': 'SORTED'})
        .copyWith(
          orderLocation: const BuyerOrderLocation(
            latitude: 14.2,
            longitude: 121.3,
            label: 'San Miguel, Pila, Laguna',
          ),
          shipmentRouteStops: const [
            BuyerOrderLocation(
              latitude: 14.27,
              longitude: 121.45,
              label: 'Magdapio, Pagsanjan, Laguna',
            ),
          ],
        );
    await tester.pumpWidget(
      MaterialApp(
        home: OrderTrackingScreen(
          order: order,
          previewMap: const ColoredBox(color: Colors.white),
        ),
      ),
    );
    expect(find.text('Sorting center'), findsOneWidget);
    expect(find.text('Delivery address'), findsOneWidget);
    expect(find.text('Magdapio, Pagsanjan, Laguna'), findsWidgets);
    expect(find.textContaining('Rider GPS appears'), findsOneWidget);
    await tester.tap(find.text('Full map'));
    await tester.pump();
    expect(find.text('Close map'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

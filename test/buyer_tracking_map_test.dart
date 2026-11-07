import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/orders/order_tracking_screen.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
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

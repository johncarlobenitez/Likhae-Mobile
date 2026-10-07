import 'package:flutter_test/flutter_test.dart';

import 'package:likhae/app.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  testWidgets('App smoke test — renders without crashing',
      (WidgetTester tester) async {
    await tester.pumpWidget(const LikhaeApp());
    await tester.pumpAndSettle();

    // The app should build and display something on screen.
    expect(find.byType(LikhaeApp), findsOneWidget);
  });

  test('BuyerOrderData exposes rider location for live tracking', () {
    final BuyerOrderData order = BuyerOrderData.fromApi(<String, dynamic>{
      'id': '1001',
      'status': 'to-receive',
      'status_label': 'To Receive',
      'payment': 'Cash',
      'buyer': <String, dynamic>{'name': 'Rosa'},
      'shipping_address': '123 Main St',
      'rider_location': <String, dynamic>{
        'latitude': '14.2289',
        'longitude': '121.3608',
      },
      'order_location': <String, dynamic>{
        'latitude': '14.2326',
        'longitude': '121.3648',
      },
      'items': <Map<String, dynamic>>[],
    });

    expect(order.riderLocation, isNotNull);
    expect(order.riderLocation!.latitude, 14.2289);
    expect(order.riderLocation!.longitude, 121.3608);
  });
}

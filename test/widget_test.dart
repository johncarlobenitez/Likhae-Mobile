import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:likhae/app.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  testWidgets('App smoke test — renders without crashing', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const LikhaeApp());

    // The initial route can keep a live progress indicator running, so the
    // smoke test only needs the first frame to verify that the app builds.
    expect(find.byType(MaterialApp), findsOneWidget);
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

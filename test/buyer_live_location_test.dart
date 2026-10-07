import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';

void main() {
  test('maps and clears the synced rider location', () {
    final BuyerOrderData order = BuyerOrderData.fromApi(<String, dynamic>{
      'id': '42',
      'status': 'PROCESSING',
      'rider_location': <String, dynamic>{
        'latitude': 14.5995,
        'longitude': 120.9842,
      },
    });

    expect(order.riderLocation?.latitude, 14.5995);
    expect(order.riderLocation?.longitude, 120.9842);
    expect(order.copyWith(clearRiderLocation: true).riderLocation, isNull);
  });
}

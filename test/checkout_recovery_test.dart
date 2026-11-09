import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/checkout/checkout_screen.dart';

void main() {
  for (final failure in ['unavailable', 'server-error', 'missing-token']) {
    testWidgets('retrying a quote does not submit for $failure', (
      tester,
    ) async {
      var quotes = 0;
      var orders = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: CheckoutScreen(
            checkoutToken: 'test',
            items: const [
              CheckoutItemData(
                id: 1,
                productId: 2,
                sellerId: 3,
                seller: 'Shop',
                name: 'Basket',
                price: 100,
                quantity: 1,
              ),
            ],
            addresses: const [
              CheckoutAddressData(
                id: 1,
                label: 'Home',
                recipient: 'Test Buyer',
                phone: '09171234567',
                province: 'Laguna',
                city: 'Pila',
                barangay: 'San Miguel',
                postalCode: '4010',
                isDefault: true,
              ),
            ],
            couriersBySeller: const {},
            automaticRouting: true,
            requireCourierSelection: false,
            initialRecipientName: 'Test Buyer',
            initialContactNumber: '09171234567',
            onLoadQuote: (_) async {
              if (++quotes == 1) throw Exception('Temporary quote failure');
              if (failure == 'server-error') {
                throw const FormatException(
                  'The delivery service is temporarily unavailable. Please try again later.',
                );
              }
              return {
                if (failure != 'missing-token')
                  'shipping_quote_token': 'a' * 64,
                'delivery_availability': {
                  'available': false,
                  'message': 'Outside delivery area',
                },
              };
            },
            onPlaceOrder: (_) async {
              orders++;
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'Place Order');
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pumpAndSettle();
      expect(quotes, 2);
      expect(orders, 0);
      final message = switch (failure) {
        'server-error' =>
          'The delivery service is temporarily unavailable. Please try again later.',
        'missing-token' =>
          'The delivery service returned an incomplete quote. Please try again later.',
        _ => 'Outside delivery area',
      };
      expect(find.text(message), findsWidgets);
      expect(
        find.text(
          'Could not verify the shipping quote. Refresh checkout and try again.',
        ),
        findsNothing,
      );
    });
  }
}

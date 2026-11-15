import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/products/products_screen.dart';

void main() {
  testWidgets('category chips use independent scroll storage in filters', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductsScreen(
          products: const <BuyerProduct>[
            BuyerProduct(
              id: 1,
              name: 'Basket',
              category: 'Home Goods',
              categorySlug: 'home-goods',
              price: 125,
            ),
            BuyerProduct(
              id: 2,
              name: 'Bag',
              category: 'Fashion',
              categorySlug: 'fashion',
              price: 250,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filters').first);
    await tester.pumpAndSettle();

    expect(find.text('Category'), findsOneWidget);
    expect(find.byType(RangeSlider), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

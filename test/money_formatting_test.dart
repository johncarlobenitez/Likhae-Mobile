import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/deliveries/rider_collection_field.dart';
import 'package:likhae/shared/formatting/money_formatting.dart';

void main() {
  group('money formatting', () {
    testWidgets('rider cash collection input groups typed amounts', (
      WidgetTester tester,
    ) async {
      final TextEditingController controller = TextEditingController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RiderCollectionField(controller: controller),
          ),
        ),
      );

      expect(find.text('Actual cash collected (₱)'), findsOneWidget);
      await tester.enterText(find.byType(TextField), '123456.50');

      expect(controller.text, '123,456.50');
    });

    test('groups typed whole amounts at every three digits', () {
      expect(formatGroupedMoneyInput('123456'), '123,456');
      expect(formatGroupedMoneyInput('1000000'), '1,000,000');
      expect(formatGroupedMoneyInput('10000000'), '10,000,000');
    });

    test('preserves a typed decimal fraction', () {
      expect(formatGroupedMoneyInput('1234.50'), '1,234.50');
      expect(formatGroupedMoneyInput('.50'), '0.50');
    });

    test('formats live input while keeping the caret beside the last digit', () {
      const formatter = MonetaryAmountInputFormatter();
      final TextEditingValue result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '123456',
          selection: TextSelection.collapsed(offset: 6),
        ),
      );

      expect(result.text, '123,456');
      expect(result.selection, const TextSelection.collapsed(offset: 7));
    });

    test('formats pasted decimals and limits precision to two digits', () {
      const formatter = MonetaryAmountInputFormatter();
      final TextEditingValue result = formatter.formatEditUpdate(
        const TextEditingValue(),
        const TextEditingValue(
          text: '1234567.890',
          selection: TextSelection.collapsed(offset: 11),
        ),
      );

      expect(result.text, '1,234,567.89');
    });

    test('parses grouped peso values back to numeric values', () {
      expect(parseMoneyInput('₱1,234.50'), '1234.50');
      expect(parseMoneyAmount('₱1,234.50'), 1234.5);
      expect(parseMoneyAmount('PHP 10,000,000'), 10000000);
      expect(parseMoneyAmount('not an amount'), isNull);
    });

    test('formats peso displays with grouped values and two decimals', () {
      expect(formatPesoCurrency(1234567.5), '₱1,234,567.50');
      expect(formatPesoValue('10000000'), '₱10,000,000.00');
    });
  });
}

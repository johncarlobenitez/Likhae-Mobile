import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/checkout/checkout_screen.dart';
import 'package:likhae/features/buyer/checkout/shop_voucher_picker.dart';

void main() {
  test(
    'seller, platform, and shipping voucher selections use the API shape',
    () {
      const VoucherCodesSelection selection = VoucherCodesSelection(
        sellerCodes: <int, String>{12: 'SHOP10'},
        platformCode: 'LIKHAE15',
        shippingCode: 'SHIPFREE',
      );
      const Map<String, dynamic> expected = <String, dynamic>{
        'seller': <String, String>{'12': 'SHOP10'},
        'platform': 'LIKHAE15',
        'shipping': 'SHIPFREE',
      };

      expect(selection.toApiPayload(), expected);

      final CheckoutPlaceOrderRequest request = CheckoutPlaceOrderRequest(
        checkoutAttemptKey: 'attempt-key',
        checkoutToken: 'checkout-token',
        recipientName: 'Buyer Name',
        contactNumber: '09171234567',
        addressId: 3,
        couriersBySeller: const <int, int>{},
        notesBySeller: const <int, String>{},
        voucherCodes: selection.sellerCodes,
        platformVoucherCode: selection.platformCode,
        shippingVoucherCode: selection.shippingCode,
      );

      expect(request.toJson()['voucher_codes'], expected);
    },
  );
}

import '../rewards/rewards_screen.dart';

/// Mirrors Laravel's CheckoutService::discountAmount for seller vouchers.
double calculateSellerVoucherDiscount(
  RewardVoucherData voucher,
  double sellerSubtotal,
) {
  final double? amount = voucher.discountAmount;
  if (voucher.canUse == false ||
      amount == null ||
      amount <= 0 ||
      sellerSubtotal <= 0) {
    return 0;
  }

  final double minimum = voucher.minimumOrderAmount ?? 0;
  if (sellerSubtotal < minimum) return 0;

  double discount = voucher.discountType?.toUpperCase() == 'PERCENT'
      ? sellerSubtotal * amount / 100
      : amount;
  final double? maximum = voucher.maximumDiscountAmount;
  if (maximum != null && discount > maximum) discount = maximum;
  if (discount < 0) discount = 0;
  if (discount > sellerSubtotal) discount = sellerSubtotal;

  return (discount * 100).roundToDouble() / 100;
}

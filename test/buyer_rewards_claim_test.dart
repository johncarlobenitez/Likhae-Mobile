import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/rewards/rewards_screen.dart';

void main() {
  testWidgets('claiming a seller voucher refreshes Rewards', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1400);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final List<int> claimedVoucherIds = <int>[];
    int refreshCount = 0;

    const claimableVoucher = RewardVoucherData(
      icon: '10%',
      status: 'Test Store',
      value: '10% off',
      condition: 'No minimum spend',
      code: 'TEST10',
      expires: 'No expiry',
      voucherId: 42,
      sellerId: 7,
      canClaim: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: RewardsScreen(
          activeVouchers: const <RewardVoucherData>[claimableVoucher],
          onClaimVoucher: (voucherId) async {
            claimedVoucherIds.add(voucherId);
          },
          onUseVoucher: (_) {},
          onRefresh: () async {
            refreshCount++;
            return const RewardsData(
              activeVouchers: <RewardVoucherData>[
                RewardVoucherData(
                  icon: '10%',
                  status: 'Test Store',
                  value: '10% off',
                  condition: 'No minimum spend',
                  code: 'TEST10',
                  expires: 'No expiry',
                  voucherId: 42,
                  sellerId: 7,
                  isCollected: true,
                  canUse: true,
                ),
              ],
              voucherHistory: <VoucherHistoryData>[],
              pointsBalance: 0,
              pointActivities: <PointsActivityData>[],
              availableCashback: 0,
              pendingCashback: 0,
              cashbackActivities: <CashbackActivityData>[],
              pointsPerCompletedOrder: 50,
              pointsPerReview: 20,
              cashbackRate: 0,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final claimButton = find.text('Claim Voucher');
    await tester.tap(claimButton);
    await tester.pumpAndSettle();

    expect(claimedVoucherIds, <int>[42]);
    expect(refreshCount, 1);
    expect(find.text('Shop With Voucher'), findsOneWidget);
    expect(find.text('Claim Voucher'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/settings/buyer_system_settings_screen.dart';

void main() {
  testWidgets('buyer settings uses the grouped account settings menu', (
    WidgetTester tester,
  ) async {
    int securityOpens = 0;
    int addressOpens = 0;
    int walletOpens = 0;
    int vouchersOpen = 0;
    int reviewsOpen = 0;
    int followingOpen = 0;
    int recentOpen = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: BuyerSystemSettingsScreen(
          onMyAddresses: () => addressOpens++,
          onMyAccount: () => securityOpens++,
          onWallet: () => walletOpens++,
          onVouchers: () => vouchersOpen++,
          onReviewHistory: () => reviewsOpen++,
          onFollowingStores: () => followingOpen++,
          onRecentlyViewed: () => recentOpen++,
          onMessages: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account Settings'), findsOneWidget);
    expect(find.text('My Account'), findsOneWidget);
    expect(find.text('Account & Security'), findsOneWidget);
    expect(find.text('My Addresses'), findsOneWidget);
    expect(find.text('Wallet'), findsOneWidget);

    await tester.tap(find.text('Account & Security'));
    expect(securityOpens, 1);

    await tester.tap(find.text('My Addresses'));
    expect(addressOpens, 1);

    await tester.tap(find.text('Wallet'));
    expect(walletOpens, 1);

    Future<void> tapDestination(String title, int Function() openCount) async {
      await tester.scrollUntilVisible(find.text(title), 300);
      await tester.tap(find.text(title));
      expect(openCount(), 1, reason: '$title should invoke its destination');
    }

    await tapDestination('Vouchers', () => vouchersOpen);
    await tapDestination('My review history', () => reviewsOpen);
    await tapDestination('Following Stores', () => followingOpen);
    await tapDestination('Recently Viewed', () => recentOpen);

    await tester.scrollUntilVisible(find.text('Danger Zone'), 300);
    expect(find.text('Danger Zone'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Support'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Help Centre'), findsOneWidget);
    expect(find.text('Community Rules'), findsOneWidget);
    expect(find.text('LIKHAE Policies'), findsOneWidget);
    expect(find.text('About'), findsOneWidget);
  });
}

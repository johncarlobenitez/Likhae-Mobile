import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/profile/account_screen.dart';

void main() {
  testWidgets('enlarged account tabs remain reachable and respond to taps', (
    WidgetTester tester,
  ) async {
    int settingsOpens = 0;
    int recentlyViewedOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          profile: const BuyerProfileData(
            name: 'Test Buyer',
            email: 'buyer@example.test',
          ),
          onSystemSettings: () => settingsOpens++,
          onRecentlyViewed: () => recentlyViewedOpens++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder recentlyViewed = find.text('Recently Viewed');
    await tester.ensureVisible(recentlyViewed);
    final Finder recentlyViewedTapTarget = find
        .ancestor(of: recentlyViewed, matching: find.byType(InkWell))
        .first;
    expect(tester.getSize(recentlyViewedTapTarget).height, greaterThanOrEqualTo(54));
    await tester.tap(recentlyViewed);
    expect(recentlyViewedOpens, 1);

    final Finder settings = find.text('System Settings');
    await tester.ensureVisible(settings);
    await tester.tap(settings);
    expect(settingsOpens, 1);

    final Finder dangerZone = find.text('Danger Zone');
    await tester.ensureVisible(dangerZone);
    await tester.tap(dangerZone);
    await tester.pumpAndSettle();
    expect(find.text('Account Deletion'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

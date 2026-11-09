import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/profile/account_screen.dart';

void main() {
  testWidgets('Danger Zone validates confirmation then closes and signs out', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    String? submittedPassword;
    String? submittedConfirmation;
    int logoutCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          profile: const BuyerProfileData(
            name: 'Test Buyer',
            email: 'buyer@example.test',
          ),
          initialTab: BuyerAccountTab.dangerZone,
          showNavigationTabs: false,
          onDeleteAccount: (password, confirmation) async {
            submittedPassword = password;
            submittedConfirmation = confirmation;
          },
          onLogout: () async => logoutCalls++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final Finder closeButton = find.text('Close My Account');
    await tester.drag(find.byType(ListView), const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(find.text('Type DELETE to confirm.'), findsOneWidget);
    expect(submittedPassword, isNull);
    expect(logoutCalls, 0);

    await tester.enterText(find.byType(TextField).at(0), 'correct-password');
    await tester.enterText(find.byType(TextField).at(1), 'DELETE');
    await tester.tap(closeButton);
    await tester.pumpAndSettle();

    expect(submittedPassword, 'correct-password');
    expect(submittedConfirmation, 'DELETE');
    expect(logoutCalls, 1);
    expect(tester.takeException(), isNull);
  });
}

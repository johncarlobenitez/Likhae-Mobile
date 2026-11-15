import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/buyer/profile/account_screen.dart';

void main() {
  testWidgets('buyer profile is read-only and settings are accessible', (
    WidgetTester tester,
  ) async {
    int settingsOpens = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          profile: BuyerProfileData(
            name: 'Test Buyer',
            email: 'buyer@example.test',
            phone: '09123456789',
            middleInitial: 'Q',
            birthday: DateTime(1995, 4, 12),
            gender: BuyerGender.female,
          ),
          accountActive: true,
          onSystemSettings: () => settingsOpens++,
          showProfileSettingsButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Settings'));
    expect(settingsOpens, 1);
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Reward Points'), findsNothing);
    expect(find.text('Test Buyer'), findsWidgets);
    expect(find.text('buyer@example.test'), findsWidgets);
    expect(find.text('09123456789'), findsWidgets);
    expect(find.text('Q'), findsOneWidget);
    expect(find.text('1995-04-12'), findsOneWidget);
    expect(find.text('Female'), findsOneWidget);
    expect(find.text('Active'), findsWidgets);
    expect(find.byType(TextFormField), findsNothing);
    expect(find.text('Choose Photo'), findsNothing);
    expect(find.text('Save Changes'), findsNothing);

  });

  testWidgets('account shortcut buttons are removed from the profile page', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          profile: const BuyerProfileData(
            name: 'Test Buyer',
            email: 'buyer@example.test',
          ),
          onSystemSettings: () {},
          showProfileSettingsButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Recently Viewed'), findsNothing);
    expect(find.text('System Settings'), findsNothing);
    expect(find.text('Danger Zone'), findsNothing);
    expect(find.text('Addresses'), findsNothing);
    expect(find.text('Vouchers'), findsNothing);
    expect(find.text('My review history'), findsNothing);
    expect(find.text('Following Stores'), findsNothing);
    expect(find.byTooltip('Settings'), findsOneWidget);
  });

  testWidgets('Account & Security contains profile and password controls', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccountScreen(
          profile: const BuyerProfileData(
            name: 'Test Buyer',
            email: 'buyer@example.test',
            phone: '09123456789',
          ),
          initialTab: BuyerAccountTab.accountSecurity,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Account & Security'), findsOneWidget);
    expect(find.text('Edit Information'), findsOneWidget);
    expect(find.textContaining('Full name'), findsOneWidget);
    expect(find.text('Email address'), findsWidgets);
    expect(find.textContaining('Mobile number'), findsOneWidget);
    expect(find.text('Change Password'), findsOneWidget);
    expect(find.textContaining('Current password'), findsWidgets);
    expect(find.text('Update Password'), findsOneWidget);
  });
}

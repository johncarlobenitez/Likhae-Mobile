import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/app.dart';
import 'package:likhae/features/buyer/home/home_screen.dart';
import 'package:likhae/features/buyer/messages/messages_screen.dart';
import 'package:likhae/features/buyer/profile/account_screen.dart';
import 'package:likhae/routes/app_router.dart';
import 'package:likhae/shared/widgets/buyer_navigation.dart';

void main() {
  testWidgets('buyer tabs retain Home and its scroll offset', (tester) async {
    await tester.pumpWidget(const LikhaeApp());
    appRouter.go('/buyer/home');
    await tester.pumpAndSettle();
    final home = tester.state(find.byType(BuyerHomeScreen));
    final scroll = find.byKey(
      const PageStorageKey<String>('buyer-home-scroll'),
    );
    await tester.drag(scroll, const Offset(0, -400));
    await tester.pumpAndSettle();
    final scrollState = tester.state<ScrollableState>(
      find.descendant(of: scroll, matching: find.byType(Scrollable)).first,
    );
    final offset = scrollState.position.pixels;
    expect(offset, greaterThan(0));
    await tester.tap(
      find.descendant(
        of: find.byType(BuyerBottomNavigation),
        matching: find.text('Orders'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.descendant(
        of: find.byType(BuyerBottomNavigation),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.state(find.byType(BuyerHomeScreen)), same(home));
    expect(scrollState.position.pixels, closeTo(offset, 0.1));
    expect(tester.takeException(), isNull);
    appRouter.go('/login');
    await tester.pumpAndSettle();
  });

  testWidgets(
    '500-message conversation builds lazily and reaches its latest message',
    (tester) async {
      const seller = BuyerConversationData(
        sellerId: '1',
        conversationId: 'conversation-1',
        name: 'Store',
        slug: 'store',
      );
      final messages = List.generate(
        500,
        (i) => BuyerMessageData(
          id: '$i',
          body: 'Message number $i',
          time: '12:00',
          fromBuyer: i.isEven,
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: MessagesScreen(
            initialSeller: seller,
            conversations: const [seller],
            initialMessages: messages,
            showPreviewWhenEmpty: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Message number 499'), findsOneWidget);
      expect(find.text('Message number 0'), findsNothing);
      final built = find
          .byWidgetPredicate(
            (w) =>
                w is Text && (w.data?.startsWith('Message number ') ?? false),
          )
          .evaluate()
          .length;
      expect(built, lessThan(40));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('messages use server presence and read receipts', (tester) async {
    const seller = BuyerConversationData(
      sellerId: 'seller-1',
      conversationId: 'conversation-1',
      name: 'Store',
      slug: 'store',
    );
    final DateTime sentAt = DateTime(2026, 10, 25, 12);
    int heartbeatCount = 0;
    int receiptCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: MessagesScreen(
          initialSeller: seller,
          conversations: const <BuyerConversationData>[seller],
          initialMessages: <BuyerMessageData>[
            BuyerMessageData(
              id: 'message-1',
              conversationId: seller.conversationId,
              body: 'Is this available?',
              time: '12:00',
              sentAt: sentAt,
              fromBuyer: true,
            ),
          ],
          showPreviewWhenEmpty: false,
          onPresenceHeartbeat: () async {
            heartbeatCount++;
          },
          onRefreshConversationPresence: (BuyerConversationData _) async {
            receiptCount++;
            return BuyerConversationPresenceData(
              isOnline: true,
              recipientReadAt: sentAt.add(const Duration(seconds: 1)),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(heartbeatCount, greaterThan(0));
    expect(receiptCount, greaterThan(0));
    expect(find.text('Online'), findsOneWidget);
    expect(find.text('Seen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile revalidation retains an unsaved full name', (
    tester,
  ) async {
    Widget page(String serverName) => MaterialApp(
      home: AccountScreen(
        profile: BuyerProfileData(
          name: serverName,
          email: 'buyer@example.test',
          phone: '09123456789',
        ),
        showNavigationTabs: false,
      ),
    );
    await tester.pumpWidget(page('Saved Name'));
    final nameField = find.byType(TextFormField).first;
    await tester.enterText(nameField, 'Unsaved Name');
    await tester.pumpWidget(page('Updated Server Name'));
    expect(find.text('Unsaved Name'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

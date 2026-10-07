import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/features/rider/messages/rider_messages_screen.dart';

void main() {
  const RiderConversationData conversation = RiderConversationData(
    id: 'conversation-1',
    buyerId: 'buyer-1',
    buyerName: 'Maria Santos',
    orderId: 'order-41',
    trackingCode: 'LKH-DLV-2026-0041',
    lastMessage: 'Where is my order?',
    unreadCount: 1,
  );

  testWidgets('shows a clear disconnected empty state', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: RiderMessagesScreen()));

    expect(find.text('No conversations yet'), findsOneWidget);
    expect(
      find.textContaining('when Laravel messaging is connected'),
      findsOneWidget,
    );
  });

  testWidgets('loads a buyer conversation and displays the server response', (
    WidgetTester tester,
  ) async {
    String? sentBody;
    await tester.pumpWidget(
      MaterialApp(
        home: RiderMessagesScreen(
          conversations: const <RiderConversationData>[conversation],
          onLoadMessages: (RiderConversationData selected) async {
            expect(selected.id, conversation.id);
            return <RiderMessageData>[
              RiderMessageData(
                id: 'message-1',
                conversationId: 'conversation-1',
                body: 'Your parcel is on the way.',
                sentAt: DateTime(2026, 10, 4, 17),
                fromRider: true,
              ),
            ];
          },
          onSendMessage: (RiderConversationData selected, String body) async {
            sentBody = body;
            return RiderMessageData(
              id: 'message-2',
              conversationId: selected.id,
              body: body,
              sentAt: DateTime(2026, 10, 4, 17, 1),
              fromRider: true,
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();
    expect(find.text('Your parcel is on the way.'), findsOneWidget);
    expect(find.textContaining('order-41'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'I am nearby.');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(sentBody, 'I am nearby.');
    expect(find.text('I am nearby.'), findsOneWidget);
  });

  testWidgets('does not display a sent message without a backend callback', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RiderMessagesScreen(
          conversations: const <RiderConversationData>[conversation],
        ),
      ),
    );

    await tester.tap(find.text('Maria Santos'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Please call me.');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();

    expect(
      find.text('Messaging is not connected to Laravel yet.'),
      findsOneWidget,
    );
    expect(
      find.byWidgetPredicate(
        (Widget widget) => widget is Text && widget.data == 'Please call me.',
      ),
      findsNothing,
    );
  });
}

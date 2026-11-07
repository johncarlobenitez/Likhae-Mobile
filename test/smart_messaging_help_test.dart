import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/services/smart_messaging_service.dart';
import 'package:likhae/shared/widgets/smart_messaging_help.dart';

void main() {
  testWidgets('loads seller suggestions and submits a selected question', (
    tester,
  ) async {
    final _FakeSmartMessagingClient service = _FakeSmartMessagingClient();
    await _showHelp(tester, service);

    expect(service.bootstrappedProductId, 7);
    expect(find.text('Is this product available?'), findsOneWidget);
    await tester.tap(find.text('Is this product available?'));
    await tester.pumpAndSettle();

    expect(service.lastQuestionKey, '42');
    expect(service.lastQuestionText, isNull);
    expect(find.text('Seller-approved answer'), findsOneWidget);
    expect(
      find.text('The selected item is currently available.'),
      findsOneWidget,
    );

    await tester.ensureVisible(find.text('Yes, thanks'));
    await tester.tap(find.text('Yes, thanks'));
    await tester.pumpAndSettle();
    expect(service.lastFeedback, 'RESOLVED');
    expect(find.textContaining('Marked helpful.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('submits a buyer question written in their own words', (
    tester,
  ) async {
    final _FakeSmartMessagingClient service = _FakeSmartMessagingClient();
    await _showHelp(tester, service);

    await tester.enterText(
      find.byType(TextField),
      'Can you deliver this to Pila?',
    );
    await tester.pump();
    await tester.tap(find.text('Ask question'));
    await tester.pumpAndSettle();

    expect(service.lastQuestionKey, isNull);
    expect(service.lastQuestionText, 'Can you deliver this to Pila?');
    expect(
      find.text('Answer for: Can you deliver this to Pila?'),
      findsOneWidget,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });
}

Future<void> _showHelp(
  WidgetTester tester,
  SmartMessagingClient service,
) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (BuildContext context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => showSmartMessagingHelp(
                context,
                workspace: 'buyer',
                conversationId: 'conversation-42',
                productId: 7,
                service: service,
              ),
              child: const Text('Open help'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open help'));
  await tester.pumpAndSettle();
}

class _FakeSmartMessagingClient implements SmartMessagingClient {
  String? lastQuestionKey;
  String? lastQuestionText;
  String? lastFeedback;
  String? lastConcern;
  int? bootstrappedProductId;

  @override
  Future<Map<String, dynamic>> bootstrap({
    required String workspace,
    required String conversationId,
    int? productId,
    int? variantId,
  }) async {
    bootstrappedProductId = productId;
    return <String, dynamic>{
      'recipient_name': 'Tibay Furnishings',
      'welcome_message': 'Choose a question or ask in your own words.',
      'context_label': 'Product Executive Table',
      'suggestions': <Map<String, dynamic>>[
        <String, dynamic>{
          'key': '42',
          'category': 'Products',
          'question': 'Is this product available?',
        },
      ],
      'session': <String, dynamic>{'status': 'AUTOMATED_HELP'},
      'history': <dynamic>[],
    };
  }

  @override
  Future<Map<String, dynamic>> answer({
    required String workspace,
    required String conversationId,
    String? questionKey,
    String? questionText,
    int? productId,
    int? variantId,
  }) async {
    lastQuestionKey = questionKey;
    lastQuestionText = questionText;
    return <String, dynamic>{
      'question': questionText ?? 'Is this product available?',
      'answer': questionText == null
          ? 'The selected item is currently available.'
          : 'Answer for: $questionText',
      'answer_source': 'Seller-approved answer',
    };
  }

  @override
  Future<Map<String, dynamic>> feedback({
    required String workspace,
    required String conversationId,
    required String feedback,
  }) async {
    lastFeedback = feedback;
    return <String, dynamic>{'last_feedback': feedback};
  }

  @override
  Future<Map<String, dynamic>> requestHuman({
    required String workspace,
    required String conversationId,
    String? concern,
    int? productId,
    int? variantId,
  }) async {
    lastConcern = concern;
    return <String, dynamic>{'status': 'HUMAN_ASSISTANCE_REQUESTED'};
  }
}

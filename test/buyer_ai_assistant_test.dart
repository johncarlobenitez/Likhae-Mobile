import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/features/buyer/ai/buyer_ai_assistant.dart';
import 'package:likhae/services/buyer_ai_service.dart';

void main() {
  final Uri apiBase = Uri.parse(AppConfig.apiBaseUrl);
  final bool usesLoopbackApi =
      AppConfig.apiEnabled && apiBase.host == '127.0.0.1';

  group('Buyer AI offline help', () {
    test(
      'answers the built-in order, checkout, and voucher prompts',
      () async {
        final BuyerAiResponse order = await BuyerAiService.chat(
          message: 'How do I track my order?',
        );
        final BuyerAiResponse checkout = await BuyerAiService.chat(
          message: 'How do I check out?',
        );
        final BuyerAiResponse vouchers = await BuyerAiService.chat(
          message: 'Where are my vouchers?',
        );

        expect(order.reply, contains('Open Orders'));
        expect(order.reply, contains('connected to your account'));
        expect(order.options, contains('How do I check out?'));
        expect(checkout.reply, contains('continue to checkout'));
        expect(vouchers.reply, contains('Open Rewards'));
      },
      skip: AppConfig.apiEnabled,
    );

    testWidgets(
      'opens, sends a suggested prompt, and accepts a typed question',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: BuyerAiAssistant())),
        );

        await tester.tap(find.bySemanticsLabel('Open Buyer AI Assistant'));
        await tester.pumpAndSettle();
        expect(find.text('LIKHAE AI Assistant'), findsOneWidget);

        await tester.tap(
          find.widgetWithText(ActionChip, 'How do I check out?'),
        );
        await tester.pumpAndSettle();
        expect(find.text('How do I check out?'), findsOneWidget);
        expect(find.textContaining('continue to checkout'), findsOneWidget);

        await tester.enterText(
          find.byType(TextField),
          'Where are my vouchers?',
        );
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(find.textContaining('Open Rewards'), findsOneWidget);
      },
      skip: AppConfig.apiEnabled,
    );
  });

  test(
    'posts buyer chat to the authenticated assistant endpoint and parses options',
    () async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await TokenStorage.writeToken('buyer-ai-test-token');
      final HttpServer server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        apiBase.port,
      );
      String? requestMethod;
      String? requestPath;
      Map<String, dynamic>? postedBody;
      String? authorization;
      server.listen((HttpRequest request) async {
        requestMethod = request.method;
        requestPath = request.uri.path;
        postedBody =
            jsonDecode(await utf8.decoder.bind(request).join())
                as Map<String, dynamic>;
        authorization = request.headers.value('authorization');
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'reply': 'The API assistant is online.',
            'options': <String>['Check my cart', '', 'Where are my vouchers?'],
          }),
        );
        await request.response.close();
      });

      try {
        final BuyerAiResponse response = await BuyerAiService.chat(
          message: '  Hello assistant  ',
          page: 'orders',
          workspace: 'buyer',
        );

        expect(response.reply, 'The API assistant is online.');
        expect(response.options, <String>[
          'Check my cart',
          'Where are my vouchers?',
        ]);
        expect(requestMethod, 'POST');
        expect(requestPath, '/api/v1/buyer/ai/chat');
        expect(postedBody, <String, dynamic>{
          'message': 'Hello assistant',
          'page': 'orders',
        });
        expect(authorization, 'Bearer buyer-ai-test-token');
      } finally {
        await server.close(force: true);
        await TokenStorage.clearToken();
      }
    },
    skip: !usesLoopbackApi,
  );
}

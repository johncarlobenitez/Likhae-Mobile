import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/features/buyer/messages/messages_screen.dart';
import 'package:likhae/services/buyer_mobile_service.dart';

void main() {
  final base = Uri.parse(AppConfig.apiBaseUrl);
  test(
    'admin reply preserves thread and bypasses seller order endpoint',
    () async {
      FlutterSecureStorage.setMockInitialValues({});
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        base.port,
      );
      final requests = <Map<String, dynamic>>[];
      server.listen((request) async {
        if (request.method == 'POST') {
          requests.add({
            'path': request.uri.path,
            'body': jsonDecode(await utf8.decoder.bind(request).join()),
          });
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode({
            'success': true,
            'data': {
              'id': '99',
              'conversation_id': '12',
              'body': 'Hello',
              'from_buyer': true,
            },
          }),
        );
        await request.response.close();
      });
      try {
        const conversation = BuyerConversationData(
          sellerId: '7',
          name: 'LIKHAE Support',
          slug: 'conversation-12',
          conversationId: '12',
          recipientAccountType: 'ADMIN',
          orderContext: MessageOrderContext(
            orderReference: 'ORDER-1',
            status: 'Delivered',
            orderId: '1',
            sellerOrderId: '2',
          ),
        );
        final sent = await BuyerMobileService.sendMessage(
          conversation,
          'Hello',
        );
        expect(sent.conversationId, '12');
        expect(requests.single['path'], endsWith('/buyer/messages'));
        expect(requests.single['body'], {
          'recipient_id': 7,
          'conversation_id': 12,
          'body': 'Hello',
        });
        expect(conversation.copyWith(unread: 0).isSupport, isTrue);
      } finally {
        await server.close(force: true);
      }
    },
    skip: !AppConfig.apiEnabled || base.host != '127.0.0.1',
  );
}

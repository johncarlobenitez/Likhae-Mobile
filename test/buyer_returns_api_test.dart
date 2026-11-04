import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:likhae/features/buyer/orders/orders_screen.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/buyer_mobile_service.dart';

// Run with API_ENABLED=true and API_BASE_URL=http://127.0.0.1:18769/api/v1.
void main() {
  final Uri base = Uri.parse(AppConfig.apiBaseUrl);
  group('Return and refund API', () {
    late HttpServer server;
    late String method;
    late String path;
    late String body;
    dynamic payload;
    int status = 200;
    bool binary = false;
    int requestCount = 0;

    BuyerOrderReturnRequest returnRequest() => BuyerOrderReturnRequest(
      order: const BuyerOrderData(
        id: '12', status: 'completed', statusLabel: 'Completed',
        payment: 'Cash on Delivery', products: [], total: 100,
        buyerName: 'Buyer', shippingAddress: 'Address',
      ),
      issueCategory: 'DEFECTIVE', issueReason: 'Does not work',
      description: 'The item does not work.',
      quantitiesByItem: {'34': 1}, buyerEmail: 'buyer@example.test',
      evidence: [XFile.fromData(utf8.encode('test-photo'), name: 'evidence.jpg', path: 'evidence.jpg')],
    );

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      ApiClient.invalidateReads();
      payload = {'success': true};
      status = 200;
      binary = false;
      requestCount = 0;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
      server.listen((request) async {
        requestCount++;
        method = request.method;
        path = request.uri.path;
        body = await utf8.decoder.bind(request).join();
        request.response.statusCode = status;
        if (binary) {
          request.response.add([1, 2, 3, 4]);
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(payload));
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      ApiClient.invalidateReads();
    });

    test('uploads evidence bytes and return fields as multipart', () async {
      payload = {'success': true, 'request_id': 56};
      expect(await BuyerMobileService.requestOrderReturn(returnRequest()), '56');
      expect(method, 'POST');
      expect(path, '/api/v1/buyer/orders/12/return-refund');
      expect(body, contains('name="item_ids[]"\r\n\r\n34'));
      expect(body, contains('name="quantities[34]"\r\n\r\n1'));
      expect(body, contains('name="images[]"; filename="evidence.jpg"'));
      expect(body, contains('test-photo'));
    });

    test('gateway failure explains uncertain submission without retrying', () async {
      status = 502;
      payload = 'Bad Gateway';
      await expectLater(
        BuyerMobileService.requestOrderReturn(returnRequest()),
        throwsA(predicate((error) => error.toString().contains(
          'Check Returns & Refunds before submitting again',
        ))),
      );
      expect(requestCount, 1);
    });

    test('loads request list and case details', () async {
      payload = {
        'success': true,
        'data': [
          {'id': 12, 'status': 'pending'},
        ],
      };
      expect((await BuyerMobileService.fetchReturnRequests()).single['id'], 12);
      expect(method, 'GET');
      expect(path, '/api/v1/buyer/returns');
      payload = {
        'success': true,
        'data': {'id': 12, 'seller_cases': []},
      };
      expect((await BuyerMobileService.fetchReturnRequest('12'))['id'], 12);
      expect(path, '/api/v1/buyer/returns/12');
    });

    test('rejects missing case data', () async {
      expect(
        BuyerMobileService.fetchReturnRequest('12'),
        throwsFormatException,
      );
    });

    test('confirms noncash refund receipt for the seller case', () async {
      await BuyerMobileService.confirmReturnRefund('23');
      expect(method, 'POST');
      expect(path, '/api/v1/buyer/returns/seller-cases/23/confirm');
      expect(jsonDecode(body), {'confirm_receipt': true});
    });

    test('confirms cash receipt for the cash obligation', () async {
      await BuyerMobileService.confirmReturnCashRefund('34');
      expect(method, 'POST');
      expect(path, '/api/v1/buyer/returns/cash-refunds/34/confirm');
      expect(jsonDecode(body), {'confirm_receipt': true});
    });

    test('escalates the selected seller case with explanation', () async {
      await BuyerMobileService.escalateReturnRefund(
        sellerCaseId: '23',
        reason: 'Refund missing',
        explanation: 'The refund has not arrived.',
      );
      expect(method, 'POST');
      expect(path, '/api/v1/buyer/returns/seller-cases/23/escalate');
      expect(jsonDecode(body), {
        'reason': 'Refund missing',
        'explanation': 'The refund has not arrived.',
        'confirm_escalation': true,
      });
    });

    test('propagates rejected refund confirmations', () async {
      status = 422;
      payload = {'success': false, 'message': 'Refund not yet sent.'};
      await expectLater(
        BuyerMobileService.confirmReturnRefund('23'),
        throwsA(isA<Exception>()),
      );
      await expectLater(
        BuyerMobileService.confirmReturnCashRefund('34'),
        throwsA(isA<Exception>()),
      );
    });

    test('downloads evidence and payout proof bytes', () async {
      binary = true;
      expect(await BuyerMobileService.fetchReturnEvidence('45'), [1, 2, 3, 4]);
      expect(path, '/api/v1/buyer/returns/evidence/45');
      expect(await BuyerMobileService.fetchReturnPayoutProof('56'), [
        1,
        2,
        3,
        4,
      ]);
      expect(path, '/api/v1/buyer/returns/payout-proofs/56');
    });

    test('rejects unavailable private evidence', () async {
      status = 403;
      await expectLater(
        BuyerMobileService.fetchReturnEvidence('45'),
        throwsA(isA<Exception>()),
      );
    });
  }, skip: !AppConfig.apiEnabled || base.host != '127.0.0.1');
}

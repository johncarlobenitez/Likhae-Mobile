import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/services/buyer_mobile_service.dart';
import 'package:likhae/shared/widgets/buyer_navigation_badges.dart';

void main() {
  final base = Uri.parse(AppConfig.apiBaseUrl);
  final enabled = AppConfig.apiEnabled && base.host == '127.0.0.1';
  group(
    'Buy Now compatibility',
    () {
      late HttpServer server;
      late int routeStatus;
      late List<Map<String, dynamic>> cart;
      final writes =
          <({String method, String path, Map<String, dynamic> body})>[];
      Map<String, dynamic> item(int variant, int quantity) => {
        'id': '$variant',
        'product_id': 20,
        'product_variant_id': variant,
        'name': 'Tshirt',
        'quantity': quantity,
        'stock': 30,
        'price': 200,
      };

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues({});
        await TokenStorage.writeToken('test-token');
        ApiClient.invalidateReads();
        routeStatus = 405;
        cart = [item(7, 5), item(8, 3)];
        writes.clear();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
        server.listen((request) async {
          final path = request.uri.path;
          final raw = await utf8.decoder.bind(request).join();
          final body = raw.isEmpty
              ? <String, dynamic>{}
              : jsonDecode(raw) as Map<String, dynamic>;
          if (request.method != 'GET') {
            writes.add((method: request.method, path: path, body: body));
          }
          dynamic data = <dynamic>[];
          if (path.endsWith('/checkout/buy-now')) {
            request.response.statusCode = routeStatus;
            data = item(7, 2);
          } else if (path.endsWith('/buyer/cart')) {
            if (request.method == 'POST') {
              data = item(
                body['product_variant_id'] as int,
                body['quantity'] as int,
              );
              cart.add(data as Map<String, dynamic>);
            } else {
              data = cart;
            }
          } else if (request.method == 'PATCH') {
            final row = cart.singleWhere(
              (row) => path.endsWith('/${row['id']}'),
            );
            row['quantity'] = body['quantity'];
            data = row;
          }
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({'data': data, 'message': 'Request rejected'}),
          );
          await request.response.close();
        });
      });
      tearDown(() async {
        await BuyerNavigationBadges.instance.refresh(force: true);
        await server.close(force: true);
        await TokenStorage.clearToken();
      });

      test('405 replaces only the selected variation quantity', () async {
        final selected = await BuyerMobileService.buyNow(
          productId: 20,
          productVariantId: 7,
          quantity: 2,
        );
        expect(selected.quantity, 2);
        expect(cart.map((row) => row['quantity']), [2, 3]);
        expect(writes.map((write) => write.method), ['POST', 'PATCH']);
        expect(writes.last.path, endsWith('/buyer/cart/items/7'));
      });
      test(
        '404 adds a missing variation with the requested quantity',
        () async {
          routeStatus = 404;
          cart = [item(8, 3)];
          final selected = await BuyerMobileService.buyNow(
            productId: 20,
            productVariantId: 7,
            quantity: 2,
          );
          expect(selected.quantity, 2);
          expect(cart.map((row) => row['quantity']), [3, 2]);
          expect(writes.last.path, endsWith('/buyer/cart'));
          expect(writes, hasLength(2));
        },
      );
      test('supported endpoint requires no fallback write', () async {
        routeStatus = 201;
        final selected = await BuyerMobileService.buyNow(
          productId: 20,
          productVariantId: 7,
          quantity: 2,
        );
        expect(selected.quantity, 2);
        expect(writes, hasLength(1));
      });
      for (final status in [422, 500]) {
        test('$status does not retry a rejected or ambiguous write', () async {
          routeStatus = status;
          await expectLater(
            BuyerMobileService.buyNow(
              productId: 20,
              productVariantId: 7,
              quantity: 2,
            ),
            throwsException,
          );
          expect(writes, hasLength(1));
          expect(cart.first['quantity'], 5);
        });
      }
    },
    skip: !enabled ? 'Requires loopback API configuration.' : false,
  );
}

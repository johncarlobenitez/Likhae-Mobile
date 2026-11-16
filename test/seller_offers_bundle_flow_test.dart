import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/services/workspace_mobile_service.dart';

void main() {
  final Uri base = Uri.parse(AppConfig.apiBaseUrl);
  final bool enabled = AppConfig.apiEnabled && base.host == '127.0.0.1';

  group(
    'Bundle Deals API flow',
    () {
      late HttpServer server;
      final requests =
          <
            ({
              String method,
              String path,
              Map<String, String> query,
              String body,
            })
          >[];

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        await TokenStorage.writeToken('bundle-deals-test-token');
        ApiClient.invalidateReads();
        requests.clear();
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
        server.listen((HttpRequest request) async {
          final String body = await utf8.decoder.bind(request).join();
          requests.add((
            method: request.method,
            path: request.uri.path,
            query: request.uri.queryParameters,
            body: body,
          ));

          final bool isOfferList =
              request.method == 'GET' &&
              request.uri.path.endsWith('/buyer/offers');
          final dynamic payload = isOfferList
              ? <String, dynamic>{
                  'success': true,
                  'data': request.uri.queryParameters['page'] == '1'
                      ? <Map<String, dynamic>>[
                          <String, dynamic>{
                            'id': 42,
                            'type': 'BUNDLE',
                            'name': 'Weekend Bundle',
                          },
                          <String, dynamic>{
                            'id': 43,
                            'type': 'BUY_X_GET_Y',
                            'name': 'Free Gift Promotion',
                          },
                        ]
                      : <Map<String, dynamic>>[
                          <String, dynamic>{
                            'id': 44,
                            'type': 'BUNDLE',
                            'name': 'Second Bundle',
                          },
                        ],
                  'meta': <String, dynamic>{'last_page': 2},
                }
              : <String, dynamic>{
                  'success': true,
                  'message': 'Bundle items added to cart.',
                };
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(payload));
          await request.response.close();
        });
      });

      tearDown(() async {
        await server.close(force: true);
        await TokenStorage.clearToken();
        ApiClient.invalidateReads();
      });

      test(
        'loads paginated offers and posts selected bundle sets/options',
        () async {
          final List<Map<String, dynamic>> offers =
              await WorkspaceMobileService.rows('buyer/offers');
          final List<Map<String, dynamic>> bundles = offers
              .where((offer) => offer['type'] == 'BUNDLE')
              .toList(growable: false);

          expect(bundles.map((offer) => offer['name']), <String>[
            'Weekend Bundle',
            'Second Bundle',
          ]);
          expect(
            offers.where((offer) => offer['type'] == 'BUY_X_GET_Y'),
            hasLength(1),
          );
          expect(requests, hasLength(2));
          expect(requests[0].method, 'GET');
          expect(requests[0].path, endsWith('/buyer/offers'));
          expect(requests[0].query['page'], '1');
          expect(requests[1].query['page'], '2');

          final form = FormData()
            ..fields.add(const MapEntry('sets', '2'))
            ..fields.add(const MapEntry('choices[Size]', '71'));
          final response = await WorkspaceMobileService.send(
            'buyer/cart/bundles/42',
            form,
          );

          expect(response['message'], 'Bundle items added to cart.');
          expect(requests, hasLength(3));
          final request = requests.last;
          expect(request.method, 'POST');
          expect(request.path, endsWith('/buyer/cart/bundles/42'));
          expect(request.body, contains('name="sets"'));
          expect(request.body, contains('\r\n\r\n2\r\n'));
          expect(request.body, contains('name="choices[Size]"'));
          expect(request.body, contains('\r\n\r\n71\r\n'));
        },
      );
    },
    skip: !enabled
        ? 'Run with API_ENABLED=true and a loopback API_BASE_URL.'
        : false,
  );
}

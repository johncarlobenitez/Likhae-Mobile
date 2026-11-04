import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/philippine_address_service.dart';

void main() {
  final base = Uri.parse(AppConfig.apiBaseUrl);
  group(
    'Laravel address API',
    () {
      late HttpServer server;
      final requests = <Uri>[];
      var status = 200;

      setUp(() async {
        PhilippineAddressService.clearCache();
        requests.clear();
        status = 200;
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
        server.listen((request) async {
          requests.add(request.uri);
          request.response.statusCode = status;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode(
              status != 200
                  ? {'message': 'Address service unavailable'}
                  : request.uri.path.endsWith('/postal-code')
                  ? {'postal_code': '4301'}
                  : [
                      {'code': '0405643000', 'name': 'City of Lucena'},
                    ],
            ),
          );
          await request.response.close();
        });
      });

      tearDown(() async => server.close(force: true));

      test('uses Laravel lookup paths and preserves canonical codes', () async {
        final regions = await PhilippineAddressService.fetchRegions();
        expect(regions.single.code, '0405643000');
        await PhilippineAddressService.fetchProvinces('0400000000');
        await PhilippineAddressService.fetchMunicipalities('0405600000');
        await PhilippineAddressService.fetchBarangays('0405643000');
        final postal = await PhilippineAddressService.fetchPostalCode(
          municipalityCode: '0405643000',
          barangayCode: '0405643001',
          provinceCode: '0405600000',
          provinceName: 'Quezon',
          municipalityName: 'City of Lucena',
        );
        expect(postal, '4301');
        expect(requests.map((uri) => uri.path), [
          '/api/v1/address/philippines/regions',
          '/api/v1/address/philippines/regions/0400000000/provinces',
          '/api/v1/address/philippines/provinces/0405600000/municipalities',
          '/api/v1/address/philippines/municipalities/0405643000/barangays',
          '/api/v1/address/philippines/postal-code',
        ]);
        expect(requests.last.queryParameters['municipality'], '0405643000');
      });

      test(
        'surfaces Laravel failures instead of switching PSGC providers',
        () async {
          status = 503;
          await expectLater(
            PhilippineAddressService.fetchRegions(),
            throwsA(
              isA<DioException>().having(
                (error) => error.response?.statusCode,
                'status',
                503,
              ),
            ),
          );
          expect(requests, hasLength(1));
        },
      );
    },
    skip: base.host != '127.0.0.1'
        ? 'Run with --dart-define=API_BASE_URL=http://127.0.0.1:18764/api/v1'
        : false,
  );
}

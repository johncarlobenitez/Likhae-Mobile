import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/features/auth/register_screen.dart';
import 'package:likhae/features/buyer/profile/account_screen.dart';
import 'package:likhae/services/auth_service.dart';
import 'package:likhae/services/buyer_mobile_service.dart';

void main() {
  final Uri base = Uri.parse(AppConfig.apiBaseUrl);
  final bool enabled = AppConfig.apiEnabled && base.host == '127.0.0.1';

  group(
    'Account API contracts',
    () {
      late HttpServer server;
      late Directory uploadDirectory;
      late File validId;
      final List<
        ({String method, String path, Map<String, String> query, String body})
      >
      requests = [];

      setUp(() async {
        FlutterSecureStorage.setMockInitialValues(<String, String>{});
        ApiClient.invalidateReads();
        requests.clear();
        uploadDirectory = await Directory.systemTemp.createTemp(
          'likhae-account-api-',
        );
        validId = File(
          '${uploadDirectory.path}${Platform.pathSeparator}valid-id.png',
        );
        await validId.writeAsBytes(<int>[1, 2, 3]);
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
        server.listen((HttpRequest request) async {
          final String body = await utf8.decoder.bind(request).join();
          requests.add((
            method: request.method,
            path: request.uri.path,
            query: request.uri.queryParameters,
            body: body,
          ));

          dynamic response;
          int statusCode = 200;
          if (request.uri.path.endsWith('/auth/registration-policies')) {
            response = <String, dynamic>{
              'success': true,
              'ready': true,
              'policies': <Map<String, dynamic>>[
                <String, dynamic>{
                  'id': 4,
                  'policy_type': 'TERMS',
                  'version': 'terms-v3',
                },
                <String, dynamic>{
                  'id': 7,
                  'policy_type': 'PRIVACY',
                  'version': 'privacy-v2',
                },
              ],
            };
          } else if (request.uri.path.endsWith('/buyer/profile') &&
              request.method == 'GET') {
            response = <String, dynamic>{
              'success': true,
              'user': <String, dynamic>{
                'name': 'Taylor Buyer',
                'email': 'taylor@example.test',
                'contact_number': '+639171234567',
              },
            };
          } else {
            if (request.uri.path.endsWith('/auth/register')) {
              statusCode = 201;
            }
            response = <String, dynamic>{
              'success': true,
              'message': 'Saved.',
              'user': <String, dynamic>{
                'name': 'Mary J Santos',
                'email': 'taylor@example.test',
                'contact_number': '+639171234567',
                'birthday': '1995-05-06',
              },
            };
          }

          request.response.statusCode = statusCode;
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode(response));
          await request.response.close();
        });
      });

      tearDown(() async {
        await server.close(force: true);
        await uploadDirectory.delete(recursive: true);
        ApiClient.invalidateReads();
      });

      RegisterFormData registrationData(MobileAccountType accountType) {
        const AddressOption region = AddressOption(code: 'R1', name: 'Region');
        const AddressOption province = AddressOption(
          code: 'P1',
          name: 'Province',
        );
        const AddressOption municipality = AddressOption(
          code: 'M1',
          name: 'Municipality',
        );
        const AddressOption barangay = AddressOption(
          code: 'B1',
          name: 'Barangay',
        );
        return RegisterFormData(
          accountType: accountType,
          firstName: 'Taylor',
          middleInitial: '',
          lastName: 'Buyer',
          sex: 'female',
          birthday: DateTime(1995, 5, 6),
          age: 31,
          email: 'taylor@example.test',
          contactNumber: '+639171234567',
          region: region,
          province: province,
          municipality: municipality,
          barangay: barangay,
          street: 'Main Street',
          houseNumber: '12',
          postalCode: '1000',
          landmark: '',
          vehicleType: null,
          plateNumber: null,
          targetLogisticsCenterId: null,
          driversLicenseNumber: null,
          validId: RegistrationDocument(
            name: 'valid-id.png',
            path: validId.path,
          ),
          vehicleOrCr: null,
          driversLicense: null,
          password: 'StrongPass123!',
          emailVerificationToken: 'verified-email-token',
          termsAcknowledged: true,
          privacyAcknowledged: true,
        );
      }

      test(
        'registration sends current policy versions and consent fields',
        () async {
          await AuthService.register(registrationData(MobileAccountType.buyer));

          expect(requests, hasLength(2));
          expect(requests.first.method, 'GET');
          expect(requests.first.path, '/api/v1/auth/registration-policies');
          expect(requests.first.query['role'], 'BUYER');

          final String body = requests.last.body;
          expect(requests.last.method, 'POST');
          expect(requests.last.path, '/api/v1/auth/register');
          expect(body, contains('name="terms_acknowledged"'));
          expect(body, contains('name="privacy_acknowledged"'));
          expect(body, contains('name="policy_acceptances[4]"'));
          expect(body, contains('terms-v3'));
          expect(body, contains('name="policy_acceptances[7]"'));
          expect(body, contains('privacy-v2'));
          expect(body, contains('name="email_verification_token"'));
          expect(body, contains('name="valid_id"'));
        },
      );

      test('rider registration requests rider policy versions', () async {
        await AuthService.register(registrationData(MobileAccountType.rider));

        expect(requests.first.path, '/api/v1/auth/registration-policies');
        expect(requests.first.query['role'], 'RIDER');
      });

      test(
        'profile update uses Laravel profile field names and PATCH',
        () async {
          final BuyerProfileData updated =
              await BuyerMobileService.updateProfile(
                UpdateBuyerProfileRequest(
                  name: 'Mary J Santos',
                  email: 'taylor@example.test',
                  phone: '+639171234567',
                  birthday: DateTime(1995, 5, 6),
                  gender: null,
                ),
              );

          expect(requests, hasLength(2));
          expect(requests.last.method, 'PATCH');
          expect(requests.last.path, '/api/v1/buyer/profile');
          final Map<String, dynamic> body =
              jsonDecode(requests.last.body) as Map<String, dynamic>;
          expect(body['first_name'], 'Mary');
          expect(body['middle_initial'], 'J');
          expect(body['last_name'], 'Santos');
          expect(body['contact_number'], '+639171234567');
          expect(body['birthday'], '1995-05-06');
          expect(body.containsKey('email'), isFalse);
          expect(updated.name, 'Mary J Santos');
        },
      );
    },
    skip: !enabled
        ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
        : false,
  );
}

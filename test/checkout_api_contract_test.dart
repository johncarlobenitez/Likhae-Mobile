import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';
import 'package:likhae/services/buyer_mobile_service.dart';

void main() {
  final Uri base = Uri.parse(AppConfig.apiBaseUrl);
  final bool enabled = AppConfig.apiEnabled && base.host == '127.0.0.1';

  group('Checkout API contract', () {
    late HttpServer server;
    final requests =
        <({String method, String path, String body, String? token})>[];
    dynamic responseBody;
    int responseStatus = 200;

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues(<String, String>{});
      await TokenStorage.writeToken('checkout-test-token');
      ApiClient.invalidateReads();
      requests.clear();
      responseStatus = 200;
      responseBody = <String, dynamic>{
        'success': true,
        'data': <String, dynamic>{},
      };
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, base.port);
      server.listen((HttpRequest request) async {
        requests.add((
          method: request.method,
          path: request.uri.path,
          body: await utf8.decoder.bind(request).join(),
          token: request.headers.value('authorization'),
        ));
        request.response.statusCode = responseStatus;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(responseBody));
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      await TokenStorage.clearToken();
      ApiClient.invalidateReads();
    });

    test(
      'quote server failure reports delivery unavailability',
      () async {
        responseStatus = 500;
        responseBody = {'message': 'Server Error'};
        await expectLater(
          BuyerMobileService.previewCheckout(cartItemIds: [12], addressId: 8),
          throwsA(
            isA<FormatException>().having(
              (error) => error.message,
              'message',
              'The delivery service is temporarily unavailable. Please try again later.',
            ),
          ),
        );
        expect(requests, hasLength(1));
      },
      skip: !enabled ? 'Requires loopback API configuration.' : false,
    );

    test(
      'checkout loads saved addresses from the buyer API',
      () async {
        responseBody = <String, dynamic>{
          'success': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 8,
              'label': 'Home',
              'recipient_name': 'Test Buyer',
              'contact_number': '09171234567',
              'province_name': 'Laguna',
              'municipality_name': 'Pila',
              'barangay_name': 'San Miguel',
              'street_address': '1 Purok',
              'postal_code': '4010',
              'is_default': true,
            },
          ],
        };

        final addresses = await BuyerMobileService.fetchCheckoutAddresses();

        expect(addresses, hasLength(1));
        expect(addresses.single.id, 8);
        expect(addresses.single.recipient, 'Test Buyer');
        expect(addresses.single.isDefault, isTrue);
        expect(requests.single.path, endsWith('/buyer/addresses'));
        expect(requests.single.token, 'Bearer checkout-test-token');
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );

    test(
      'checkout loads available providers and routing mode',
      () async {
        responseBody = <String, dynamic>{
          'success': true,
          'automatic_routing': true,
          'data': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 4,
              'name': 'Pagsanjan Logistics',
              'fee': 75,
            },
          ],
        };

        final Map<String, dynamic> options =
            await BuyerMobileService.fetchCheckoutOptions();

        expect(options['automatic_routing'], isTrue);
        expect((options['data'] as List).single['id'], 4);
        expect(requests.single.method, 'GET');
        expect(requests.single.path, endsWith('/buyer/checkout/options'));
        expect(requests.single.token, 'Bearer checkout-test-token');
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );

    test(
      'rewards endpoint supplies checkout points and voucher choices',
      () async {
        responseBody = <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'active_vouchers': <Map<String, dynamic>>[
              <String, dynamic>{
                'code': 'SHIPFREE',
                'voucher_type': 'shipping',
                'value': 'Free shipping',
              },
            ],
            'voucher_history': <dynamic>[],
            'points_balance': 160,
            'point_activities': <dynamic>[],
            'available_cashback': 0,
            'pending_cashback': 0,
            'cashback_activities': <dynamic>[],
            'points_per_completed_order': 50,
            'points_per_review': 20,
            'minimum_points_redemption': 100,
            'points_per_peso': 100,
            'cashback_rate': 0,
          },
        };

        final rewards = await BuyerMobileService.fetchRewards();

        expect(rewards.pointsBalance, 160);
        expect(rewards.activeVouchers.single.code, 'SHIPFREE');
        expect(requests.single.method, 'GET');
        expect(requests.single.path, endsWith('/buyer/rewards'));
        expect(requests.single.token, 'Bearer checkout-test-token');
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );

    test(
      'preview returns Laravel shipping token and sends selected quote inputs',
      () async {
        final String token = List<String>.filled(64, 'b').join();
        responseBody = <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{
            'shipping_quote_token': token,
            'shipping_total': 75.0,
            'grand_total': 575.0,
          },
        };

        final Map<String, dynamic> quote =
            await BuyerMobileService.previewCheckout(
              cartItemIds: const <int>[12, 13],
              addressId: 8,
              voucherCodes: const <int, String>{31: 'SHOP10'},
              platformVoucherCode: 'PLATFORM5',
              shippingVoucherCode: 'SHIPFREE',
              protectionItemIds: const <int>[13],
              rewardPoints: 100,
            );

        expect(quote['shipping_quote_token'], token);
        expect(requests.single.method, 'POST');
        expect(requests.single.path, endsWith('/buyer/checkout/preview'));
        expect(requests.single.token, 'Bearer checkout-test-token');
        final Map<String, dynamic> body =
            jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['cart_item_ids'], <int>[12, 13]);
        expect(body['address_id'], 8);
        expect(body['protection_item_ids'], <int>[13]);
        expect(body['reward_points'], 100);
        expect(body['voucher_codes'], <String, dynamic>{
          'seller': <String, String>{'31': 'SHOP10'},
          'platform': 'PLATFORM5',
          'shipping': 'SHIPFREE',
        });
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );

    test(
      'cart preview uses its existing Laravel quote route',
      () async {
        responseBody = <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'shipping_quote_token': 'd' * 64},
        };

        final Map<String, dynamic> quote =
            await BuyerMobileService.previewCheckout(
              cartItemIds: const <int>[12],
              addressId: 8,
              cartPreview: true,
            );

        expect(quote['shipping_quote_token'], 'd' * 64);
        expect(requests.single.path, endsWith('/buyer/cart/preview'));
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );

    test(
      'place order sends the exact shipping token and checkout selections',
      () async {
        final String token = List<String>.filled(64, 'c').join();
        responseBody = <String, dynamic>{
          'success': true,
          'data': <String, dynamic>{'id': 'order-91', 'order_number': 'LK91'},
        };

        final Map<String, dynamic> order = await BuyerMobileService.placeOrder(
          cartItemIds: const <int>[12, 13],
          addressId: 8,
          paymentMethod: 'cod',
          recipientName: 'Test Buyer',
          contactNumber: '09171234567',
          logisticsCenterId: 4,
          voucherCodes: const <int, String>{31: 'SHOP10'},
          platformVoucherCode: 'PLATFORM5',
          shippingVoucherCode: 'SHIPFREE',
          sellerNotes: const <int, String>{31: 'Call on arrival'},
          protectionItemIds: const <int>[13],
          rewardPoints: 100,
          checkoutAttemptKey: '00000000-0000-4000-8000-000000000091',
          priceSnapshot: const <String, dynamic>{
            '12': '250.00',
            '13': '250.00',
          },
          shippingQuoteToken: token,
        );

        expect(order['order_number'], 'LK91');
        expect(requests.single.method, 'POST');
        expect(requests.single.path, endsWith('/buyer/checkout'));
        expect(requests.single.token, 'Bearer checkout-test-token');
        final Map<String, dynamic> body =
            jsonDecode(requests.single.body) as Map<String, dynamic>;
        expect(body['shipping_quote_token'], token);
        expect(body['cart_item_ids'], <int>[12, 13]);
        expect(body['address_id'], 8);
        expect(body['logistics_center_id'], 4);
        expect(body['payment_method'], 'COD');
        expect(body['expected_price_snapshot'], <String, String>{
          '12': '250.00',
          '13': '250.00',
        });
        expect(body['protection_item_ids'], <int>[13]);
        expect(body['reward_points'], 100);
        expect(body['seller_notes'], <String, String>{'31': 'Call on arrival'});
        expect(body['voucher_codes'], <String, dynamic>{
          'seller': <String, String>{'31': 'SHOP10'},
          'platform': 'PLATFORM5',
          'shipping': 'SHIPFREE',
        });
      },
      skip: !enabled
          ? 'Requires API_ENABLED=true and loopback API_BASE_URL.'
          : false,
    );
  });
}

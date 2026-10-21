import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/api/api_client.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/storage/token_storage.dart';

// Run this file separately with --dart-define=API_ENABLED=true. All requests
// target the ephemeral loopback fixture below, never the configured server.
void main() {
  group('API request accuracy', () {
    late HttpServer server;
    late String base;
    var reads = 0;
    Completer<void>? gate;
    final tokens = <String?>[];

    setUp(() async {
      FlutterSecureStorage.setMockInitialValues({});
      await TokenStorage.writeToken('session-a');
      ApiClient.invalidateReads();
      reads = 0;
      tokens.clear();
      gate = null;
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      base = 'http://127.0.0.1:${server.port}';
      server.listen((request) async {
        final value = request.method == 'GET' ? ++reads : 0;
        tokens.add(request.headers.value('authorization'));
        final pending = gate;
        if (pending != null && request.method == 'GET') await pending.future;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'value': value}));
        await request.response.close();
      });
    });
    tearDown(() async {
      if (gate != null && !gate!.isCompleted) gate!.complete();
      await server.close(force: true);
      await TokenStorage.clearToken();
      ApiClient.invalidateReads();
    });

    test(
      'concurrent identical GETs use one HTTP request; cart is fresh next time',
      () async {
        final result = await Future.wait(
          List.generate(6, (_) => ApiClient.get('$base/cart')),
        );
        expect(reads, 1);
        expect(result.every((response) => response.data['value'] == 1), isTrue);
        final next = await ApiClient.get('$base/cart');
        expect(next.data['value'], 2);
        expect(reads, 2);
      },
    );

    test('query filters are part of the request identity', () async {
      await Future.wait([
        ApiClient.get(
          '$base/products',
          queryParameters: {'page': 1, 'q': '%_'},
        ),
        ApiClient.get(
          '$base/products',
          queryParameters: {'q': '%_', 'page': 1},
        ),
        ApiClient.get(
          '$base/products',
          queryParameters: {'page': 2, 'q': '%_'},
        ),
      ]);
      expect(reads, 2);
    });

    test(
      'mutations and account changes invalidate explicit reference caches',
      () async {
        Future<dynamic> categories() => ApiClient.get(
          '$base/categories',
          cacheFor: const Duration(minutes: 2),
        );
        await categories();
        await categories();
        expect(reads, 1);
        await ApiClient.post('$base/change', {});
        await categories();
        expect(reads, 2);
        await TokenStorage.writeToken('session-b');
        await categories();
        expect(reads, 3);
        expect(tokens.last, 'Bearer session-b');
        await TokenStorage.clearToken();
        await categories();
        expect(tokens.last, isNull);
      },
    );

    test(
      'a mutation does not reuse a read started before that mutation',
      () async {
        gate = Completer<void>();
        final old = ApiClient.get('$base/cart');
        // The shared read starts synchronously before post invalidates it.
        await ApiClient.post('$base/change', {});
        final fresh = ApiClient.get('$base/cart');
        gate!.complete();
        await Future.wait([old, fresh]);
        expect(reads, 2);
      },
    );
  }, skip: !AppConfig.apiEnabled);
}

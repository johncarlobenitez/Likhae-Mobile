import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:likhae/core/data/async_cache.dart';

void main() {
  test('shares concurrent work but never retains uncached live data', () async {
    final cache = AsyncCache<String, int>();
    final response = Completer<int>();
    var calls = 0;
    Future<int> fetch() {
      calls++;
      return response.future;
    }

    final first = cache.load('cart', fetch);
    final second = cache.load('cart', fetch);
    expect(calls, 1);
    response.complete(10);
    expect(await Future.wait([first, second]), [10, 10]);
    await cache.load('cart', fetch);
    expect(calls, 2);
  });

  test(
    'reference data expires, refreshes, and evicts the least recently used entry',
    () async {
      var now = DateTime(2026);
      final cache = AsyncCache<String, int>(maximumEntries: 2, now: () => now);
      var calls = 0;
      Future<int> load(String key, {bool refresh = false}) => cache.load(
        key,
        () async => ++calls,
        lifetime: const Duration(minutes: 2),
        refresh: refresh,
      );
      expect(await load('a'), 1);
      expect(await load('a'), 1);
      await load('b');
      await load('a');
      await load('c');
      expect(await load('b'), 4);
      now = now.add(const Duration(minutes: 3));
      expect(await load('b'), 5);
      expect(await load('b', refresh: true), 6);
    },
  );

  test('a failed request can be retried', () async {
    final cache = AsyncCache<String, int>();
    await expectLater(
      cache.load('x', () async => throw StateError('offline')),
      throwsStateError,
    );
    expect(await cache.load('x', () async => 7), 7);
  });

  test(
    'invalidation prevents old session responses overwriting newer data',
    () async {
      final cache = AsyncCache<String, int>();
      final old = Completer<int>();
      final fresh = Completer<int>();
      final previous = cache.load(
        'x',
        () => old.future,
        lifetime: const Duration(minutes: 2),
      );
      cache.clear();
      final current = cache.load(
        'x',
        () => fresh.future,
        lifetime: const Duration(minutes: 2),
      );
      old.complete(1);
      await previous;
      final joined = cache.load('x', () async => 99);
      fresh.complete(2);
      expect(await current, 2);
      expect(await joined, 2);
      expect(await cache.load('x', () async => 99), 2);
    },
  );
}

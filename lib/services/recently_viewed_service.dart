import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../features/buyer/products/product_details_screen.dart';
import 'auth_service.dart';

/// Account-scoped browsing history, cached locally for offline use.
class RecentlyViewedService {
  static const _storage = FlutterSecureStorage();
  static const _syncKeyPrefix = 'recently_viewed_synced_v1_';
  static const _pendingKeyPrefix = 'recently_viewed_pending_v1_';
  static Future<void> _queue = Future<void>.value();
  static int? _revision;
  static Future<int>? _buyer;

  static Future<int> _buyerId() {
    if (_revision != TokenStorage.revision || _buyer == null) {
      _revision = TokenStorage.revision;
      _buyer = AuthService.getCurrentUser().then((user) => user.id);
    }
    return _buyer!;
  }

  static Future<List<ProductDetailData>> read() async {
    try {
      final id = await _buyerId();
      await _queue;
      final local = await _read(id);
      if (!AppConfig.apiEnabled) return local;

      final remoteRows = await _readRemote();
      if (remoteRows == null) return local;
      List<ProductDetailData> remote = remoteRows;

      final syncKey = '$_syncKeyPrefix$id';
      try {
        if (await _storage.read(key: syncKey) != 'true') {
          await _queueLegacyHistory(id, local, remote);
        }
        final uploaded = await _syncPendingHistory(id, local, remote);
        if (uploaded) {
          final refreshedRemote = await _readRemote();
          if (refreshedRemote != null) remote = refreshedRemote;
        }
        if ((await _readPendingIds(id)).isNotEmpty) {
          remote = _merge(remote, local);
        }
      } catch (_) {
        remote = _merge(remote, local);
      }

      try {
        await _save(id, remote);
      } catch (_) {
        // The server remains the source of truth when the cache cannot update.
      }
      return remote;
    } catch (_) {
      _buyer = null;
      rethrow;
    }
  }

  static Future<void> _queueLegacyHistory(
    int buyerId,
    List<ProductDetailData> local,
    List<ProductDetailData> remote,
  ) async {
    // Earlier app versions kept history only on this device. Queue missing
    // entries once, without bumping products already viewed on the web.
    final remoteIds = remote.map((product) => product.id).toSet();
    final pending = await _readPendingIds(buyerId);
    pending.addAll(
      local
          .where((product) => !remoteIds.contains(product.id))
          .map((product) => product.id),
    );
    await _savePendingIds(buyerId, pending);
    await _storage.write(key: '$_syncKeyPrefix$buyerId', value: 'true');
  }

  static Future<bool> _syncPendingHistory(
    int buyerId,
    List<ProductDetailData> local,
    List<ProductDetailData> remote,
  ) async {
    final pending = await _readPendingIds(buyerId);
    if (pending.isEmpty) return false;

    final localById = <int, ProductDetailData>{
      for (final product in local) product.id: product,
    };
    pending.removeWhere((id) => !localById.containsKey(id));
    final remoteIds = remote.map((product) => product.id).toSet();
    var uploaded = false;

    for (final product in local.reversed) {
      if (!pending.contains(product.id)) continue;
      if (remoteIds.contains(product.id)) {
        pending.remove(product.id);
        continue;
      }
      if (!await _recordRemoteView(product.id)) break;
      pending.remove(product.id);
      uploaded = true;
    }

    await _savePendingIds(buyerId, pending);
    return uploaded;
  }

  static Future<Set<int>> _readPendingIds(int buyerId) async {
    final value = await _storage.read(key: '$_pendingKeyPrefix$buyerId');
    if (value == null) return <int>{};
    try {
      final decoded = jsonDecode(value);
      if (decoded is! List) return <int>{};
      return decoded
          .map((id) => int.tryParse(id.toString()))
          .whereType<int>()
          .where((id) => id > 0)
          .toSet();
    } catch (_) {
      return <int>{};
    }
  }

  static Future<void> _savePendingIds(int buyerId, Set<int> ids) {
    return _storage.write(
      key: '$_pendingKeyPrefix$buyerId',
      value: jsonEncode(ids.toList()..sort()),
    );
  }

  static Future<void> _markPending(int buyerId, int productId) async {
    final pending = await _readPendingIds(buyerId);
    pending.add(productId);
    await _savePendingIds(buyerId, pending);
  }

  static Future<void> _markSynced(int buyerId, int productId) async {
    final pending = await _readPendingIds(buyerId);
    pending.remove(productId);
    await _savePendingIds(buyerId, pending);
  }

  static Future<List<ProductDetailData>?> _readRemote() async {
    try {
      final response = await ApiClient.get(
        'buyer/recently-viewed',
        refresh: true,
      );
      if ((response.statusCode ?? 500) >= 400) return null;

      final dynamic payload = response.data;
      final dynamic rows = payload is Map ? payload['data'] : null;
      if (rows is! List) return null;
      return rows
          .whereType<Map>()
          .map(
            (row) => ProductDetailData.fromApi(
              Map<String, dynamic>.from(row),
            ),
          )
          .where((product) => product.id > 0)
          .take(50)
          .toList();
    } catch (_) {
      return null;
    }
  }

  static List<ProductDetailData> _merge(
    List<ProductDetailData> preferred,
    List<ProductDetailData> fallback,
  ) {
    final products = <ProductDetailData>[...preferred];
    final ids = products.map((product) => product.id).toSet();
    for (final product in fallback) {
      if (ids.add(product.id)) products.add(product);
    }
    return products.take(50).toList();
  }

  static Future<List<ProductDetailData>> _read(int buyerId) async {
    final value = await _storage.read(key: 'recently_viewed_$buyerId');
    if (value == null) return [];
    final decoded = jsonDecode(value);
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((row) => ProductDetailData.fromApi(Map<String, dynamic>.from(row)))
        .where((product) => product.id > 0)
        .take(50)
        .toList();
  }

  static Future<void> record(ProductDetailData product) async {
    if (product.id <= 0) return;
    try {
      final id = await _buyerId();
      final next = _queue.catchError((Object _) {}).then((_) async {
        final savedRemotely = await _recordRemoteView(product.id);
        if (savedRemotely) {
          await _markSynced(id, product.id);
        } else {
          await _markPending(id, product.id);
        }
        final products = await _read(id);
        await _save(
          id,
          [product, ...products.where((p) => p.id != product.id)].take(50),
        );
      });
      _queue = next.catchError((Object _) {});
      await next;
    } catch (_) {
      // History must never prevent a product from opening.
      _buyer = null;
    }
  }

  static Future<bool> _recordRemoteView(int productId) async {
    if (!AppConfig.apiEnabled) return false;
    try {
      final response = await ApiClient.post(
        'buyer/product-views',
        <String, int>{'product_id': productId},
      );
      return (response.statusCode ?? 500) < 400;
    } catch (_) {
      // Keep the local cache usable if the shared API is unavailable.
      return false;
    }
  }

  static Future<void> clear() async {
    final id = await _buyerId();
    final next = _queue.catchError((Object _) {}).then((_) async {
      if (AppConfig.apiEnabled) {
        final response = await ApiClient.delete('buyer/product-views', null);
        if ((response.statusCode ?? 500) >= 400) {
          throw StateError('Could not clear shared viewing history.');
        }
      }
      await _save(id, []);
      await _savePendingIds(id, <int>{});
      await _storage.write(key: '$_syncKeyPrefix$id', value: 'true');
    });
    _queue = next.catchError((Object _) {});
    await next;
  }

  static Future<void> _save(int id, Iterable<ProductDetailData> products) {
    return _storage.write(
      key: 'recently_viewed_$id',
      value: jsonEncode([
        for (final p in products)
          {
            'id': p.id,
            'name': p.name,
            'slug': p.slug,
            'price': p.price,
            'image_url': p.imageUrl,
            'stock': p.stock,
            'seller_name': p.sellerName,
            'seller_slug': p.sellerSlug,
            'seller_user_id': p.sellerUserId,
            'seller_avatar_url': p.sellerAvatarUrl,
            'seller_location': p.sellerLocation,
            'seller_rating': p.sellerRating,
            'seller_product_count': p.sellerProductCount,
            'seller_verified': p.sellerVerified,
          },
      ]),
    );
  }
}

import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/storage/token_storage.dart';
import '../features/buyer/products/product_details_screen.dart';
import 'auth_service.dart';

/// Device-local browsing history, isolated by signed-in buyer.
class RecentlyViewedService {
  static const _storage = FlutterSecureStorage();
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
      return await _read(id);
    } catch (_) {
      _buyer = null;
      rethrow;
    }
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

  static Future<void> clear() async {
    final id = await _buyerId();
    final next = _queue.catchError((Object _) {}).then((_) => _save(id, []));
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

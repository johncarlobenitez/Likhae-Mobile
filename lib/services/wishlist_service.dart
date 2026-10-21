import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/wishlist/wishlist_screen.dart';

class WishlistService {
  static final Map<int, WishlistProduct> _localWishlist =
      <int, WishlistProduct>{};

  static final ValueNotifier<Set<int>> productIds =
      ValueNotifier<Set<int>>(<int>{});

  static bool isWishlisted(int productId) => productIds.value.contains(productId);

  static void setProductWishlisted(int productId, bool wishlisted) {
    final Set<int> next = Set<int>.from(productIds.value);
    if (wishlisted) {
      next.add(productId);
    } else {
      next.remove(productId);
    }
    _publish(next);
  }

  static void replaceWithWishlist(Iterable<int> ids) {
    _publish(ids.where((int id) => id > 0).toSet());
  }

  static void recordKnownProducts(Iterable<({int id, bool wishlisted})> products) {
    final Set<int> next = Set<int>.from(productIds.value);
    for (final ({int id, bool wishlisted}) product in products) {
      if (product.id < 1) continue;
      if (product.wishlisted) next.add(product.id);
    }
    _publish(next);
  }

  static void _publish(Set<int> next) {
    if (!setEquals(productIds.value, next)) {
      productIds.value = Set<int>.unmodifiable(next);
    }
  }

  static Set<int> get localProductIds => _localWishlist.keys.toSet();

  static List<WishlistProduct> get localWishlist {
    return _localWishlist.values.toList().reversed.toList(growable: false);
  }

  static Future<void> toggleLocalProduct(WishlistProduct product) {
    if (_localWishlist.containsKey(product.id)) {
      _localWishlist.remove(product.id);
      setProductWishlisted(product.id, false);
    } else {
      _localWishlist[product.id] = product;
      setProductWishlisted(product.id, true);
    }

    return Future<void>.value();
  }

  static Future<List<WishlistProduct>> fetchLocalWishlist() {
    return Future<List<WishlistProduct>>.value(localWishlist);
  }

  static Future<void> removeLocalProduct(int productId) {
    _localWishlist.remove(productId);
    setProductWishlisted(productId, false);
    return Future<void>.value();
  }

  static Future<void> clearLocalWishlist() {
    _localWishlist.clear();
    replaceWithWishlist(const <int>[]);
    return Future<void>.value();
  }

  static Future<void> toggleProduct(int productId) async {
    final List<String> candidatePaths = <String>[
      'wishlist/toggle',
      'wishlists/toggle',
      'wishlist',
      'wishlists',
    ];

    Object? lastError;

    for (final String candidatePath in candidatePaths) {
      try {
        final Response<dynamic> response = await ApiClient.post(
          AppConfig.resolveApiUrl(candidatePath),
          <String, dynamic>{'product_id': productId},
        );

        if (response.statusCode != null &&
            response.statusCode! >= 200 &&
            response.statusCode! < 300) {
          return;
        }

        if (response.statusCode == 404) {
          lastError = const FormatException('Wishlist endpoint not found.');
          continue;
        }

        if (response.statusCode == 405) {
          lastError = const FormatException('Wishlist endpoint method is not allowed.');
          continue;
        }

        lastError = FormatException('Wishlist request failed: ${response.statusCode}');
      } on DioException catch (error) {
        if (error.response?.statusCode == 404) {
          lastError = error;
          continue;
        }

        if (error.response?.statusCode == 405) {
          lastError = error;
          continue;
        }

        lastError = error;
        break;
      }
    }

    if (lastError != null) {
      throw lastError;
    }

    throw const FormatException('Wishlist endpoint is not available on the backend.');
  }
}

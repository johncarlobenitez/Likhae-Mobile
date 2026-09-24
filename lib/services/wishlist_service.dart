import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';

class WishlistService {
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

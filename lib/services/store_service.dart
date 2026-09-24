import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/store/store_screen.dart';

class StoreService {
  static Future<StoreSellerData> fetchSeller(String sellerSlug) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('stores/$sellerSlug'),
    );

    final dynamic payload = response.data;
    final dynamic data = payload is Map ? (payload['data'] ?? payload['seller'] ?? payload) : null;

    if (data is! Map<String, dynamic>) {
      throw const FormatException('Seller data not found.');
    }

    return StoreSellerData.fromApi(data);
  }

  static Future<List<StoreProductData>> fetchSellerProducts(String sellerSlug) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('stores/$sellerSlug'),
    );

    final dynamic payload = response.data;
    final dynamic rawData = payload is Map ? (payload['data'] ?? payload['seller'] ?? payload) : null;
    if (rawData is! Map<String, dynamic>) {
      return <StoreProductData>[];
    }

    final dynamic rawProducts = rawData['products'] ?? rawData['items'] ?? rawData['data'] ?? <dynamic>[];
    if (rawProducts is! List) {
      return <StoreProductData>[];
    }

    return rawProducts
        .map((dynamic item) => StoreProductData.fromApi(item is Map ? Map<String, dynamic>.from(item) : <String, dynamic>{}))
        .whereType<StoreProductData>()
        .toList(growable: false);
  }
}

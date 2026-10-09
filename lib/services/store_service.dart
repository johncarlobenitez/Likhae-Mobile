import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/store/store_screen.dart';
import 'product_service.dart';

class StorePageData {
  final StoreSellerData seller;
  final List<StoreProductData> products;

  const StorePageData({required this.seller, required this.products});
}

class StoreService {
  static Future<StorePageData> fetchStore(String sellerSlug) async {
    final String normalizedSlug = sellerSlug.trim();
    if (normalizedSlug.isEmpty) {
      throw const FormatException('Seller store slug is required.');
    }

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('stores/${Uri.encodeComponent(normalizedSlug)}'),
    );

    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      final dynamic payload = response.data;
      final String message = payload is Map && payload['message'] != null
          ? payload['message'].toString()
          : 'Unable to load this store (HTTP $statusCode).';
      throw Exception(message);
    }

    final dynamic payload = response.data;
    final dynamic rawData = payload is Map
        ? (payload['data'] ?? payload['seller'] ?? payload)
        : null;
    if (rawData is! Map) {
      throw const FormatException('Seller store data not found.');
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(rawData);
    final Map<String, dynamic> sellerData = data['seller'] is Map
        ? Map<String, dynamic>.from(data['seller'] as Map)
        : data;
    final dynamic rawProducts = data['products'] ??
        data['items'] ??
        sellerData['products'] ??
        data['data'] ??
        const <dynamic>[];

    List<StoreProductData> products = rawProducts is List
        ? rawProducts
              .whereType<Map>()
              .map(
                (Map item) => StoreProductData.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .where((StoreProductData product) => product.id != 0)
              .toList(growable: false)
        : const <StoreProductData>[];

    // Some deployed API versions return the seller profile successfully but
    // omit the nested products list. Retry through the public products API,
    // scoped to the same seller profile, so the mobile store still works.
    final int? sellerProfileId = int.tryParse(
      (sellerData['id'] ?? '').toString(),
    );
    if (products.isEmpty && sellerProfileId != null && sellerProfileId > 0) {
      final List<Map<String, dynamic>> productRows =
          await ProductService.fetchProductRows(
            perPage: 100,
            sellerProfileId: sellerProfileId,
          );
      products = productRows
          .map(StoreProductData.fromApi)
          .where((StoreProductData product) => product.id != 0)
          .toList(growable: false);
    }

    final Map<String, dynamic> sellerDisplayData =
        Map<String, dynamic>.from(sellerData);
    if (sellerDisplayData['rating'] == null && products.isNotEmpty) {
      final List<double> ratings = products
          .map((StoreProductData product) => product.rating)
          .whereType<double>()
          .where((double rating) => rating > 0)
          .toList(growable: false);
      if (ratings.isNotEmpty) {
        sellerDisplayData['rating'] =
            ratings.reduce((double a, double b) => a + b) / ratings.length;
      }
    }

    return StorePageData(
      seller: StoreSellerData.fromApi(sellerDisplayData),
      products: products,
    );
  }

  static Future<StoreSellerData> fetchSeller(String sellerSlug) async {
    return (await fetchStore(sellerSlug)).seller;
  }

  static Future<List<StoreProductData>> fetchSellerProducts(String sellerSlug) async {
    return (await fetchStore(sellerSlug)).products;
  }
}

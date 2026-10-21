import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/storage/token_storage.dart';
import '../core/utils/api_value_parsers.dart';
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
      queryParameters: const <String, dynamic>{'per_page': 50, 'page': 1},
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

    final String? token = await TokenStorage.readToken();
    if (token != null && token.trim().isNotEmpty) {
      try {
        final Response<dynamic> followResponse = await ApiClient.get(
          AppConfig.resolveApiUrl(
            'buyer/stores/${Uri.encodeComponent(normalizedSlug)}/follow',
          ),
          refresh: true,
        );
        final int followStatus = followResponse.statusCode ?? 500;
        final dynamic followPayload = followResponse.data;
        final dynamic followData = followPayload is Map
            ? (followPayload['data'] ?? followPayload)
            : null;
        if (followStatus >= 200 &&
            followStatus < 300 &&
            followData is Map) {
          sellerData['is_following'] =
              followData['following'] ?? followData['is_following'];
          sellerData['followers'] =
              followData['followers'] ?? sellerData['followers'];
        }
      } catch (_) {
        // A missing/older follow endpoint must not prevent the public store
        // page from loading.
      }
    }

    final dynamic rawProducts = data['products'] ??
        data['items'] ??
        sellerData['products'] ??
        data['data'] ??
        const <dynamic>[];

    final List<dynamic> allRows = rawProducts is List ? List<dynamic>.from(rawProducts) : <dynamic>[];
    final dynamic rawMeta = payload is Map ? payload['meta'] : null;
    final int lastPage = rawMeta is Map ? int.tryParse((rawMeta['last_page'] ?? 1).toString()) ?? 1 : 1;
    for (int page = 2; page <= lastPage; page++) {
      final Response<dynamic> pageResponse = await ApiClient.get(
        AppConfig.resolveApiUrl('stores/${Uri.encodeComponent(normalizedSlug)}'),
        queryParameters: <String, dynamic>{'per_page': 50, 'page': page},
      );
      final int pageStatus = pageResponse.statusCode ?? 500;
      if (pageStatus < 200 || pageStatus >= 300) {
        throw Exception('Unable to load all store products (HTTP $pageStatus).');
      }
      final dynamic pagePayload = pageResponse.data;
      final dynamic pageData = pagePayload is Map ? pagePayload['data'] : null;
      final dynamic pageRows = pageData is Map ? pageData['products'] : null;
      if (pageRows is List) allRows.addAll(pageRows);
    }

    List<StoreProductData> products = allRows
        .whereType<Map>()
        .map((Map item) => StoreProductData.fromApi(Map<String, dynamic>.from(item)))
        .where((StoreProductData product) => product.id != 0)
        .toList(growable: false);

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

    return StorePageData(
      seller: StoreSellerData.fromApi(sellerData),
      products: products,
    );
  }

  static Future<StoreSellerData> fetchSeller(String sellerSlug) async {
    return (await fetchStore(sellerSlug)).seller;
  }

  static Future<StoreFollowResult> setStoreFollowing(
    String sellerSlug,
    bool following,
  ) async {
    final String normalizedSlug = sellerSlug.trim();
    if (normalizedSlug.isEmpty) {
      throw const FormatException('Seller store slug is required.');
    }
    if (!AppConfig.apiEnabled) {
      throw Exception('Shop following is unavailable while offline.');
    }

    final String? token = await TokenStorage.readToken();
    if (token == null || token.trim().isEmpty) {
      throw Exception('Sign in as a buyer to follow this shop.');
    }

    final String path = AppConfig.resolveApiUrl(
      'buyer/stores/${Uri.encodeComponent(normalizedSlug)}/follow',
    );
    late final Response<dynamic> response;
    try {
      response = following
          ? await ApiClient.post(path, const <String, dynamic>{})
          : await ApiClient.delete(path, const <String, dynamic>{});
    } on DioException catch (error) {
      throw Exception(ApiClient.formatError(error));
    }
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception(
        ApiClient.formatError(
          DioException(
            requestOptions: response.requestOptions,
            response: response,
            type: DioExceptionType.badResponse,
          ),
        ),
      );
    }

    final dynamic payload = response.data;
    final dynamic rawData = payload is Map
        ? (payload['data'] ?? payload)
        : null;
    final Map<String, dynamic> data = rawData is Map
        ? Map<String, dynamic>.from(rawData)
        : <String, dynamic>{};

    return StoreFollowResult(
      following: parseApiBool(
        data['following'] ?? data['is_following'],
        defaultValue: following,
      ),
      followers: int.tryParse(
        (data['followers'] ?? data['followers_count'] ?? '').toString(),
      ),
    );
  }

  static Future<List<StoreProductData>> fetchSellerProducts(String sellerSlug) async {
    return (await fetchStore(sellerSlug)).products;
  }
}

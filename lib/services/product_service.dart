import 'package:dio/dio.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../features/buyer/home/home_screen.dart';
import '../features/buyer/products/product_details_screen.dart';

class ProductService {
  static List<BuyerHomeProduct> _demoProducts() {
    final List<BuyerHomeProduct> products = <BuyerHomeProduct>[
      const BuyerHomeProduct(
        id: 1,
        name: 'Minimal Ceramic Vase',
        price: 799,
        originalPrice: 999,
        category: 'Home Decor',
        sellerName: 'Mira Studio',
        imageUrl:
            'https://images.unsplash.com/photo-1517705008128-361805f42e86?auto=format&fit=crop&w=900&q=80',
        rating: 4.8,
        soldCount: 182,
        stock: 8,
        isFeatured: true,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 2,
        name: 'Linen Everyday Tote',
        price: 1299,
        originalPrice: 1699,
        category: 'Fashion',
        sellerName: 'Northline Co.',
        imageUrl:
            'https://images.unsplash.com/photo-1542291026-7eec264c27ff?auto=format&fit=crop&w=900&q=80',
        rating: 4.7,
        soldCount: 248,
        stock: 12,
        isFeatured: true,
      ),
      const BuyerHomeProduct(
        id: 3,
        name: 'Wireless Noise Cancelling Headphones',
        price: 5399,
        originalPrice: 6299,
        category: 'Electronics',
        sellerName: 'Echo Labs',
        imageUrl:
            'https://images.unsplash.com/photo-1546435770-a3e426bf472b?auto=format&fit=crop&w=900&q=80',
        rating: 4.9,
        soldCount: 96,
        stock: 15,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 4,
        name: 'Leather Journal Set',
        price: 899,
        originalPrice: 1199,
        category: 'Office',
        sellerName: 'Paper & Pine',
        imageUrl:
            'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=crop&w=900&q=80',
        rating: 4.6,
        soldCount: 135,
        stock: 11,
        isFeatured: true,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 5,
        name: 'Forest Scent Candle Trio',
        price: 699,
        originalPrice: 899,
        category: 'Home',
        sellerName: 'Velvet Ember',
        imageUrl:
            'https://images.unsplash.com/photo-1503602642458-232111445657?auto=format&fit=crop&w=900&q=80',
        rating: 4.7,
        soldCount: 204,
        stock: 18,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 6,
        name: 'City Walk Running Shoes',
        price: 2499,
        originalPrice: 3299,
        category: 'Sports',
        sellerName: 'Stride Daily',
        imageUrl:
            'https://images.unsplash.com/photo-1543508282-6319a3e2621f?auto=format&fit=crop&w=900&q=80',
        rating: 4.8,
        soldCount: 312,
        stock: 20,
        isFeatured: true,
      ),
      const BuyerHomeProduct(
        id: 7,
        name: 'Stoneware Dinner Set',
        price: 1899,
        originalPrice: 2399,
        category: 'Kitchen',
        sellerName: 'Gather & Glow',
        imageUrl:
            'https://images.unsplash.com/photo-1495474472287-4d71bcdd2085?auto=format&fit=crop&w=900&q=80',
        rating: 4.6,
        soldCount: 143,
        stock: 9,
        isRecommended: true,
      ),
      const BuyerHomeProduct(
        id: 8,
        name: 'Soft Knit Throw Blanket',
        price: 1499,
        originalPrice: 1999,
        category: 'Home',
        sellerName: 'Harbor & Hearth',
        imageUrl:
            'https://images.unsplash.com/photo-1521572267360-ee0c2909d518?auto=format&fit=crop&w=900&q=80',
        rating: 4.9,
        soldCount: 271,
        stock: 14,
        isFeatured: true,
        isRecommended: true,
      ),
    ];

    products.shuffle();
    return products;
  }

  static Future<List<BuyerHomeProduct>> fetchHomeProducts({
    bool dealsOnly = false,
    String? sort,
    int perPage = 50,
  }) async {
    if (!AppConfig.apiEnabled) {
      final List<BuyerHomeProduct> products = _demoProducts();
      final List<BuyerHomeProduct> selected = dealsOnly
          ? products.where((BuyerHomeProduct item) => item.discountPercentage != null).toList()
          : products;
      if (sort == 'best-selling') {
        selected.sort((BuyerHomeProduct a, BuyerHomeProduct b) => b.soldCount.compareTo(a.soldCount));
      }
      return selected;
    }

    // Home renders a small selection; the catalog page owns full browsing.
    final List<Map<String, dynamic>> rows = await fetchProductRows(
      perPage: perPage, dealsOnly: dealsOnly, sort: sort, maxPages: 1,
    );

    return rows
        .map(BuyerHomeProduct.fromApi)
        .where((BuyerHomeProduct product) => product.id != 0)
        .toList(growable: false);
  }

  static Future<List<BuyerHomeCategory>> fetchCategories({bool refresh = false}) async {
    if (!AppConfig.apiEnabled) return const <BuyerHomeCategory>[];

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('categories'),
      cacheFor: const Duration(minutes: 2),
      refresh: refresh,
    );
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Unable to load categories (HTTP $statusCode).');
    }

    final dynamic payload = response.data;
    dynamic rawRows = payload is List
        ? payload
        : payload is Map
        ? payload['data'] ?? payload['categories']
        : null;
    if (rawRows is Map) {
      rawRows = rawRows['categories'] ?? rawRows['items'];
    }
    if (rawRows is! List) return const <BuyerHomeCategory>[];

    final List<Map<String, dynamic>> rows = rawRows
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
    final Map<String, int> childCounts = <String, int>{};
    for (final Map<String, dynamic> row in rows) {
      final dynamic parent = row['parent'];
      final dynamic parentId = row['parent_id'] ??
          (parent is Map ? parent['id'] : null);
      final String parentKey = parentId?.toString().trim() ?? '';
      if (parentKey.isEmpty) continue;
      final int count = int.tryParse(
            (row['products_count'] ?? row['product_count'] ?? 0).toString(),
          ) ??
          0;
      childCounts.update(
        parentKey,
        (int current) => current + count,
        ifAbsent: () => count,
      );
    }

    return rows.where((Map<String, dynamic> row) {
      final dynamic parent = row['parent'];
      final dynamic parentId = row['parent_id'] ??
          (parent is Map ? parent['id'] : null);
      return parentId == null || parentId.toString().trim().isEmpty;
    }).map((Map<String, dynamic> row) {
      final String name = (row['name'] ?? '').toString().trim();
      final String slug = (row['slug'] ?? '').toString().trim();
      final String id = (row['id'] ?? '').toString();
      final int directCount = int.tryParse(
            (row['products_count'] ?? row['product_count'] ?? 0).toString(),
          ) ??
          0;
      return BuyerHomeCategory(
        name: name,
        slug: slug,
        productCount: directCount + (childCounts[id] ?? 0),
      );
    }).where((BuyerHomeCategory category) =>
        category.name.isNotEmpty && category.slug.isNotEmpty).toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> fetchPlatformEvents() async {
    if (!AppConfig.apiEnabled) return const <Map<String, dynamic>>[];
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('events'),
    );
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Unable to load platform events (HTTP $statusCode).');
    }
    final dynamic rows = _extractRows(response.data);
    if (rows is! List) return const <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((Map row) => Map<String, dynamic>.from(row))
        .toList(growable: false);
  }

  static Future<List<Map<String, dynamic>>> fetchProductRows({
    int perPage = 100,
    int? sellerProfileId,
    bool dealsOnly = false,
    String? searchQuery,
    String? sort,
    int? maxPages,
  }) async {
    if (!AppConfig.apiEnabled) {
      return _demoProducts()
          .map(
            (BuyerHomeProduct product) => <String, dynamic>{
              'id': product.id,
              'name': product.name,
              'price': product.price,
              'original_price': product.originalPrice,
              'category': product.category,
              'seller_name': product.sellerName,
              'image_url': product.imageUrl,
              'rating': product.rating,
              'sold_count': product.soldCount,
              'stock': product.stock,
              'is_featured': product.isFeatured,
              'is_recommended': product.isRecommended,
              'wishlisted': product.wishlisted,
            },
          )
          .toList(growable: false);
    }

    final int pageSize = perPage.clamp(1, 50).toInt();
    final List<Map<String, dynamic>> products = <Map<String, dynamic>>[];
    final Set<String> seenIds = <String>{};
    int page = 1;
    int? lastPage;
    while (page <= (lastPage ?? 100) && (maxPages == null || page <= maxPages)) {
      final Response<dynamic> response = await ApiClient.get(
        AppConfig.resolveApiUrl('products'),
        queryParameters: <String, dynamic>{
          'per_page': pageSize,
          'page': page,
          if (dealsOnly) 'deals': true,
          if (searchQuery != null && searchQuery.trim().isNotEmpty)
            'q': searchQuery.trim(),
          if (sort != null && sort.trim().isNotEmpty) 'sort': sort,
          if (sellerProfileId != null) 'seller_profile_id': sellerProfileId,
        },
      );
      final int statusCode = response.statusCode ?? 500;
      if (statusCode < 200 || statusCode >= 300) {
        final dynamic payload = response.data;
        final String message = payload is Map && payload['message'] != null
            ? payload['message'].toString()
            : 'Unable to load products (HTTP $statusCode).';
        throw Exception(message);
      }

      final dynamic payload = response.data;
      final dynamic rows = _extractRows(payload);
      if (rows is! List) {
        if (page == 1) {
          throw const FormatException('Invalid products response from server.');
        }
        break;
      }

      int newCount = 0;
      for (final Map row in rows.whereType<Map>()) {
        final Map<String, dynamic> product = Map<String, dynamic>.from(row);
        final String id = (product['id'] ?? product['product_id'] ?? '').toString();
        if (id.isNotEmpty && !seenIds.add(id)) continue;
        products.add(product);
        newCount++;
      }

      lastPage ??= _extractLastPage(payload);
      if (lastPage != null && page >= lastPage!) break;
      if (rows.length < pageSize || newCount == 0) break;
      page++;
    }

    return products;
  }

  static Future<ProductDetailData> fetchProductDetails(String slug) async {
    final String normalizedSlug = slug.trim();
    if (normalizedSlug.isEmpty) {
      throw const FormatException('Product slug is required.');
    }

    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(
        'products/${Uri.encodeComponent(normalizedSlug)}',
      ),
    );
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      final dynamic payload = response.data;
      final String message = payload is Map && payload['message'] != null
          ? payload['message'].toString()
          : 'Unable to load product details (HTTP $statusCode).';
      throw Exception(message);
    }

    final dynamic payload = response.data;
    final dynamic product = payload is Map
        ? payload['data'] ?? payload['product'] ?? payload
        : null;
    if (product is! Map) {
      throw const FormatException('Invalid product details response.');
    }

    return ProductDetailData.fromApi(Map<String, dynamic>.from(product));
  }

  static dynamic _extractRows(dynamic payload) {
    if (payload is List) {
      return payload;
    }
    if (payload is! Map) {
      return null;
    }

    final dynamic data = payload['data'];
    if (data is List) {
      return data;
    }
    if (data is Map) {
      for (final String key in <String>['products', 'items', 'data']) {
        if (data[key] is List) {
          return data[key];
        }
      }
    }
    for (final String key in <String>['products', 'items']) {
      if (payload[key] is List) {
        return payload[key];
      }
    }
    return null;
  }

  static int? _extractLastPage(dynamic payload) {
    if (payload is! Map) return null;
    final dynamic meta = payload['meta'];
    final dynamic nestedData = payload['data'];
    final dynamic pagination = payload['pagination'];
    final dynamic nestedPagination =
        nestedData is Map ? nestedData['pagination'] : null;
    final dynamic nestedMeta = nestedData is Map ? nestedData['meta'] : null;
    final dynamic raw = payload['last_page'] ??
        (meta is Map ? meta['last_page'] : null) ??
        (pagination is Map ? pagination['last_page'] : null) ??
        (nestedData is Map ? nestedData['last_page'] : null) ??
        (nestedPagination is Map ? nestedPagination['last_page'] : null) ??
        (nestedMeta is Map ? nestedMeta['last_page'] : null);
    return int.tryParse(raw?.toString() ?? '');
  }
}

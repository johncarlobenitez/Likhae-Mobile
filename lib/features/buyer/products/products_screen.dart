import 'dart:async';

import '../../../shared/widgets/sized_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/utils/api_value_parsers.dart';
import 'package:likhae/services/product_service.dart';
import 'package:likhae/services/product_search_history_service.dart';
import 'package:likhae/services/wishlist_service.dart';
import 'package:likhae/shared/widgets/price_range_filter.dart';

typedef BuyerProductCallback = void Function(BuyerProduct product);

typedef BuyerProductWishlistCallback =
    Future<void> Function(BuyerProduct product);

typedef BuyerProductsRefreshCallback = Future<void> Function();

class BuyerProduct {
  final int id;

  final String name;
  final String? description;
  final String? slug;

  final String? category;
  final String? categorySlug;

  final String? sellerName;
  final String? sellerSlug;
  final int? sellerUserId;

  final String? imageUrl;

  final double price;
  final double? highestVariantPrice;
  final double? originalPrice;

  final double? rating;
  final int soldCount;

  /// Nullable because older marketplace payloads may not
  /// provide stock yet.
  ///
  /// null = stock not supplied to this page
  /// 0    = explicitly out of stock
  /// > 0  = available
  final int? stock;
  final String? sellerLocation;
  final bool isActive;
  final bool isDraft;
  final bool isDeleted;
  final bool sellerOnVacation;
  final DateTime? flashSaleStartsAt;
  final DateTime? flashSaleEndsAt;
  final bool flashSaleReminderAvailable;

  /// The actual wishlist state that should eventually come
  /// from Laravel.
  final bool wishlisted;

  const BuyerProduct({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.highestVariantPrice,
    this.slug,
    this.category,
    this.categorySlug,
    this.sellerName,
    this.sellerSlug,
    this.sellerUserId,
    this.imageUrl,
    this.originalPrice,
    this.rating,
    this.soldCount = 0,
    this.stock,
    this.sellerLocation,
    this.isActive = true,
    this.isDraft = false,
    this.isDeleted = false,
    this.sellerOnVacation = false,
    this.flashSaleStartsAt,
    this.flashSaleEndsAt,
    this.flashSaleReminderAvailable = false,
    this.wishlisted = false,
  });

  double? get discountPercentage {
    final double? original = originalPrice;

    if (original == null || original <= 0 || original <= price) {
      return null;
    }

    return ((original - price) / original) * 100;
  }

  bool get isOutOfStock {
    final int? available = stock;

    if (available == null) {
      return false;
    }

    return available < 1;
  }

  bool get isVisibleInCatalog => isActive && !isDraft && !isDeleted;

  bool get isFlashSaleUpcoming {
    final DateTime? startsAt = flashSaleStartsAt;
    final DateTime? endsAt = flashSaleEndsAt;
    final DateTime now = DateTime.now();
    return startsAt != null &&
        startsAt.isAfter(now) &&
        (endsAt == null || endsAt.isAfter(now));
  }

  bool get isFlashSaleExpired {
    final DateTime? endsAt = flashSaleEndsAt;
    return endsAt != null && !endsAt.isAfter(DateTime.now());
  }

  bool get isFlashSaleActive {
    final DateTime? startsAt = flashSaleStartsAt;
    return !isFlashSaleExpired &&
        (startsAt == null || !startsAt.isAfter(DateTime.now())) &&
        (startsAt != null || flashSaleEndsAt != null);
  }

  static BuyerProduct? fromApi(dynamic json) {
    if (json is! Map) {
      return null;
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(json);

    final dynamic rawId = data['id'] ?? data['product_id'];
    final dynamic rawName = data['name'] ?? data['product_name'];
    final dynamic rawPrice =
        data['price'] ?? data['amount'] ?? data['min_price'];
    final dynamic rawVariants = data['variants'] ?? data['variations'];
    final List<Map<String, dynamic>> variants = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((Map row) => Map<String, dynamic>.from(row))
              .where(
                (Map<String, dynamic> row) =>
                    double.tryParse(
                      (row['price'] ?? row['sale_price'] ?? '').toString(),
                    ) !=
                    null,
              )
              .toList()
        : <Map<String, dynamic>>[];
    Map<String, dynamic>? lowestVariant;
    for (final Map<String, dynamic> variant in variants) {
      final double price =
          double.tryParse(
            (variant['price'] ?? variant['sale_price']).toString(),
          ) ??
          double.infinity;
      final double lowestPrice = lowestVariant == null
          ? double.infinity
          : double.tryParse(
                  (lowestVariant['price'] ?? lowestVariant['sale_price'])
                      .toString(),
                ) ??
                double.infinity;
      if (price < lowestPrice) lowestVariant = variant;
    }
    double? highestAvailableVariantPrice;
    for (final Map<String, dynamic> variant in variants) {
      final bool isActive = parseApiBool(
        variant['is_active'],
        defaultValue: true,
      );
      final int? stock = int.tryParse(variant['stock']?.toString() ?? '');
      if (!isActive || (stock != null && stock < 1)) continue;
      final double? price = double.tryParse(
        (variant['price'] ?? variant['sale_price'])?.toString() ?? '',
      );
      if (price != null &&
          (highestAvailableVariantPrice == null ||
              price > highestAvailableVariantPrice)) {
        highestAvailableVariantPrice = price;
      }
    }

    if (rawId == null ||
        rawName == null ||
        (rawPrice == null && lowestVariant == null)) {
      return null;
    }

    final dynamic rawPrimaryImage = data['primary_image'];
    final Map<String, dynamic>? primaryImage = rawPrimaryImage is Map
        ? Map<String, dynamic>.from(rawPrimaryImage)
        : null;
    final dynamic rawCategory = data['category'];
    final Map<String, dynamic>? category = rawCategory is Map
        ? Map<String, dynamic>.from(rawCategory)
        : null;
    final dynamic rawSeller = data['seller'];
    final Map<String, dynamic>? seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : null;
    final String imageValue = _firstNonEmptyString(
      data['image'],
      data['image_url'],
      data['imageUrl'],
      data['photo'],
      data['thumbnail'],
      primaryImage?['url'] ?? primaryImage?['file_path'],
    );

    final String categoryValue = _firstNonEmptyString(
      category?['name'] ?? data['category'],
      data['category_name'],
      data['categoryName'],
    );

    final String sellerNameValue = _firstNonEmptyString(
      seller?['business_name'] ?? data['seller_name'],
      data['sellerName'],
      data['store_name'],
      data['storeName'],
    );
    final dynamic rawLocation =
        seller?['location'] ?? data['seller_location'] ?? data['location'];
    final String sellerLocationValue = rawLocation is Map
        ? <dynamic>[
                rawLocation['name'],
                rawLocation['city'],
                rawLocation['municipality'],
                rawLocation['province'],
              ]
              .where(
                (dynamic value) =>
                    value != null && value.toString().trim().isNotEmpty,
              )
              .map((dynamic value) => value.toString().trim())
              .toSet()
              .join(', ')
        : (rawLocation?.toString().trim() ?? '');

    final String slugValue = _firstNonEmptyString(
      data['slug'],
      data['product_slug'],
      data['slug_name'],
    );

    final double parsedPrice = (rawPrice is num)
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice.toString()) ?? 0;

    final dynamic rawOriginalPrice =
        data['original_price'] ??
        data['originalPrice'] ??
        data['old_price'] ??
        data['oldPrice'];
    final double? originalPrice = rawOriginalPrice is num
        ? rawOriginalPrice.toDouble()
        : double.tryParse(rawOriginalPrice?.toString() ?? '');

    final dynamic resolvedPrice =
        data['min_price'] ??
        lowestVariant?['price'] ??
        lowestVariant?['sale_price'] ??
        rawPrice;
    final double? resolvedPriceNumber = double.tryParse(
      resolvedPrice?.toString() ?? '',
    );
    Map<String, dynamic>? priceVariant = lowestVariant;
    if (resolvedPriceNumber != null) {
      for (final Map<String, dynamic> variant in variants) {
        final double? variantPrice = double.tryParse(
          (variant['price'] ?? variant['sale_price'])?.toString() ?? '',
        );
        if (variantPrice == resolvedPriceNumber) {
          priceVariant = variant;
          break;
        }
      }
    }
    final String status = (data['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final dynamic rawActive =
        data['is_active'] ??
        data['is_available'] ??
        data['active'] ??
        data['is_published'];
    final bool active = parseApiBool(
      rawActive,
      defaultValue: !<String>{
        'inactive',
        'unpublished',
        'draft',
        'deleted',
        'disabled',
      }.contains(status),
    );
    final bool draft =
        parseApiBool(data['is_draft'], defaultValue: false) ||
        status == 'draft';
    final bool deleted =
        parseApiBool(
          data['is_deleted'] ?? data['deleted'],
          defaultValue: false,
        ) ||
        data['deleted_at'] != null ||
        status == 'deleted';

    return BuyerProduct(
      id: int.tryParse(rawId.toString()) ?? 0,
      name: rawName.toString(),
      description: data['description']?.toString(),
      slug: slugValue.isNotEmpty ? slugValue : null,
      category: categoryValue.isNotEmpty ? categoryValue : null,
      categorySlug: (category?['slug'] ?? data['category_slug'])?.toString(),
      sellerName: sellerNameValue.isNotEmpty ? sellerNameValue : null,
      imageUrl: imageValue.isNotEmpty ? imageValue : null,
      price: double.tryParse(resolvedPrice.toString()) ?? parsedPrice,
      highestVariantPrice: highestAvailableVariantPrice,
      originalPrice: variants.isEmpty
          ? originalPrice
          : double.tryParse(
              (priceVariant?['old_price'] ??
                          priceVariant?['original_price'] ??
                          originalPrice)
                      ?.toString() ??
                  '',
            ),
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble()
          : double.tryParse(data['rating']?.toString() ?? ''),
      soldCount:
          int.tryParse(data['sold_count']?.toString() ?? '') ??
          int.tryParse(data['soldCount']?.toString() ?? '') ??
          int.tryParse(data['sold']?.toString() ?? '') ??
          0,
      stock: data['stock'] is num
          ? (data['stock'] as num).toInt()
          : int.tryParse(
              (data['stock'] ?? data['quantity'] ?? data['variant_stock'])
                      ?.toString() ??
                  '',
            ),
      sellerLocation: sellerLocationValue.isEmpty ? null : sellerLocationValue,
      isActive: active,
      isDraft: draft,
      isDeleted: deleted,
      sellerOnVacation: parseApiBool(
        seller?['is_on_vacation'] ??
            seller?['is_vacation_mode'] ??
            seller?['vacation_mode'] ??
            data['seller_on_vacation'],
        defaultValue: false,
      ),
      flashSaleStartsAt: DateTime.tryParse(
        (data['flash_sale_starts_at'] ?? '').toString(),
      ),
      flashSaleEndsAt: DateTime.tryParse(
        (data['flash_sale_ends_at'] ?? '').toString(),
      ),
      flashSaleReminderAvailable: parseApiBool(
        data['flash_sale_reminder_available'],
        defaultValue: false,
      ),
      sellerSlug:
          seller?['slug']?.toString() ?? data['seller_slug']?.toString(),
      sellerUserId: int.tryParse(
        (seller?['user_id'] ?? data['seller_user_id'] ?? '').toString(),
      ),
      wishlisted: data['wishlisted'] == true || data['wishlist'] == true,
    );
  }

  static String _firstNonEmptyString(
    dynamic first, [
    dynamic second,
    dynamic third,
    dynamic fourth,
    dynamic fifth,
    dynamic sixth,
  ]) {
    final List<dynamic> values = <dynamic>[
      first,
      second,
      third,
      fourth,
      fifth,
      sixth,
    ];

    for (final value in values) {
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString().trim();
      }
    }

    return '';
  }

  BuyerProduct copyWith({
    String? name,
    String? description,
    String? slug,
    String? category,
    String? categorySlug,
    String? sellerName,
    String? sellerSlug,
    String? imageUrl,
    double? price,
    double? highestVariantPrice,
    double? originalPrice,
    double? rating,
    int? soldCount,
    int? stock,
    bool? wishlisted,
  }) {
    return BuyerProduct(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      categorySlug: categorySlug ?? this.categorySlug,
      sellerName: sellerName ?? this.sellerName,
      sellerSlug: sellerSlug ?? this.sellerSlug,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      highestVariantPrice: highestVariantPrice ?? this.highestVariantPrice,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      soldCount: soldCount ?? this.soldCount,
      stock: stock ?? this.stock,
      sellerLocation: sellerLocation,
      isActive: isActive,
      isDraft: isDraft,
      isDeleted: isDeleted,
      sellerOnVacation: sellerOnVacation,
      flashSaleStartsAt: flashSaleStartsAt,
      flashSaleEndsAt: flashSaleEndsAt,
      flashSaleReminderAvailable: flashSaleReminderAvailable,
      wishlisted: wishlisted ?? this.wishlisted,
    );
  }
}

enum BuyerProductSort { recommended, latest, sold, priceHigh, priceLow }

extension BuyerProductSortInfo on BuyerProductSort {
  String get label {
    switch (this) {
      case BuyerProductSort.recommended:
        return 'Relevance';

      case BuyerProductSort.latest:
        return 'Latest';

      case BuyerProductSort.sold:
        return 'Top Sales';

      case BuyerProductSort.priceLow:
        return 'Sort by Price: Low to High';

      case BuyerProductSort.priceHigh:
        return 'Sort by Price: High to Low';
    }
  }

  String get badgeLabel {
    switch (this) {
      case BuyerProductSort.recommended:
        return 'RELEVANCE';

      case BuyerProductSort.latest:
        return 'LATEST';

      case BuyerProductSort.sold:
        return 'TOP SALES';

      case BuyerProductSort.priceLow:
        return 'LOWEST PRICE';

      case BuyerProductSort.priceHigh:
        return 'HIGHEST PRICE';
    }
  }
}

class ProductsScreen extends StatefulWidget {
  final List<BuyerProduct> products;

  final BuyerProductCallback? onProductSelected;
  final BuyerProductCallback? onSellerSelected;

  /// This callback should eventually call Laravel's
  /// wishlist toggle endpoint.
  ///
  /// The local heart changes only after this Future
  /// completes successfully.
  final BuyerProductWishlistCallback? onWishlistProduct;

  final BuyerProductsRefreshCallback? onRefresh;

  final VoidCallback? onBack;
  final VoidCallback? onCart;
  final VoidCallback? onNotifications;

  final String initialSearchQuery;
  final BuyerProductSort initialSort;
  final String? initialCategorySlug;
  final bool dealsOnly;
  final bool searchOnOpen;

  const ProductsScreen({
    super.key,
    this.products = const [],
    this.onProductSelected,
    this.onSellerSelected,
    this.onWishlistProduct,
    this.onRefresh,
    this.onBack,
    this.onCart,
    this.onNotifications,
    this.initialSearchQuery = '',
    this.initialSort = BuyerProductSort.recommended,
    this.initialCategorySlug,
    this.dealsOnly = false,
    this.searchOnOpen = false,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _muted = ShopColors.muted;

  static const Color _mutedLight = ShopColors.faint;

  static const Color _tan = ShopColors.tan;

  static const Color _danger = Color(0xFFB42318);

  late final TextEditingController _searchController;
  late final FocusNode _searchFocusNode;

  late List<BuyerProduct> _products;
  List<BuyerProduct>? _remoteSearchProducts;
  List<ProductSearchSuggestion> _remoteTextSuggestions =
      <ProductSearchSuggestion>[];
  List<ProductSearchRecord> _recentSearches = <ProductSearchRecord>[];
  Timer? _searchDebounce;
  Timer? _suggestionDebounce;
  int _searchRequestVersion = 0;
  int _suggestionRequestVersion = 0;
  late bool _showSearchExperience;

  bool _isLoading = false;
  bool _isRemoteSearchLoading = false;
  bool _isRemoteSuggestionLoading = false;
  bool _remoteSuggestionFailed = false;
  String? _errorMessage;

  late String _searchQuery;
  late bool _searchSubmitted;

  late BuyerProductSort _sort;
  String? _categorySlug;
  String? _location;
  double? _minimumRating;
  double? _minimumPrice;
  double? _maximumPrice;
  int _pageIndex = 0;
  static const int _pageSize = 20;

  final Set<int> _wishlistLoading = <int>{};

  @override
  void initState() {
    super.initState();

    _products = List<BuyerProduct>.from(widget.products);

    _searchQuery = widget.initialSearchQuery;
    _searchSubmitted = _searchQuery.trim().isNotEmpty;
    _isRemoteSearchLoading =
        AppConfig.apiEnabled && _searchQuery.trim().isNotEmpty;
    _showSearchExperience = widget.searchOnOpen;

    _sort = widget.initialSort;
    _categorySlug = widget.initialCategorySlug;

    _searchController = TextEditingController(text: _searchQuery);
    _searchFocusNode = FocusNode()..addListener(_onSearchFocusChanged);
    unawaited(_loadSearchHistory());
    WishlistService.recordKnownProducts(
      _products.map(
        (BuyerProduct product) =>
            (id: product.id, wishlisted: product.wishlisted),
      ),
    );

    if (_products.isEmpty) {
      _loadProducts();
    }
    if (_searchQuery.trim().isNotEmpty) {
      _scheduleRemoteSearch(_searchQuery.trim());
      _scheduleRemoteSuggestions(_searchQuery.trim());
    }
    WishlistService.productIds.addListener(_onWishlistChanged);
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchFocusChanged() {
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _remoteSearchProducts = null;
      _isRemoteSearchLoading = AppConfig.apiEnabled && value.trim().isNotEmpty;
      if (value.trim().isEmpty) _searchSubmitted = false;
      _pageIndex = 0;
    });
    _scheduleRemoteSearch(value.trim());
    _scheduleRemoteSuggestions(value.trim());
  }

  void _scheduleRemoteSuggestions(String query) {
    _suggestionDebounce?.cancel();
    final int requestVersion = ++_suggestionRequestVersion;
    if (!AppConfig.apiEnabled || query.length < 2) {
      setState(() {
        _remoteTextSuggestions = <ProductSearchSuggestion>[];
        _isRemoteSuggestionLoading = false;
        _remoteSuggestionFailed = false;
      });
      return;
    }

    setState(() {
      _remoteTextSuggestions = <ProductSearchSuggestion>[];
      _isRemoteSuggestionLoading = true;
      _remoteSuggestionFailed = false;
    });
    _suggestionDebounce = Timer(const Duration(milliseconds: 1100), () {
      unawaited(_loadRemoteSuggestions(query, requestVersion));
    });
  }

  Future<void> _loadRemoteSuggestions(String query, int requestVersion) async {
    try {
      final List<ProductSearchSuggestion> suggestions =
          await ProductService.fetchSearchSuggestions(query);
      if (!mounted ||
          requestVersion != _suggestionRequestVersion ||
          query != _searchQuery.trim()) {
        return;
      }
      setState(() {
        _remoteTextSuggestions = suggestions;
        _isRemoteSuggestionLoading = false;
        _remoteSuggestionFailed = false;
      });
    } catch (_) {
      if (!mounted || requestVersion != _suggestionRequestVersion) return;
      setState(() {
        _remoteTextSuggestions = <ProductSearchSuggestion>[];
        _isRemoteSuggestionLoading = false;
        _remoteSuggestionFailed = true;
      });
    }
  }

  void _selectRemoteSuggestion(ProductSearchSuggestion suggestion) {
    final String query = suggestion.query.trim();
    if (query.isEmpty) return;
    _searchController.text = query;
    _onSearchChanged(query);
    _submitSearch(query);
  }

  void _scheduleRemoteSearch(String query, {bool immediately = false}) {
    _searchDebounce?.cancel();
    final int requestVersion = ++_searchRequestVersion;
    if (!AppConfig.apiEnabled || query.isEmpty) return;

    Future<void> search() async {
      try {
        final List<Map<String, dynamic>> rows =
            await ProductService.fetchProductRows(
              dealsOnly: widget.dealsOnly,
              searchQuery: query,
            );
        final List<BuyerProduct> results = rows
            .map(BuyerProduct.fromApi)
            .whereType<BuyerProduct>()
            .where(
              (BuyerProduct product) =>
                  product.id != 0 && product.isVisibleInCatalog,
            )
            .toList(growable: false);
        if (!mounted ||
            requestVersion != _searchRequestVersion ||
            query != _searchQuery.trim()) {
          return;
        }
        WishlistService.recordKnownProducts(
          results.map(
            (BuyerProduct product) =>
                (id: product.id, wishlisted: product.wishlisted),
          ),
        );
        setState(() {
          _remoteSearchProducts = results;
          _isRemoteSearchLoading = false;
          _pageIndex = 0;
        });
      } catch (_) {
        // Local matching remains available if the catalog search request fails.
        if (mounted && requestVersion == _searchRequestVersion) {
          setState(() => _isRemoteSearchLoading = false);
        }
      }
    }

    if (immediately) {
      unawaited(search());
    } else {
      _searchDebounce = Timer(
        const Duration(milliseconds: 350),
        () => unawaited(search()),
      );
    }
  }

  Future<void> _loadSearchHistory() async {
    final List<ProductSearchRecord> records =
        await ProductSearchHistoryService.read();
    if (!mounted) return;
    setState(() => _recentSearches = records);
  }

  Future<void> _recordSearch(String query, {int? productId}) async {
    final List<ProductSearchRecord> records =
        await ProductSearchHistoryService.record(query, productId: productId);
    if (!mounted) return;
    setState(() => _recentSearches = records);
  }

  Future<void> _clearSearchHistory() async {
    await ProductSearchHistoryService.clear();
    if (!mounted) return;
    setState(() => _recentSearches = <ProductSearchRecord>[]);
  }

  BuyerProduct? _productForSearch(ProductSearchRecord search) {
    if (search.productId != null) {
      for (final BuyerProduct product in _products) {
        if (product.id == search.productId && product.isVisibleInCatalog) {
          return product;
        }
      }
    }

    final String query = search.query.trim().toLowerCase();
    if (query.isEmpty) return null;
    for (final BuyerProduct product in _products) {
      if (!product.isVisibleInCatalog) continue;
      final String searchableText = <String>[
        product.name,
        product.category ?? '',
        product.sellerName ?? '',
      ].join(' ').toLowerCase();
      if (searchableText.contains(query)) return product;
    }
    return null;
  }

  List<BuyerProduct> get _recentlySearchedProducts {
    final Set<int> seenIds = <int>{};
    final List<BuyerProduct> products = <BuyerProduct>[];
    for (final ProductSearchRecord search in _recentSearches) {
      final BuyerProduct? product = _productForSearch(search);
      if (product != null && seenIds.add(product.id)) products.add(product);
    }
    return products;
  }

  List<BuyerProduct> get _suggestedFromSearchHistory {
    final List<BuyerProduct> recentProducts = _recentlySearchedProducts;
    final Set<int> recentIds = recentProducts
        .map((BuyerProduct product) => product.id)
        .toSet();
    final Set<String> categories = recentProducts
        .map(
          (BuyerProduct product) =>
              product.category?.trim().toLowerCase() ?? '',
        )
        .where((String category) => category.isNotEmpty)
        .toSet();
    final Set<String> words = <String>{
      ..._recentSearches
          .expand(
            (ProductSearchRecord search) =>
                search.query.toLowerCase().split(RegExp(r'[^a-z0-9]+')),
          )
          .where((String word) => word.length >= 3)
          .toSet(),
      ..._searchQuery
          .toLowerCase()
          .split(RegExp(r'[^a-z0-9]+'))
          .where((String word) => word.length >= 3),
    };
    if (categories.isEmpty && words.isEmpty) return <BuyerProduct>[];

    final List<MapEntry<BuyerProduct, int>> ranked =
        <MapEntry<BuyerProduct, int>>[];
    for (final BuyerProduct product in _products) {
      if (!product.isVisibleInCatalog ||
          product.isOutOfStock ||
          product.sellerOnVacation ||
          recentIds.contains(product.id)) {
        continue;
      }
      int score = 0;
      final String category = product.category?.trim().toLowerCase() ?? '';
      if (categories.contains(category)) score += 4;
      final String searchableText = <String>[
        product.name,
        product.category ?? '',
        product.sellerName ?? '',
      ].join(' ').toLowerCase();
      for (final String word in words) {
        if (searchableText.contains(word)) score++;
      }
      if (score > 0) ranked.add(MapEntry<BuyerProduct, int>(product, score));
    }
    ranked.sort((
      MapEntry<BuyerProduct, int> first,
      MapEntry<BuyerProduct, int> second,
    ) {
      final int relevance = second.value.compareTo(first.value);
      if (relevance != 0) return relevance;
      final int rating = (second.key.rating ?? 0).compareTo(
        first.key.rating ?? 0,
      );
      if (rating != 0) return rating;
      return second.key.soldCount.compareTo(first.key.soldCount);
    });
    return ranked
        .take(8)
        .map((MapEntry<BuyerProduct, int> row) => row.key)
        .toList();
  }

  List<BuyerProduct> get _searchSuggestionProducts {
    final List<BuyerProduct> suggestions = <BuyerProduct>[];
    final Set<int> seenIds = <int>{};
    final String query = _searchQuery.trim();

    void add(Iterable<BuyerProduct> products) {
      for (final BuyerProduct product in products) {
        if (product.isVisibleInCatalog && seenIds.add(product.id)) {
          suggestions.add(product);
        }
      }
    }

    if (query.isNotEmpty) add(_filteredProducts);
    add(_suggestedFromSearchHistory);
    if (suggestions.isEmpty) {
      add(
        _products.where(
          (BuyerProduct product) =>
              !widget.dealsOnly ||
              product.discountPercentage != null ||
              product.isFlashSaleUpcoming,
        ),
      );
    }
    return suggestions.take(12).toList(growable: false);
  }

  void _submitSearch(String query) {
    final String trimmedQuery = query.trim();
    if (trimmedQuery.isEmpty) return;
    setState(() => _searchSubmitted = true);
    _scheduleRemoteSearch(trimmedQuery, immediately: true);
    final List<BuyerProduct> matchingProducts = _filteredProducts;
    unawaited(
      _recordSearch(
        trimmedQuery,
        productId: matchingProducts.isEmpty ? null : matchingProducts.first.id,
      ),
    );
    _searchFocusNode.unfocus();
  }

  void _openProduct(BuyerProduct product, {String? searchQuery}) {
    final String query = (searchQuery ?? _searchQuery).trim();
    if (query.isNotEmpty) {
      unawaited(_recordSearch(query, productId: product.id));
    }
    _searchFocusNode.unfocus();
    widget.onProductSelected?.call(product);
  }

  Future<void> _loadProducts() async {
    if (_isLoading) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final List<Map<String, dynamic>> rows =
          await ProductService.fetchProductRows(dealsOnly: widget.dealsOnly);
      final List<BuyerProduct> loadedProducts = rows
          .map(BuyerProduct.fromApi)
          .whereType<BuyerProduct>()
          .where(
            (BuyerProduct product) =>
                product.id != 0 && product.isVisibleInCatalog,
          )
          .toList(growable: false);

      WishlistService.recordKnownProducts(
        loadedProducts.map(
          (BuyerProduct product) =>
              (id: product.id, wishlisted: product.wishlisted),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _products = loadedProducts;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.products != widget.products) {
      _products = List<BuyerProduct>.from(widget.products);
      WishlistService.recordKnownProducts(
        _products.map(
          (BuyerProduct product) =>
              (id: product.id, wishlisted: product.wishlisted),
        ),
      );
      _pageIndex = 0;
    }

    if (oldWidget.initialSearchQuery != widget.initialSearchQuery) {
      _searchQuery = widget.initialSearchQuery;
      _searchSubmitted = _searchQuery.trim().isNotEmpty;
      _isRemoteSearchLoading =
          AppConfig.apiEnabled && _searchQuery.trim().isNotEmpty;
      _searchController.text = _searchQuery;
      _remoteSearchProducts = null;
      _scheduleRemoteSearch(_searchQuery.trim());
      _scheduleRemoteSuggestions(_searchQuery.trim());
    }

    if (oldWidget.initialSort != widget.initialSort) {
      _sort = widget.initialSort;
    }
    if (oldWidget.initialCategorySlug != widget.initialCategorySlug) {
      _categorySlug = widget.initialCategorySlug;
      _pageIndex = 0;
    }
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _suggestionDebounce?.cancel();
    _searchRequestVersion++;
    _suggestionRequestVersion++;
    _searchController.dispose();
    _searchFocusNode.removeListener(_onSearchFocusChanged);
    _searchFocusNode.dispose();
    WishlistService.productIds.removeListener(_onWishlistChanged);

    super.dispose();
  }

  Object? _filterKey;
  List<BuyerProduct> _filterResult = [];

  List<BuyerProduct> get _filteredProducts {
    final List<BuyerProduct> sourceProducts =
        _remoteSearchProducts ?? _products;
    final bool hasRemoteSearchResults = _remoteSearchProducts != null;
    final key = (
      sourceProducts,
      _searchQuery,
      _sort,
      _minimumPrice,
      _maximumPrice,
      _minimumRating,
      _categorySlug,
      _location,
      widget.dealsOnly,
    );
    if (_filterKey == key) return _filterResult;

    List<BuyerProduct> result = sourceProducts.where((BuyerProduct product) {
      if (!product.isVisibleInCatalog) return false;
      final String query = _searchQuery.trim().toLowerCase();

      if (query.isEmpty || hasRemoteSearchResults) {
        return true;
      }

      final String searchableText = <String>[
        product.name,
        product.description ?? '',
        product.category ?? '',
        product.sellerName ?? '',
      ].join(' ').toLowerCase();

      final bool matched = searchableText.contains(query);
      if (!matched) return false;
      return true;
    }).toList();

    final List<double> prices = _products
        .where((BuyerProduct product) => product.isVisibleInCatalog)
        .map((BuyerProduct product) => product.price)
        .toList(growable: false);
    final double minimum = prices.isEmpty
        ? 0
        : prices.reduce((a, b) => a < b ? a : b);
    final double maximum = prices.isEmpty
        ? 100000
        : prices.reduce((a, b) => a > b ? a : b);
    final String? categoryFilter = _categorySlug?.trim();
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      result = result.where((BuyerProduct product) {
        final String categoryName = product.category?.trim() ?? '';
        final String fallbackSlug = categoryName
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-|-$'), '');
        return product.categorySlug == categoryFilter ||
            (product.categorySlug?.toLowerCase().startsWith(
                  '${categoryFilter.toLowerCase()}-',
                ) ??
                false) ||
            fallbackSlug == categoryFilter.toLowerCase() ||
            categoryName.toLowerCase() == categoryFilter.toLowerCase();
      }).toList();
    }
    if (widget.dealsOnly) {
      result = result
          .where(
            (BuyerProduct product) =>
                (product.discountPercentage != null ||
                    product.isFlashSaleUpcoming) &&
                !product.isFlashSaleExpired &&
                !product.isOutOfStock &&
                !product.sellerOnVacation,
          )
          .toList();
    }
    final double lower = _minimumPrice ?? minimum;
    final double upper = _maximumPrice ?? maximum;
    result = result
        .where(
          (BuyerProduct product) =>
              product.price >= lower && product.price <= upper,
        )
        .toList();
    if (_minimumRating != null) {
      result = result
          .where(
            (BuyerProduct product) => (product.rating ?? 0) >= _minimumRating!,
          )
          .toList();
    }
    if (_location != null && _location!.isNotEmpty) {
      result = result
          .where((BuyerProduct product) => product.sellerLocation == _location)
          .toList();
    }

    switch (_sort) {
      case BuyerProductSort.recommended:
        final String query = _searchQuery.trim().toLowerCase();
        if (query.isEmpty) break;
        final Map<int, int> originalPositions = <int, int>{
          for (int index = 0; index < result.length; index++)
            result[index].id: index,
        };
        result.sort((BuyerProduct a, BuyerProduct b) {
          final int scoreDifference =
              _relevanceScore(b, query) - _relevanceScore(a, query);
          if (scoreDifference != 0) return scoreDifference;
          return originalPositions[a.id]!.compareTo(originalPositions[b.id]!);
        });
        break;

      case BuyerProductSort.latest:
        // Laravel returns its catalog newest first. The local demo catalog has
        // no creation timestamp, so use its sequential IDs as a fallback.
        if (!AppConfig.apiEnabled) {
          result.sort((BuyerProduct a, BuyerProduct b) => b.id.compareTo(a.id));
        }
        break;

      case BuyerProductSort.sold:
        result.sort(
          (BuyerProduct a, BuyerProduct b) =>
              b.soldCount.compareTo(a.soldCount),
        );
        break;

      case BuyerProductSort.priceLow:
        result.sort(
          (BuyerProduct a, BuyerProduct b) => a.price.compareTo(b.price),
        );
        break;

      case BuyerProductSort.priceHigh:
        result.sort(
          (BuyerProduct a, BuyerProduct b) => (b.highestVariantPrice ?? b.price)
              .compareTo(a.highestVariantPrice ?? a.price),
        );
        break;
    }

    _filterKey = key;
    return _filterResult = result;
  }

  String? get _searchSuggestion {
    final String query = _searchQuery.trim();
    if (query.isEmpty || _filteredProducts.isNotEmpty) return null;

    return closestProductSuggestion(
      query,
      _products
          .where((BuyerProduct product) => product.isVisibleInCatalog)
          .map((BuyerProduct product) => product.name),
    );
  }

  int _relevanceScore(BuyerProduct product, String query) {
    final String name = product.name.toLowerCase();
    final String category = product.category?.toLowerCase() ?? '';
    final String seller = product.sellerName?.toLowerCase() ?? '';
    if (name == query) return 100;
    if (name.startsWith(query)) return 80;
    if (name.contains(query)) return 60;
    if (category.startsWith(query)) return 40;
    if (category.contains(query)) return 30;
    if (seller.startsWith(query)) return 20;
    if (seller.contains(query)) return 10;
    if (product.description?.toLowerCase().contains(query) == true) return 5;
    return 0;
  }

  double get _priceMinimum {
    final List<double> prices = _products
        .where((BuyerProduct product) => product.isVisibleInCatalog)
        .map((BuyerProduct product) => product.price)
        .toList(growable: false);
    return prices.isEmpty
        ? 0
        : prices.reduce((double a, double b) => a < b ? a : b);
  }

  double get _priceMaximum {
    final List<double> prices = _products
        .where((BuyerProduct product) => product.isVisibleInCatalog)
        .map((BuyerProduct product) => product.price)
        .toList(growable: false);
    return prices.isEmpty
        ? 100000
        : prices.reduce((double a, double b) => a > b ? a : b);
  }

  List<BuyerProduct> get _pageProducts {
    final List<BuyerProduct> all = _filteredProducts;
    final int start = (_pageIndex * _pageSize).clamp(0, all.length).toInt();
    final int end = (start + _pageSize).clamp(0, all.length).toInt();
    return all.sublist(start, end);
  }

  Future<void> _toggleWishlist(BuyerProduct product) async {
    if (_wishlistLoading.contains(product.id)) {
      return;
    }

    final BuyerProductWishlistCallback? callback = widget.onWishlistProduct;

    if (callback == null) {
      _showMessage('Wishlist will be connected to Laravel later.');

      return;
    }

    setState(() {
      _wishlistLoading.add(product.id);
    });

    try {
      final bool wasWishlisted = WishlistService.isWishlisted(product.id);
      await callback(product);

      if (!mounted) {
        return;
      }

      final int index = _products.indexWhere(
        (BuyerProduct current) => current.id == product.id,
      );

      if (index < 0) {
        return;
      }

      bool newState = WishlistService.isWishlisted(product.id);
      if (newState == wasWishlisted) {
        newState = !wasWishlisted;
        WishlistService.setProductWishlisted(product.id, newState);
      }

      _showMessage(
        newState
            ? 'Product saved to your wishlist.'
            : 'Product removed from your wishlist.',
      );
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _wishlistLoading.remove(product.id);
        });
      }
    }
  }

  Future<void> _refreshProducts() async {
    try {
      await _loadProducts();
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _showSortSheet() async {
    final BuyerProductSort? selected =
        await showModalBottomSheet<BuyerProductSort>(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (BuildContext context) {
            return SafeArea(
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                decoration: const BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: _border,
                        borderRadius: BorderRadius.circular(100),
                      ),
                    ),

                    const SizedBox(height: 18),

                    const Row(
                      children: [
                        Text(
                          'Sort products',
                          style: TextStyle(
                            color: _text,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    for (final BuyerProductSort sort in BuyerProductSort.values)
                      _SortOption(sort: sort, currentValue: _sort),
                  ],
                ),
              ),
            );
          },
        );

    if (selected == null) {
      return;
    }

    setState(() {
      _sort = selected;
      _pageIndex = 0;
    });
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  void _showMessage(String message, {bool error = false}) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: error ? _danger : _maroonDark,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          content: Text(
            message,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final List<BuyerProduct> allProducts = _filteredProducts;
    final List<BuyerProduct> products = _pageProducts;
    final bool inSearchExperience =
        _showSearchExperience || _searchFocusNode.hasFocus;
    final bool showSearchSuggestions = inSearchExperience && !_searchSubmitted;

    if (_isLoading &&
        products.isEmpty &&
        !_showSearchExperience &&
        !_searchFocusNode.hasFocus) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              const Expanded(
                child: Center(child: CircularProgressIndicator(color: _maroon)),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Column(
          children: [
            if (!_showSearchExperience && !_searchFocusNode.hasFocus)
              _buildHeader(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refreshProducts,
                child: CustomScrollView(
                  key: const PageStorageKey<String>('buyer-products-scroll'),
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _buildSearchArea()),

                    if (showSearchSuggestions) ...[
                      if (_recentSearches.isNotEmpty)
                        SliverToBoxAdapter(child: _buildSearchHistory()),
                      SliverToBoxAdapter(child: _buildSearchSuggestions()),
                    ] else ...[
                      SliverToBoxAdapter(
                        child: _buildCatalogHeader(allProducts.length),
                      ),

                      if (_isRemoteSearchLoading && allProducts.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: CircularProgressIndicator(color: _maroon),
                          ),
                        )
                      else if (_errorMessage != null && products.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  size: 52,
                                  color: _maroon,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Could not load products',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: _text,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: _muted),
                                ),
                              ],
                            ),
                          ),
                        )
                      else if (allProducts.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _buildEmptyState(),
                        )
                      else ...[
                        _buildProductGrid(products),
                        if (allProducts.length > _pageSize)
                          SliverToBoxAdapter(
                            child: _buildPagination(allProducts.length),
                          ),
                      ],
                    ],

                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return ShopPageHeader(
      title: widget.dealsOnly ? 'Shop Deals' : 'Discover',
      subtitle: widget.dealsOnly
          ? 'Browse genuine discounts from local sellers.'
          : 'Good things, made closer to home.',
      onBack: widget.onBack ?? () => Navigator.of(context).maybePop(),
    );
  }

  Widget _buildSearchArea() {
    if (_showSearchExperience || _searchFocusNode.hasFocus) {
      return _buildFocusedSearchBar();
    }

    final String? suggestion = _searchSuggestion;
    final Map<String, String> categories = <String, String>{};
    final Set<String> locations = <String>{};
    for (final BuyerProduct product in _products) {
      final String categoryKey = product.categorySlug?.trim().isNotEmpty == true
          ? product.categorySlug!.trim()
          : product.category?.trim() ?? '';
      if (categoryKey.isNotEmpty)
        categories[categoryKey] = product.category ?? categoryKey;
      final String location = product.sellerLocation?.trim() ?? '';
      if (location.isNotEmpty) locations.add(location);
    }
    final List<MapEntry<String, String>> categoryEntries =
        categories.entries.toList()..sort(
          (MapEntry<String, String> a, MapEntry<String, String> b) =>
              a.value.toLowerCase().compareTo(b.value.toLowerCase()),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: _submitSearch,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Search products, shops...',
                    hintStyle: const TextStyle(
                      color: _mutedLight,
                      fontSize: 12,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: _muted,
                      size: 21,
                    ),
                    suffixIcon: _searchQuery.trim().isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear',
                            onPressed: _clearSearch,
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _muted,
                              size: 18,
                            ),
                          ),
                    filled: true,
                    fillColor: _surface,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: const BorderSide(color: _maroon, width: 1.3),
                    ),
                  ),
                ),
              ),

              const SizedBox(width: 9),

              Material(
                color: _surface,
                borderRadius: BorderRadius.circular(15),
                child: InkWell(
                  onTap: _showSortSheet,
                  borderRadius: BorderRadius.circular(15),
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      border: Border.all(color: _border),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.swap_vert_rounded,
                      color: _maroon,
                      size: 23,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (suggestion != null) ...[
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () {
                  _searchController.text = suggestion;
                  _searchController.selection = TextSelection.collapsed(
                    offset: suggestion.length,
                  );
                  _onSearchChanged(suggestion);
                  setState(() => _searchSubmitted = true);
                  _scheduleRemoteSearch(suggestion, immediately: true);
                  unawaited(_recordSearch(suggestion));
                  _searchFocusNode.unfocus();
                },
                icon: const Icon(Icons.auto_awesome, size: 15),
                label: Text('Did you mean "$suggestion"?'),
                style: TextButton.styleFrom(
                  foregroundColor: _maroon,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 8),
          Material(
            color: _surface,
            borderRadius: BorderRadius.circular(15),
            child: ExpansionTile(
              key: const PageStorageKey<String>('buyer-products-filters'),
              tilePadding: const EdgeInsets.symmetric(horizontal: 14),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              leading: const Icon(
                Icons.filter_list_rounded,
                color: _maroon,
                size: 20,
              ),
              title: const Text(
                'Filters',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                '${_filteredProducts.length} matching products',
                style: const TextStyle(fontSize: 11, color: _muted),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Category',
                    style: TextStyle(
                      color: _text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 7),
                SizedBox(
                  height: 44,
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List<Widget>.generate(
                        categoryEntries.length + 1,
                        (int index) {
                          final bool allCategories = index == 0;
                          final MapEntry<String, String>? entry = allCategories
                              ? null
                              : categoryEntries[index - 1];
                          final String? slug = entry?.key;
                          final bool selected = allCategories
                              ? _categorySlug == null
                              : _categorySlug == slug;
                          final String label = allCategories
                              ? 'All'
                              : entry!.value;

                          return Padding(
                            padding: const EdgeInsets.only(right: 7),
                            child: Semantics(
                              button: true,
                              selected: selected,
                              label: label,
                              child: Material(
                                color: selected ? _maroon : _surface,
                                borderRadius: BorderRadius.circular(100),
                                child: InkWell(
                                  onTap: () => setState(() {
                                    _categorySlug = slug;
                                    _pageIndex = 0;
                                  }),
                                  borderRadius: BorderRadius.circular(100),
                                  child: Container(
                                    constraints: const BoxConstraints(
                                      minHeight: 44,
                                    ),
                                    alignment: Alignment.center,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(100),
                                      border: Border.all(
                                        color: selected ? _maroon : _border,
                                      ),
                                    ),
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        color: selected ? Colors.white : _text,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                PriceRangeFilter(
                  minimum: _priceMinimum,
                  maximum: _priceMaximum,
                  selectedMinimum: _minimumPrice ?? _priceMinimum,
                  selectedMaximum: _maximumPrice ?? _priceMaximum,
                  onChanged: (RangeValues range) => setState(() {
                    _minimumPrice = range.start;
                    _maximumPrice = range.end;
                    _pageIndex = 0;
                  }),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue:
                      _location != null && locations.contains(_location)
                      ? _location
                      : 'any',
                  decoration: const InputDecoration(
                    labelText: 'Seller location',
                    isDense: true,
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem(
                      value: 'any',
                      child: Text('Any location'),
                    ),
                    ...locations.map(
                      (String value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    ),
                  ],
                  onChanged: (String? value) => setState(() {
                    _location = value == 'any' ? null : value;
                    _pageIndex = 0;
                  }),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _minimumRating?.toString() ?? 'any',
                  decoration: const InputDecoration(
                    labelText: 'Minimum rating',
                    isDense: true,
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem(value: 'any', child: Text('Any rating')),
                    DropdownMenuItem(value: '3', child: Text('3 stars and up')),
                    DropdownMenuItem(value: '4', child: Text('4 stars and up')),
                    DropdownMenuItem(value: '5', child: Text('5 stars')),
                  ],
                  onChanged: (String? value) => setState(() {
                    _minimumRating = value == null || value == 'any'
                        ? null
                        : double.tryParse(value);
                    _pageIndex = 0;
                  }),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _categorySlug = widget.initialCategorySlug;
                      _location = null;
                      _minimumRating = null;
                      _minimumPrice = null;
                      _maximumPrice = null;
                      _pageIndex = 0;
                    }),
                    child: const Text('Reset filters'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchHistory() {
    final double maxQueryWidth = (MediaQuery.sizeOf(context).width - 200)
        .clamp(120, 190)
        .toDouble();
    final List<Widget> chips = _recentSearches
        .map<Widget>((ProductSearchRecord search) {
          final BuyerProduct? product = _productForSearch(search);
          return Material(
            color: ShopColors.soft,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => _selectRecentSearch(search),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(13, 8, 10, 8),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: maxQueryWidth),
                      child: Text(
                        search.query,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    if (product?.imageUrl?.isNotEmpty == true) ...[
                      const SizedBox(width: 7),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: SizedBox(
                          width: 25,
                          height: 25,
                          child: SizedNetworkImage(
                            url: AppConfig.resolveMediaUrl(product!.imageUrl!),
                            fit: BoxFit.contain,
                            iconSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        })
        .toList(growable: true);
    chips.add(
      Tooltip(
        message: 'Clear recent searches',
        child: Material(
          color: ShopColors.soft,
          shape: const CircleBorder(),
          child: IconButton(
            onPressed: _clearSearchHistory,
            icon: const Icon(Icons.delete_outline_rounded),
            color: _muted,
            iconSize: 20,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
          ),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
      child: Wrap(spacing: 9, runSpacing: 12, children: chips),
    );
  }

  Widget _buildFocusedSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: _leaveSearchExperience,
            icon: const Icon(Icons.arrow_back_rounded),
            color: _maroon,
            iconSize: 23,
            constraints: const BoxConstraints.tightFor(width: 38, height: 52),
            padding: EdgeInsets.zero,
          ),
          const SizedBox(width: 5),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              textInputAction: TextInputAction.search,
              onSubmitted: _submitSearch,
              onChanged: _onSearchChanged,
              style: const TextStyle(color: _text, fontSize: 14),
              cursorColor: _maroon,
              decoration: InputDecoration(
                hintText: 'Search products, shops...',
                hintStyle: const TextStyle(color: _mutedLight, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: _muted,
                  size: 21,
                ),
                suffixIcon: _searchQuery.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded, size: 18),
                        color: _muted,
                      ),
                filled: true,
                fillColor: _surface,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 17,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _maroon.withValues(alpha: .65)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: BorderSide(color: _maroon.withValues(alpha: .65)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(18),
                  borderSide: const BorderSide(color: _maroon, width: 1.3),
                ),
              ),
            ),
          ),
          const SizedBox(width: 7),
          IconButton(
            tooltip: 'Sort results',
            onPressed: _showSortSheet,
            icon: const Icon(Icons.swap_vert_rounded),
            color: _maroon,
            iconSize: 25,
            constraints: const BoxConstraints.tightFor(width: 42, height: 50),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _leaveSearchExperience() {
    if (_showSearchExperience) {
      if (widget.onBack != null) {
        widget.onBack!();
      } else {
        Navigator.of(context).maybePop();
      }
      return;
    }
    _searchFocusNode.unfocus();
  }

  Widget _buildSearchSuggestions() {
    final List<BuyerProduct> products = _searchSuggestionProducts;
    final List<ProductSearchSuggestion> textSuggestions =
        _remoteTextSuggestions;
    final bool hasRecentSearches = _recentSearches.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const ColoredBox(color: ShopColors.soft, child: SizedBox(height: 7)),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
          child: const Text(
            'Search Suggestions',
            style: TextStyle(
              color: _text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        if (_searchQuery.trim().length >= 2 &&
            (_isRemoteSuggestionLoading ||
                textSuggestions.isNotEmpty ||
                _remoteSuggestionFailed))
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (textSuggestions.isNotEmpty) ...[
                  for (final ProductSearchSuggestion suggestion
                      in textSuggestions)
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                      leading: Icon(
                        switch (suggestion.type.toLowerCase()) {
                          'category' => Icons.category_outlined,
                          'local seller' ||
                          'seller' => Icons.storefront_outlined,
                          _ => Icons.search_rounded,
                        },
                        color: _maroon,
                        size: 20,
                      ),
                      title: Text(
                        suggestion.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: suggestion.type.isEmpty
                          ? null
                          : Text(suggestion.type),
                      trailing: const Icon(Icons.north_west_rounded, size: 16),
                      onTap: () => _selectRemoteSuggestion(suggestion),
                    ),
                ] else if (_isRemoteSuggestionLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(minHeight: 2),
                  )
                else if (_remoteSuggestionFailed)
                  const Text(
                    'Live suggestions are unavailable. You can still search.',
                    style: TextStyle(color: _muted, fontSize: 12),
                  ),
              ],
            ),
          ),
        if (products.isEmpty && _isLoading)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 28, 20, 40),
            child: Center(child: CircularProgressIndicator(color: _maroon)),
          )
        else if (products.isEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Text(
              _errorMessage != null
                  ? 'Search suggestions could not be loaded. Pull down to try again.'
                  : hasRecentSearches
                  ? 'No product suggestions yet. Try a different search.'
                  : 'Products you search for will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 13),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: products.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 11,
                mainAxisSpacing: 11,
                childAspectRatio: .88,
              ),
              itemBuilder: (BuildContext context, int index) =>
                  _SearchSuggestionCard(
                    product: products[index],
                    onTap: () => _openProduct(products[index]),
                  ),
            ),
          ),
      ],
    );
  }

  void _selectRecentSearch(ProductSearchRecord search) {
    _searchController.text = search.query;
    _searchController.selection = TextSelection.collapsed(
      offset: search.query.length,
    );
    _onSearchChanged(search.query);
    setState(() => _searchSubmitted = true);
    _scheduleRemoteSearch(search.query, immediately: true);
    _searchFocusNode.unfocus();
  }

  Widget _buildCatalogHeader(int count) {
    final String query = _searchQuery.trim();
    final bool searching = query.isNotEmpty;
    final String resultCount = count == 1 ? '1 product' : '$count products';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  searching
                      ? 'Search Results'
                      : widget.dealsOnly
                      ? 'Shop Deals'
                      : 'Explore Products',
                  style: TextStyle(
                    color: _text,
                    fontSize: 24,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.6,
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  searching
                      ? '$resultCount matching “$query”'
                      : '$resultCount found',
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: ShopColors.accentSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: Text(
              _sort.badgeLabel,
              style: const TextStyle(
                color: _maroon,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<BuyerProduct> products) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 18),
      sliver: SliverLayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.crossAxisExtent;
          final columns = width >= 1000
              ? 4
              : width >= 700
              ? 3
              : width < 290 || MediaQuery.textScalerOf(context).scale(14) > 24
              ? 1
              : 2;
          return SliverList(
            delegate: SliverChildBuilderDelegate((context, row) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (int column = 0; column < columns; column++) ...[
                      if (column > 0) const SizedBox(width: 12),
                      Expanded(
                        child: row * columns + column >= products.length
                            ? const SizedBox.shrink()
                            : _ProductCard(
                                product: products[row * columns + column],
                                wishlistLoading: _wishlistLoading.contains(
                                  products[row * columns + column].id,
                                ),
                                onWishlist: () => _toggleWishlist(
                                  products[row * columns + column],
                                ),
                                onTap: () => _openProduct(
                                  products[row * columns + column],
                                ),
                                onSellerTap: widget.onSellerSelected == null
                                    ? null
                                    : () => widget.onSellerSelected!(
                                        products[row * columns + column],
                                      ),
                              ),
                      ),
                    ],
                  ],
                ),
              );
            }, childCount: (products.length / columns).ceil()),
          );
        },
      ),
    );
  }

  Widget _buildPagination(int itemCount) {
    final int pageCount = (itemCount / _pageSize).ceil();
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pageIndex == 0
                ? null
                : () => setState(() => _pageIndex--),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'Page ${_pageIndex + 1} of $pageCount',
              style: const TextStyle(color: _muted, fontSize: 11),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pageIndex >= pageCount - 1
                ? null
                : () => setState(() => _pageIndex++),
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final bool searching = _searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: ShopColors.accentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(
                searching
                    ? Icons.search_off_rounded
                    : Icons.shopping_bag_outlined,
                color: _maroon,
                size: 30,
              ),
            ),

            const SizedBox(height: 18),

            Text(
              searching ? 'No matching products' : 'No products available yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: _text,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            Text(
              searching
                  ? 'Try another product name, category, or seller.'
                  : 'Products from approved sellers will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _muted, fontSize: 11, height: 1.45),
            ),

            if (searching) ...[
              const SizedBox(height: 18),

              OutlinedButton(
                onPressed: _clearSearch,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _tan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: const Text(
                  'Clear Search',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final BuyerProduct product;
  final bool wishlistLoading;
  final VoidCallback onWishlist;
  final VoidCallback onTap;
  final VoidCallback? onSellerTap;

  const _ProductCard({
    required this.product,
    required this.wishlistLoading,
    required this.onWishlist,
    required this.onTap,
    required this.onSellerTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool saleEnded = product.isFlashSaleExpired;
    return ShopProductCard(
      image: _ProductImage(imageUrl: product.imageUrl),
      name: product.name,
      category: product.category,
      seller: product.sellerName,
      price: saleEnded
          ? product.originalPrice ?? product.price
          : product.price,
      originalPrice: saleEnded ? null : product.originalPrice,
      priceLabel: saleEnded && product.originalPrice == null
          ? 'Refresh for price'
          : null,
      rating: product.rating,
      soldCount: product.soldCount,
      outOfStock:
          product.isOutOfStock || product.sellerOnVacation || saleEnded,
      availabilityLabel: product.sellerOnVacation
          ? 'Seller on vacation'
          : product.isOutOfStock
          ? 'Out of stock'
          : saleEnded
          ? 'Flash sale ended; refresh price'
          : product.isFlashSaleUpcoming
          ? _upcomingLabel(product.flashSaleStartsAt, context)
          : product.isFlashSaleActive
          ? _endingLabel(product.flashSaleEndsAt, context)
          : null,
      wishlisted: WishlistService.isWishlisted(product.id),
      wishlistLoading: wishlistLoading,
      onTap: onTap,
      onSellerTap: onSellerTap,
      onWishlist: onWishlist,
    );
  }

  String _upcomingLabel(DateTime? startsAt, BuildContext context) {
    if (startsAt == null) return 'Flash sale coming soon';
    final DateTime local = startsAt.toLocal();
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Sale starts ${months[local.month - 1]} ${local.day} at ${TimeOfDay.fromDateTime(local).format(context)}';
  }

  String _endingLabel(DateTime? endsAt, BuildContext context) {
    if (endsAt == null) return 'Flash sale active';
    final DateTime local = endsAt.toLocal();
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return 'Sale ends ${months[local.month - 1]} ${local.day} at ${TimeOfDay.fromDateTime(local).format(context)}';
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;
  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final value = imageUrl?.trim() ?? '';
    if (value.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: ShopColors.faint,
          size: 36,
        ),
      );
    }
    return SizedNetworkImage(
      url: AppConfig.resolveMediaUrl(value),
      fit: BoxFit.cover,
      iconSize: 36,
    );
  }
}

class _SearchSuggestionCard extends StatelessWidget {
  const _SearchSuggestionCard({required this.product, required this.onTap});

  final BuyerProduct product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: ShopColors.surface,
    borderRadius: BorderRadius.circular(14),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          border: Border.all(color: ShopColors.border),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox.expand(
                  child: product.imageUrl?.isNotEmpty == true
                      ? SizedNetworkImage(
                          url: AppConfig.resolveMediaUrl(product.imageUrl!),
                          fit: BoxFit.contain,
                          iconSize: 38,
                        )
                      : const Center(
                          child: Icon(
                            Icons.inventory_2_outlined,
                            color: ShopColors.faint,
                            size: 38,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 38,
              child: Center(
                child: Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: ShopColors.text,
                    fontSize: 14,
                    height: 1.15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _SortOption extends StatelessWidget {
  final BuyerProductSort sort;

  final BuyerProductSort currentValue;

  const _SortOption({required this.sort, required this.currentValue});

  @override
  Widget build(BuildContext context) {
    final bool selected = sort == currentValue;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () {
        Navigator.of(context).pop(sort);
      },
      title: Text(
        sort.label,
        style: TextStyle(
          color: ShopColors.text,
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: ShopColors.accent)
          : null,
    );
  }
}

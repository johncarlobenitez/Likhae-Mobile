import '../../../shared/widgets/sized_network_image.dart';
import 'dart:async';
import '../../../core/api/api_client.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:likhae/core/theme/app_theme.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/utils/api_value_parsers.dart';
import 'package:likhae/services/product_service.dart';
import 'package:likhae/services/buyer_mobile_service.dart';
import 'package:likhae/services/wishlist_service.dart';
import 'package:likhae/shared/widgets/buyer_navigation.dart';

typedef BuyerHomeProductCallback = void Function(BuyerHomeProduct product);
typedef BuyerHomeWishlistCallback =
    Future<void> Function(BuyerHomeProduct product);
typedef BuyerHomeCategoryCallback = void Function(String categorySlug);
typedef BuyerHomeRefreshCallback = Future<void> Function();

class BuyerHomeProduct {
  final int id;
  final String name;
  final String? slug;
  final String? category;
  final String? categorySlug;
  final String? sellerName;
  final String? sellerSlug;
  final int? sellerUserId;
  final String? imageUrl;
  final List<String> imageUrls;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int soldCount;
  final int? stock;
  final bool isActive;
  final bool isDraft;
  final bool isDeleted;
  final bool sellerOnVacation;
  final bool isFeatured;
  final bool isRecommended;
  final bool wishlisted;

  const BuyerHomeProduct({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.categorySlug,
    this.sellerName,
    this.sellerSlug,
    this.sellerUserId,
    this.imageUrl,
    this.imageUrls = const <String>[],
    this.originalPrice,
    this.rating,
    this.soldCount = 0,
    this.stock,
    this.isActive = true,
    this.isDraft = false,
    this.isDeleted = false,
    this.sellerOnVacation = false,
    this.isFeatured = false,
    this.isRecommended = false,
    this.wishlisted = false,
  });

  double? get discountPercentage {
    final double? original = originalPrice;
    if (original == null || original <= 0 || original <= price) return null;
    return ((original - price) / original) * 100;
  }

  bool get isOutOfStock {
    final int? available = stock;
    if (available == null) return false;
    return available < 1;
  }

  bool get isVisibleInCatalog =>
      isActive && !isDraft && !isDeleted && !isOutOfStock;

  static BuyerHomeProduct fromApi(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['db_id'];
    final dynamic rawName = json['name'];
    final dynamic rawDealVariant = json['deal_variant'];
    final Map<String, dynamic>? dealVariant = rawDealVariant is Map
        ? Map<String, dynamic>.from(rawDealVariant)
        : null;
    final dynamic rawPrice =
        json['price'] ?? json['min_price'] ?? dealVariant?['price'];
    final dynamic rawVariants = json['variants'] ?? json['variations'];
    final bool hasPricedVariant = rawVariants is List &&
        rawVariants.any((dynamic row) =>
            row is Map &&
            double.tryParse((row['price'] ?? row['sale_price'] ?? '').toString()) != null);
    if (rawId == null || rawName == null || (rawPrice == null && !hasPricedVariant)) {
      return const BuyerHomeProduct(id: 0, name: 'Unknown product', price: 0);
    }

    final dynamic rawImage = json['primary_image'];
    final Map<String, dynamic>? primaryImage = rawImage is Map
        ? Map<String, dynamic>.from(rawImage)
        : null;
    final dynamic rawSeller = json['seller'];
    final Map<String, dynamic>? seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : null;
    final dynamic rawCategory = json['category'];
    final Map<String, dynamic>? category = rawCategory is Map
        ? Map<String, dynamic>.from(rawCategory)
        : null;
    final List<Map<String, dynamic>> variants = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((Map row) => Map<String, dynamic>.from(row))
              .where((Map<String, dynamic> row) =>
                  double.tryParse((row['price'] ?? row['sale_price'] ?? '').toString()) != null)
              .toList()
        : <Map<String, dynamic>>[];
    Map<String, dynamic>? lowestVariant;
    for (final Map<String, dynamic> variant in variants) {
      final double price = double.tryParse(
            (variant['price'] ?? variant['sale_price']).toString(),
          ) ??
          double.infinity;
      final double lowestPrice = lowestVariant == null
          ? double.infinity
          : double.tryParse((lowestVariant['price'] ?? lowestVariant['sale_price']).toString()) ?? double.infinity;
      if (price < lowestPrice) lowestVariant = variant;
    }
    final dynamic resolvedPrice = dealVariant?['price'] ?? json['min_price'] ??
        (lowestVariant == null ? rawPrice : lowestVariant['price'] ?? lowestVariant['sale_price']);
    final double? resolvedPriceNumber = double.tryParse(resolvedPrice?.toString() ?? '');
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
    final dynamic rawOriginal = dealVariant?['original_price'] ?? (variants.isEmpty
        ? json['old_price'] ?? json['original_price']
        : priceVariant?['old_price'] ?? priceVariant?['original_price']);
    final String productStatus = (json['status'] ?? '').toString().trim().toLowerCase();
    final dynamic rawActive = json['is_active'] ?? json['is_available'] ?? json['active'] ?? json['is_published'];
    final bool active = parseApiBool(
      rawActive,
      defaultValue: !<String>{'inactive', 'unpublished', 'draft', 'deleted', 'disabled'}.contains(productStatus),
    );
    final bool draft = parseApiBool(json['is_draft'], defaultValue: false) || productStatus == 'draft';
    final bool deleted = parseApiBool(json['is_deleted'] ?? json['deleted'], defaultValue: false) ||
        json['deleted_at'] != null || productStatus == 'deleted';
    final dynamic rawStock = dealVariant?['stock'] ??
        json['stock'] ?? json['quantity'] ?? json['variant_stock'];
    final String imageValue = (json['image_url'] ??
            json['image'] ??
            primaryImage?['url'] ??
            primaryImage?['file_path'] ??
            '')
        .toString()
        .trim();
    final List<String> dealVariantImages =
        _parseImageUrls(dealVariant?['image_urls']);
    final List<String> galleryImages = dealVariantImages.isNotEmpty
        ? dealVariantImages
        : _parseImageUrls(json['images'] ?? json['gallery'] ?? json['photos']);
    final List<String> resolvedImages = <String>[];
    for (final String value in <String>[
      ...dealVariantImages,
      imageValue,
      ...galleryImages,
    ]) {
      final String resolved = AppConfig.resolveMediaUrl(value);
      if (resolved.isNotEmpty && !resolvedImages.contains(resolved)) {
        resolvedImages.add(resolved);
      }
    }
    final String sellerValue =
        (seller?['business_name'] ??
                json['seller_name'] ??
                (rawSeller is String ? rawSeller : ''))
            .toString();

    return BuyerHomeProduct(
      id: int.tryParse(rawId.toString()) ?? 0,
      name: rawName.toString(),
      slug: (json['slug'] ?? '').toString(),
      category:
          (category?['name'] ?? json['parent_category'] ?? json['category'] ?? '')
              .toString(),
      categorySlug: (category?['slug'] ?? json['category_slug'] ?? '')
          .toString()
          .trim(),
      sellerName: sellerValue.isEmpty ? null : sellerValue,
      sellerSlug: (seller?['slug'] ?? seller?['store_slug'] ?? seller?['id'] ?? '').toString(),
      sellerUserId: int.tryParse(
        (seller?['user_id'] ?? json['seller_user_id'] ?? '').toString(),
      ),
      imageUrl: resolvedImages.isEmpty
          ? null
          : resolvedImages.first,
      imageUrls: resolvedImages,
      price: double.tryParse(resolvedPrice.toString()) ?? 0,
      originalPrice: double.tryParse(rawOriginal?.toString() ?? ''),
      rating: double.tryParse((json['rating'] ?? '0').toString()),
      soldCount:
          int.tryParse(
            (json['sold'] ?? json['sold_count'] ?? '0').toString(),
          ) ??
          0,
      stock: rawStock == null ? null : int.tryParse(rawStock.toString()),
      isActive: active,
      isDraft: draft,
      isDeleted: deleted,
      sellerOnVacation: parseApiBool(
        seller?['is_on_vacation'] ?? seller?['is_vacation_mode'] ?? seller?['vacation_mode'] ?? json['seller_on_vacation'],
        defaultValue: false,
      ),
      isFeatured: json['is_featured'] == true,
      isRecommended: json['is_recommended'] == true,
      wishlisted: json['wishlisted'] == true,
    );
  }

  static List<String> _parseImageUrls(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    final List<String> urls = <String>[];
    for (final dynamic item in value) {
      String raw = '';
      if (item is Map) {
        final Map<String, dynamic> image = Map<String, dynamic>.from(item);
        raw = (image['url'] ??
                image['image_url'] ??
                image['image'] ??
                image['file_path'] ??
                image['path'] ??
                '')
            .toString();
      } else if (item != null) {
        raw = item.toString();
      }

      final String clean = raw.trim();
      if (clean.isNotEmpty && !urls.contains(clean)) {
        urls.add(clean);
      }
    }
    return urls;
  }

  List<String> get galleryImages {
    final List<String> images = <String>[];
    for (final String image in <String>[?imageUrl, ...imageUrls]) {
      final String clean = image.trim();
      if (clean.isNotEmpty && !images.contains(clean)) {
        images.add(clean);
      }
    }
    return images;
  }
}
class BuyerHomeCategory {
  final String name;
  final String slug;
  final IconData? icon;
  final String? description;
  final int? productCount;

  const BuyerHomeCategory({
    required this.name,
    required this.slug,
    this.icon,
    this.description,
    this.productCount,
  });
}

class BuyerHomeScreen extends StatefulWidget {
  final List<BuyerHomeProduct> products;
  final List<BuyerHomeProduct> featuredProducts;
  final List<BuyerHomeProduct> recommendedProducts;
  final BuyerHomeProduct? heroProduct;
  final List<BuyerHomeCategory> categories;
  final VoidCallback? onSearch;
  final VoidCallback? onCart;
  final VoidCallback? onNotifications;
  final VoidCallback? onBrowseProducts;
  final VoidCallback? onViewOrders;
  final VoidCallback? onWishlist;
  final VoidCallback? onFollowingShops;
  final VoidCallback? onMessages;
  final VoidCallback? onProfile;
  final VoidCallback? onVouchers;
  final VoidCallback? onViewAllCategories;
  final BuyerHomeCategoryCallback? onCategorySelected;
  final VoidCallback? onViewFeatured;
  final VoidCallback? onShopDeals;
  final VoidCallback? onViewRecommended;
  final BuyerHomeProductCallback? onProductSelected;
  final BuyerHomeWishlistCallback? onWishlistProductAsync;
  final BuyerHomeProductCallback? onWishlistProduct;
  final BuyerHomeRefreshCallback? onRefresh;
  final int cartItemCount;
  final int unreadNotificationCount;

  const BuyerHomeScreen({
    super.key,
    this.products = const [],
    this.featuredProducts = const [],
    this.recommendedProducts = const [],
    this.heroProduct,
    this.categories = const [],
    this.onSearch,
    this.onCart,
    this.onNotifications,
    this.onBrowseProducts,
    this.onViewOrders,
    this.onWishlist,
    this.onFollowingShops,
    this.onMessages,
    this.onProfile,
    this.onVouchers,
    this.onViewAllCategories,
    this.onCategorySelected,
    this.onViewFeatured,
    this.onShopDeals,
    this.onViewRecommended,
    this.onProductSelected,
    this.onWishlistProductAsync,
    this.onWishlistProduct,
    this.onRefresh,
    this.cartItemCount = 0,
    this.unreadNotificationCount = 0,
  });

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen>
    with WidgetsBindingObserver {
  static const List<BuyerHomeCategory> _featuredCategories =
      <BuyerHomeCategory>[
        BuyerHomeCategory(
          name: 'Fashion',
          slug: 'womens-apparel',
          icon: Icons.checkroom_rounded,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Electronics',
          slug: 'electronics-and-gadgets',
          icon: Icons.devices_rounded,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Home',
          slug: 'home-and-garden',
          icon: Icons.home_outlined,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Books',
          slug: 'books-and-media',
          icon: Icons.menu_book_rounded,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Beauty',
          slug: 'health-and-beauty',
          icon: Icons.spa_outlined,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Sports',
          slug: 'sports-and-outdoors',
          icon: Icons.sports_outlined,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Toys',
          slug: 'kids-and-baby-toys',
          icon: Icons.child_care_outlined,
          description: 'Explore',
        ),
        BuyerHomeCategory(
          name: 'Handmade Goods',
          slug: 'handmade-goods',
          icon: Icons.handyman_rounded,
          description: 'Explore',
        ),
      ];

  static Color get background => AppTheme.adaptive(ShopColors.canvas);
  static Color get backgroundSoft => AppTheme.adaptive(ShopColors.accentSoft);
  static Color get card => AppTheme.adaptive(ShopColors.surface);
  static Color get border => AppTheme.adaptive(ShopColors.border);
  static Color get maroon => AppTheme.adaptive(ShopColors.accent);
  static Color get maroonLight => AppTheme.adaptive(ShopColors.accentLight);
  static Color get text => AppTheme.adaptive(ShopColors.text);
  static Color get brown => AppTheme.adaptive(ShopColors.secondaryText);
  static Color get muted => AppTheme.adaptive(ShopColors.muted);
  static Color get muted2 => AppTheme.adaptive(ShopColors.faint);
  static Color get tan => AppTheme.adaptive(ShopColors.tan);
  static Color get star => AppTheme.adaptive(const Color(0xFFC88418));
  final Set<int> _wishlistIds = <int>{};
  final Set<int> _wishlistLoading = <int>{};
  List<BuyerHomeProduct> _loadedProducts = <BuyerHomeProduct>[];
  List<BuyerHomeProduct> _bestSellingProducts = <BuyerHomeProduct>[];
  List<BuyerHomeProduct> _dealProducts = <BuyerHomeProduct>[];
  List<BuyerHomeCategory> _loadedCategories = <BuyerHomeCategory>[];
  List<Map<String, dynamic>> _platformEvents = <Map<String, dynamic>>[];
  List<BuyerHomeProduct>? _featuredProductsCache;
  List<BuyerHomeProduct>? _recommendedProductsCache;
  BuyerHomeProduct? _heroProductCache;
  bool _heroProductCacheReady = false;
  Future<void>? _productsRequest;
  bool _loadingProducts = false;
  bool _loadingDeals = false;
  bool _loadingEvents = false;
  bool _visible = true;
  DateTime? _loadedAt;
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _syncWishlistState();
    _refreshWishlistState();
    WishlistService.productIds.addListener(_onWishlistChanged);
    _invalidateProductCaches();
    if (widget.products.isEmpty) {
      _loadProducts();
    }
  }

  void _onWishlistChanged() {
    if (!mounted) return;
    setState(() {
      _wishlistIds
        ..clear()
        ..addAll(WishlistService.productIds.value);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WishlistService.productIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isCurrent != false;
    final activated = visible && !_visible;
    _visible = visible;
    if (activated) _refreshIfStale();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _visible) _refreshIfStale();
  }

  void _refreshIfStale() {
    if (widget.products.isNotEmpty || _productsRequest != null) return;
    if (_loadedAt == null || _loadedRevision != ApiClient.dataRevision ||
        DateTime.now().difference(_loadedAt!) >= const Duration(minutes: 1)) {
      unawaited(Future.wait([
        _loadProducts(), _refreshWishlistState(),
      ]));
    }
  }

  void _invalidateProductCaches() {
    _featuredProductsCache = null;
    _recommendedProductsCache = null;
    _heroProductCache = null;
    _heroProductCacheReady = false;
  }

  Future<void> _loadProducts() {
    return _productsRequest ??= _loadHomeContent().whenComplete(() {
      _productsRequest = null;
    });
  }

  Future<void> _loadHomeContent() async {
    _loadedRevision = ApiClient.dataRevision;
    setState(() {
      _loadingProducts = true;
      _loadingDeals = true;
      _loadingEvents = true;
    });
    Future<void> products() async {
      try {
        final fetched = await ProductService.fetchHomeProducts();
        if (!mounted) return;
        setState(() {
          _loadedProducts = fetched;
          _invalidateProductCaches();
        });
        _syncWishlistState();
      } catch (_) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load products right now.')),
        );
      } finally {
        if (mounted) setState(() => _loadingProducts = false);
      }
    }
    Future<void> bestSellers() async {
      try {
        final fetched = await ProductService.fetchHomeProducts(
          sort: 'best-selling',
          perPage: 2,
        );
        if (!mounted) return;
        setState(() {
          _bestSellingProducts = fetched;
          _heroProductCache = null;
          _heroProductCacheReady = false;
        });
        _syncWishlistState();
      } catch (_) {
        // The regular home catalog remains available if this request fails.
      }
    }
    Future<void> deals() async {
      try {
        final fetched = await ProductService.fetchHomeProducts(dealsOnly: true);
        if (mounted) setState(() => _dealProducts = fetched);
      } catch (_) {
        // Retain already displayed deals on a failed refresh.
      } finally {
        if (mounted) setState(() => _loadingDeals = false);
      }
    }
    Future<void> events() async {
      try {
        final fetched = await ProductService.fetchPlatformEvents();
        if (mounted) setState(() => _platformEvents = fetched);
      } catch (_) {
        // Events must not block the catalog or clear existing content.
      } finally {
        if (mounted) setState(() => _loadingEvents = false);
      }
    }
    Future<void> categories() async {
      if (widget.categories.isNotEmpty) return;
      try {
        final fetched = await ProductService.fetchCategories();
        if (mounted && fetched.isNotEmpty) {
          setState(() => _loadedCategories = fetched);
        }
      } catch (_) {
        // Keep the featured category shortcuts when the category API is down.
      }
    }
    await Future.wait([
      products(),
      bestSellers(),
      deals(),
      events(),
      categories(),
    ]);
    _loadedAt = DateTime.now();
  }

  Future<void> _refreshWishlistState() async {
    if (!AppConfig.apiEnabled) return;
    try {
      final products = await BuyerMobileService.fetchWishlist();
      if (!mounted) return;
      WishlistService.replaceWithWishlist(products.map((product) => product.id));
    } catch (_) {}
  }

  @override
  void didUpdateWidget(covariant BuyerHomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products ||
        oldWidget.featuredProducts != widget.featuredProducts ||
        oldWidget.recommendedProducts != widget.recommendedProducts ||
        oldWidget.heroProduct != widget.heroProduct) {
      _syncWishlistState();
      _invalidateProductCaches();
    }
  }

  Iterable<BuyerHomeProduct> get _allKnownProducts sync* {
    yield* widget.products;
    yield* _loadedProducts;
    yield* _bestSellingProducts;
    yield* _dealProducts;
    yield* widget.featuredProducts;
    yield* widget.recommendedProducts;
    final BuyerHomeProduct? hero = widget.heroProduct;
    if (hero != null) yield hero;
  }

  List<BuyerHomeProduct> get _catalogProducts {
    final Map<int, BuyerHomeProduct> unique = <int, BuyerHomeProduct>{};
    for (final BuyerHomeProduct product in _allKnownProducts) {
      if (product.id > 0 && product.isVisibleInCatalog) {
        unique[product.id] = product;
      }
    }
    return unique.values.toList(growable: false);
  }

  List<BuyerHomeCategory> get _availableCategories {
    final List<BuyerHomeCategory> source = widget.categories.isNotEmpty
        ? widget.categories
        : _loadedCategories.isNotEmpty
        ? _loadedCategories
        : _featuredCategories;
    final List<BuyerHomeCategory> result = <BuyerHomeCategory>[];

    final Set<String> seenSlugs = <String>{};
    for (final BuyerHomeCategory category in source) {
      final String name = category.name.trim();
      final String slug = category.slug.trim();
      if (name.isEmpty ||
          slug.isEmpty ||
          !seenSlugs.add(slug.toLowerCase())) {
        continue;
      }

      BuyerHomeCategory? fallback;
      for (final BuyerHomeCategory featured in _featuredCategories) {
        if (featured.slug.toLowerCase() == slug.toLowerCase() ||
            _normalizeCategoryName(featured.name) ==
                _normalizeCategoryName(name)) {
          fallback = featured;
          break;
        }
      }

      result.add(
        BuyerHomeCategory(
          name: name,
          slug: slug,
          icon: category.icon ?? fallback?.icon ?? Icons.grid_view_rounded,
          description: category.description ?? fallback?.description,
          productCount: category.productCount ?? _countKnownProducts(category),
        ),
      );
    }

    return result;
  }

  String _normalizeCategoryName(String value) => value
      .toLowerCase()
      .replaceAll('&', 'and')
      .replaceAll(RegExp(r'[^a-z0-9]'), '');

  int _countKnownProducts(BuyerHomeCategory category) {
    final String categorySlug = category.slug.trim().toLowerCase();
    final String categoryName = category.name.trim().toLowerCase();
    return _catalogProducts.where((BuyerHomeProduct product) {
      final String productSlug = product.categorySlug?.trim().toLowerCase() ?? '';
      final String productName = product.category?.trim().toLowerCase() ?? '';
      return productSlug == categorySlug ||
          productSlug.startsWith('$categorySlug-') ||
          productName == categoryName;
    }).length;
  }

  void _syncWishlistState() {
    final Set<int> incoming = <int>{};
    final List<BuyerHomeProduct> known = _allKnownProducts.toList(growable: false);
    for (final BuyerHomeProduct product in known) {
      if (product.wishlisted) incoming.add(product.id);
    }
    WishlistService.recordKnownProducts(known.map((BuyerHomeProduct product) =>
        (id: product.id, wishlisted: product.wishlisted)));
    if (!AppConfig.apiEnabled) {
      incoming.addAll(WishlistService.localProductIds);
    }
    incoming.addAll(WishlistService.productIds.value);
    _wishlistIds
      ..clear()
      ..addAll(incoming);
  }

  List<BuyerHomeProduct> get _featuredProducts {
    final List<BuyerHomeProduct>? cached = _featuredProductsCache;
    if (cached != null) return cached;

    late final List<BuyerHomeProduct> result;
    final List<BuyerHomeProduct> source = widget.featuredProducts.isNotEmpty
        ? widget.featuredProducts
        : widget.products.isNotEmpty
        ? widget.products
        : _loadedProducts;
    result = source
        .where((BuyerHomeProduct product) => product.isVisibleInCatalog)
        .take(4)
        .toList(growable: false);
    return _featuredProductsCache = result;
  }

  List<BuyerHomeProduct> get _recommendedProducts {
    final List<BuyerHomeProduct>? cached = _recommendedProductsCache;
    if (cached != null) return cached;

    late final List<BuyerHomeProduct> result;
    if (widget.recommendedProducts.isNotEmpty) {
      result = widget.recommendedProducts
          .where((BuyerHomeProduct product) => product.isVisibleInCatalog)
          .take(4)
          .toList(growable: false);
    } else {
      final List<BuyerHomeProduct> source = widget.products.isNotEmpty
          ? widget.products
          : _loadedProducts;
      result = source
          .where((BuyerHomeProduct product) => product.isVisibleInCatalog)
          .skip(4)
          .take(4)
          .toList(growable: false);
    }
    return _recommendedProductsCache = result;
  }

  BuyerHomeProduct? get _heroProduct {
    if (_heroProductCacheReady) return _heroProductCache;

    if (widget.heroProduct?.isVisibleInCatalog == true) {
      _heroProductCache = widget.heroProduct;
      _heroProductCacheReady = true;
      return _heroProductCache;
    }
    if (_bestSellingProducts.isNotEmpty) {
      _heroProductCache = _bestSellingProducts.first;
    } else {
      final List<BuyerHomeProduct> base = widget.products.isNotEmpty
          ? widget.products
          : _loadedProducts;
      _heroProductCache = base.isEmpty ? null : base.first;
    }
    _heroProductCacheReady = true;
    return _heroProductCache;
  }

  Future<void> _toggleWishlist(BuyerHomeProduct product) async {
    if (_wishlistLoading.contains(product.id)) return;

    final BuyerHomeWishlistCallback? asyncCallback =
        widget.onWishlistProductAsync;
    final BuyerHomeProductCallback? syncCallback = widget.onWishlistProduct;
    if (asyncCallback == null && syncCallback == null) {
      return;
    }

    setState(() {
      _wishlistLoading.add(product.id);
    });

    bool completed = false;
    try {
      if (asyncCallback != null) {
        await asyncCallback(product);
      } else {
        syncCallback!.call(product);
      }
      completed = true;
    } catch (_) {
      // ignore for offline layout mode
    } finally {
      if (mounted) {
        setState(() {
          _wishlistLoading.remove(product.id);
          if (completed) {
            _wishlistIds
              ..clear()
              ..addAll(WishlistService.productIds.value);
          }
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BuyerNavigationFrame(
      currentIndex: 0,
      aiPage: 'home',
      aiPageTitle: 'Home',
      onHome: () {},
      onOrders: widget.onViewOrders ?? widget.onBrowseProducts ?? () {},
      onMessages: widget.onMessages ?? widget.onBrowseProducts ?? () {},
      onProfile: widget.onProfile ?? widget.onBrowseProducts ?? () {},
      child: Scaffold(
        backgroundColor: background,
        body: SafeArea(
          bottom: false,
          child: RefreshIndicator(
            color: maroon,
            onRefresh: () async {
              await Future.wait([
                _loadProducts(),
                _refreshWishlistState(),
              ]);
            },
            child: CustomScrollView(
              key: const PageStorageKey<String>('buyer-home-scroll'),
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                _buildMainContent(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
        child: Column(children: [
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(mainAxisSize: MainAxisSize.min, children: [
                Image.asset(
                  'assets/icons/likhae_ai_logo.png',
                  width: 58,
                  height: 48,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 4),
                Text(
                  'LIKHAE',
                  style: TextStyle(
                    color: text,
                    fontFamily: 'serif',
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ]),
              const SizedBox(height: 3),
              Text('Shop smart with LIKHAE', style: TextStyle(color: muted, fontSize: 11.5)),
            ])),
            GlassIconButton(icon: Icons.notifications_none_rounded, label: 'Notifications', onPressed: widget.onNotifications),
            const SizedBox(width: 9),
            GlassIconButton(icon: Icons.shopping_bag_outlined, label: 'Cart', onPressed: widget.onCart),
          ]),
          const SizedBox(height: 20),
          Material(
            color: card, borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: widget.onSearch, borderRadius: BorderRadius.circular(18),
              child: Padding(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15), child: Row(children: [
                Icon(Icons.search_rounded, size: 22, color: maroon),
                const SizedBox(width: 11),
                Expanded(child: Text('Search products, categories, local sellers...', style: TextStyle(color: muted, fontSize: 13))),
              ])),
            ),
          ),
        ]),
      ),
    ));
  }

  Widget _buildMainContent() {
    final List<BuyerHomeProduct> featuredProducts = _featuredProducts;
    final List<BuyerHomeProduct> recommendedProducts = _recommendedProducts;
    final List<BuyerHomeProduct> currentDealProducts = _dealProducts
        .where(
          (BuyerHomeProduct product) =>
              product.discountPercentage != null &&
              !product.sellerOnVacation &&
              !product.isOutOfStock,
        )
        .take(4)
        .toList(growable: false);
    final sections = <Widget>[
      if (_loadingProducts) const LinearProgressIndicator(minHeight: 2),
      _buildHero(_heroProduct),
      const SizedBox(height: 22),
      _buildQuickActions(),
      const SizedBox(height: 30),
      _buildCategorySection(),
      const SizedBox(height: 30),
      _buildHeaderRow(
        'Curated',
        'Featured Products',
        'Top picks from trusted sellers.',
        'See All',
        widget.onViewFeatured,
      ),
      const SizedBox(height: 16),
      if (featuredProducts.isEmpty)
        _buildHomeEmptyState(
          title: 'Featured products are coming soon',
          description: 'Products from trusted local sellers will appear here.',
        )
      else
        _ProductGrid(
          products: featuredProducts,
          isWishlisted: (product) => _wishlistIds.contains(product.id),
          isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
          onProductSelected: widget.onProductSelected,
          onWishlistProduct: _toggleWishlist,
        ),
      const SizedBox(height: 30),
      _buildDealsBanner(),
      const SizedBox(height: 24),
      _buildHeaderRow(
        'Live seller discounts',
        'Flash Sale',
        'Shop available products at their current discounted variant prices.',
        'See All',
        widget.onShopDeals,
      ),
      const SizedBox(height: 12),
      if (currentDealProducts.isNotEmpty)
        _ProductGrid(
          products: currentDealProducts,
          isWishlisted: (product) => _wishlistIds.contains(product.id),
          isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
          onProductSelected: widget.onProductSelected,
          onWishlistProduct: _toggleWishlist,
        )
      else if (_loadingDeals)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Loading deals...',
            style: TextStyle(color: muted, fontSize: 12),
          ),
        )
      else
        _buildHomeEmptyState(
          title: 'No discounted products are available right now',
          description: 'Check back later for current seller discounts.',
        ),
      const SizedBox(height: 30),
      _buildPlatformEvents(),
      const SizedBox(height: 30),
      _buildHeaderRow(
        'For You',
        'Recommended For You',
        'Products based on popular buyer choices.',
        'See All',
        widget.onViewRecommended,
      ),
      const SizedBox(height: 16),
      if (recommendedProducts.isEmpty)
        _buildHomeEmptyState(
          title: 'More recommendations will appear here',
          description: 'Explore products to help us prepare recommendations for you.',
          actionLabel: 'Explore Products',
          onAction: widget.onBrowseProducts,
        )
      else
        _ProductGrid(
          products: recommendedProducts,
          isWishlisted: (product) => _wishlistIds.contains(product.id),
          isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
          onProductSelected: widget.onProductSelected,
          onWishlistProduct: _toggleWishlist,
        ),

    ];
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
      sliver: SliverList(delegate: SliverChildBuilderDelegate(
        (context, index) => Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1080),
          child: SizedBox(width: double.infinity, child: sections[index]),
        )),
        childCount: sections.length,
      )),
    );
  }

  Widget _buildHomeEmptyState({
    required String title,
    required String description,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(Icons.storefront_outlined, color: maroonLight, size: 30),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(color: muted, fontSize: 11, height: 1.4),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: maroon,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDealsBanner() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[
            ShopColors.accentDark,
            ShopColors.accent,
            ShopColors.accentLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShopColors.accentDark.withValues(alpha: .14),
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Stack(
        children: <Widget>[
          Positioned(
            top: -19,
            right: -12,
            child: Icon(
              Icons.local_offer_rounded,
              size: 112,
              color: Colors.white.withValues(alpha: .07),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 17),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'CURRENT DISCOUNTS',
                  style: TextStyle(
                    color: Color(0xFFE9C7A5),
                    fontSize: 9,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Current Deals',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    height: 1.05,
                    letterSpacing: -.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Browse products with current seller discounts.',
                  style: TextStyle(
                    color: Color(0xFFF4DED4),
                    fontSize: 11,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 13),
                FilledButton.icon(
                  onPressed: widget.onShopDeals,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 15),
                  label: const Text('Shop Deals'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF7EF),
                    foregroundColor: ShopColors.accentDark,
                    minimumSize: const Size(0, 38),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlatformEvents() {
    final List<Map<String, dynamic>> events = _platformEvents.take(4).toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(
          'LIKHAE Marketplace',
          'Platform Events',
          'Marketplace-wide campaigns and events.',
          'View Offers',
          widget.onShopDeals,
        ),
        const SizedBox(height: 12),
        if (events.isEmpty)
          _buildHomeEmptyState(
            title: _loadingEvents
                ? 'Loading events...'
                : 'No scheduled events right now',
            description: _loadingEvents
                ? 'Marketplace-wide campaigns and events.'
                : 'When a marketplace-wide event is scheduled, its dates and details will appear here.',
          )
        else
          ...events.map(_buildPlatformEventCard),
      ],
    );
  }

  Widget _buildPlatformEventCard(Map<String, dynamic> event) {
    final String status = (event['status'] ?? 'active').toString().toLowerCase();
    final bool upcoming = status == 'upcoming';
    final String title = (event['title'] ?? 'Platform event').toString();
    final double discountValue = double.tryParse(
          (event['discount_value'] ?? 0).toString(),
        ) ??
        0;
    final bool isPercent =
        (event['discount_type'] ?? '').toString().toUpperCase() == 'PERCENT';
    final String discount = isPercent
        ? '${discountValue.toStringAsFixed(2).replaceFirst(RegExp(r'\.?0+$'), '')}%'
        : '${String.fromCharCode(0x20B1)}${discountValue.toStringAsFixed(2)}';
    final double minimumSpend = double.tryParse(
          (event['minimum_order_amount'] ?? 0).toString(),
        ) ??
        0;
    final dynamic rawMaximumSavings = event['maximum_discount_amount'];
    final DateTime? startsAt = DateTime.tryParse(
      (event['starts_at'] ?? '').toString(),
    );
    final DateTime? endsAt = DateTime.tryParse(
      (event['ends_at'] ?? '').toString(),
    );
    final String validity =
        '${startsAt == null ? 'Starts now' : _formatCampaignDate(startsAt)} – ${endsAt == null ? 'No end date' : _formatCampaignDate(endsAt)}';

    Widget detail(String label, String value) => Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              color: Color(0xFFE9C7A5),
              fontSize: 8,
              letterSpacing: 1,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFFFFF8F2),
              fontSize: 11,
              height: 1.35,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[ShopColors.accentDark, ShopColors.accent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShopColors.accentDark.withValues(alpha: .12),
            blurRadius: 16,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: upcoming
                      ? const Color(0xFFF8EDD9)
                      : const Color(0xFFE8F3EA),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  upcoming ? 'UPCOMING' : 'ACTIVE',
                  style: TextStyle(
                    color: upcoming
                        ? const Color(0xFF8A5A12)
                        : const Color(0xFF256F4A),
                    fontSize: 8,
                    letterSpacing: .7,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              const Expanded(
                child: Text(
                  'LIKHAE PLATFORM EVENT',
                  style: TextStyle(
                    color: Color(0xFFE9C7A5),
                    fontSize: 8,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFFFF8F2),
                    fontSize: 23,
                    height: 1.05,
                    letterSpacing: -.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Container(
                constraints: const BoxConstraints(minWidth: 78),
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .10),
                  border: Border.all(color: const Color(0x80E9C7A5)),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Column(
                  children: <Widget>[
                    Text(
                      discount,
                      maxLines: 1,
                      style: const TextStyle(
                        color: Color(0xFFFFF8F2),
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'OFF',
                      style: TextStyle(
                        color: Color(0xFFE9C7A5),
                        fontSize: 8,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 13),
          Container(height: 1, color: Colors.white.withValues(alpha: .18)),
          detail(
            'Minimum spend',
            minimumSpend > 0
                ? '${String.fromCharCode(0x20B1)}${minimumSpend.toStringAsFixed(2)}'
                : 'No minimum spend',
          ),
          detail(
            'Max savings',
            rawMaximumSavings == null
                ? 'No discount cap'
                : '${String.fromCharCode(0x20B1)}${(double.tryParse(rawMaximumSavings.toString()) ?? 0).toStringAsFixed(2)}',
          ),
          detail('Valid period', validity),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => _showPlatformEventDetails(event),
              icon: const Icon(Icons.arrow_forward_rounded, size: 14),
              label: const Text('View Event'),
              style: TextButton.styleFrom(
                foregroundColor: ShopColors.accentDark,
                backgroundColor: const Color(0xFFE9C7A5),
                padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                textStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatCampaignDate(DateTime date) {
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final DateTime localDate = date.toLocal();
    final int hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final String minute = localDate.minute.toString().padLeft(2, '0');
    final String period = localDate.hour < 12 ? 'AM' : 'PM';
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year} $hour:$minute $period';
  }

  void _showPlatformEventDetails(Map<String, dynamic> event) {
    final String title = (event['title'] ?? 'Platform event').toString();
    final String body = (event['body'] ?? '').toString();
    final String code = (event['code'] ?? '').toString().trim();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: card,
      builder: (BuildContext context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 26),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: TextStyle(color: text, fontSize: 20, fontWeight: FontWeight.w800)),
              if (body.isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(body, style: TextStyle(color: muted, fontSize: 13, height: 1.45)),
              ],
              if (code.isNotEmpty) ...<Widget>[
                const SizedBox(height: 14),
                Text('VOUCHER CODE', style: TextStyle(color: maroon, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w900)),
                const SizedBox(height: 5),
                SelectableText(code, style: TextStyle(color: text, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection() {
    final List<BuyerHomeCategory> categories = _availableCategories;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildHeaderRow(
          'Browse',
          'Shop by Category',
          'Explore products from different collections.',
          'View All',
          widget.onViewAllCategories,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final BuyerHomeCategory category = categories[index];
              return SizedBox(
                width: 88,
                child: _BuyerCategoryCard(
                  category: category,
                  onTap: category.slug == 'all'
                      ? widget.onViewAllCategories ?? widget.onBrowseProducts
                      : widget.onCategorySelected == null
                      ? widget.onBrowseProducts
                      : () => widget.onCategorySelected!(category.slug),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    final List<_BuyerQuickAction> actions = <_BuyerQuickAction>[
      _BuyerQuickAction(
        label: 'Wishlist',
        description: 'Saved products',
        icon: Icons.favorite_border_rounded,
        onTap: widget.onWishlist,
      ),
      _BuyerQuickAction(
        label: 'Following',
        description: 'Your favorite stores',
        icon: Icons.storefront_outlined,
        onTap: widget.onFollowingShops,
      ),
      _BuyerQuickAction(
        label: 'Messages',
        description: 'Chat with sellers',
        icon: Icons.chat_bubble_outline_rounded,
        onTap: widget.onMessages,
      ),
      _BuyerQuickAction(
        label: 'Vouchers',
        description: 'Available vouchers',
        icon: Icons.card_giftcard_outlined,
        onTap: widget.onVouchers,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth >= 680) {
          return Row(
            children: <Widget>[
              for (int index = 0; index < actions.length; index++) ...<Widget>[
                if (index > 0) const SizedBox(width: 14),
                Expanded(child: _BuyerQuickActionCard(action: actions[index])),
              ],
            ],
          );
        }

        final double cardWidth = (constraints.maxWidth - 10) / 2;
        return Wrap(
          spacing: 10,
          runSpacing: 10,
          children: actions
              .map(
                (_BuyerQuickAction action) => SizedBox(
                  width: cardWidth,
                  child: _BuyerQuickActionCard(action: action),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildHero(BuyerHomeProduct? product) {
    Widget buildCopy({required bool compact}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: compact ? 20 : 28, height: 1, color: ShopColors.accentLight),
            const SizedBox(width: 8),
            const Text(
              'WELCOME TO LIKHAE',
              style: TextStyle(
                color: ShopColors.accentLight,
                fontSize: 9,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 8 : 13),
        Text.rich(
          const TextSpan(
            children: [
              TextSpan(text: 'Everything you need,\n'),
              TextSpan(
                text: 'in one place.',
                style: TextStyle(color: Color(0xFFFFD9CC)),
              ),
            ],
          ),
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 25 : 30,
            letterSpacing: compact ? -0.6 : -0.8,
            height: 1.08,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: compact ? 8 : 12),
        Text(
          'Shop across a wide range of categories from trusted sellers. Compare options and find everything you need for everyday living.',
          style: TextStyle(
            color: const Color(0xFFEEDBD4),
            fontSize: compact ? 11 : 12,
            height: compact ? 1.4 : 1.5,
          ),
        ),
      ],
    );

    final Widget copy = buildCopy(compact: false);

    final Widget photo = product == null
        ? Container(
            width: double.infinity,
            height: 190,
            alignment: Alignment.center,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: ShopColors.accentDark.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'Products will appear here when available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFFEEDBD4), fontSize: 12),
            ),
          )
        : Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onProductSelected == null
                  ? null
                  : () => widget.onProductSelected!(product),
              child: Column(
                children: [
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: _ProductGallery(images: product.galleryImages),
                        ),
                      ),
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: ShopColors.accentSoft,
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.star_rounded, color: ShopColors.tan, size: 12),
                              SizedBox(width: 4),
                              Text(
                                'Best Seller',
                                style: TextStyle(
                                  color: ShopColors.accentDark,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    product.name,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      height: 1.3,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    String.fromCharCode(0x20B1) + product.price.toStringAsFixed(2) + (product.category?.trim().isNotEmpty == true ? '  |  ' + product.category! : ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFFEEDBD4), fontSize: 10),
                  ),
                ],
              ),
            ),
          );

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 620 ||
            MediaQuery.textScalerOf(context).scale(14) > 22;

        Widget compactProductPreview() {
          if (product == null) {
            return Container(
              height: 90,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text(
                'Products will appear here when available.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFEEDBD4), fontSize: 11),
              ),
            );
          }

          return Material(
            color: Colors.white.withValues(alpha: .96),
            borderRadius: BorderRadius.circular(17),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onProductSelected == null
                  ? null
                  : () => widget.onProductSelected!(product),
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 108,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: _ProductGallery(images: product.galleryImages),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'FEATURED PICK',
                            style: TextStyle(
                              color: ShopColors.accentLight,
                              fontSize: 8,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: ShopColors.text,
                              fontSize: 12,
                              height: 1.2,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            String.fromCharCode(0x20B1) +
                                product.price.toStringAsFixed(2),
                            style: const TextStyle(
                              color: ShopColors.accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (product.category?.trim().isNotEmpty == true) ...[
                            const SizedBox(height: 2),
                            Text(
                              product.category!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: ShopColors.muted,
                                fontSize: 9,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Container(
          padding: EdgeInsets.all(compact ? 16 : 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [ShopColors.accentDark, ShopColors.accent, ShopColors.accentLight],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(compact ? 23 : 28),
            boxShadow: [
              BoxShadow(
                color: ShopColors.accent.withValues(alpha: .1),
                blurRadius: compact ? 18 : 26,
                offset: Offset(0, compact ? 7.0 : 10.0),
              ),
            ],
          ),
          child: compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    buildCopy(compact: true),
                    const SizedBox(height: 13),
                    compactProductPreview(),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 3, child: copy),
                    const SizedBox(width: 22),
                    Expanded(flex: 2, child: photo),
                  ],
                ),
        );
      },
    );
  }
  Widget _buildHeaderRow(String kicker, String title, String subtitle, String actionText, VoidCallback? onAction) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                kicker.toUpperCase(),
                style: TextStyle(
                  color: maroonLight,
                  fontSize: 9,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  color: text,
                  fontSize: 19,
                  height: 1.15,
                  letterSpacing: -0.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(color: muted, fontSize: 11, height: 1.4),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        TextButton.icon(
          onPressed: onAction,
          iconAlignment: IconAlignment.end,
          icon: const Icon(Icons.arrow_forward_rounded, size: 15),
          label: Text(actionText),
          style: TextButton.styleFrom(
            foregroundColor: maroon,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}



class _ProductGrid extends StatelessWidget {
  final List<BuyerHomeProduct> products;
  final bool Function(BuyerHomeProduct product) isWishlisted;
  final bool Function(BuyerHomeProduct product) isWishlistLoading;
  final BuyerHomeProductCallback? onProductSelected;
  final BuyerHomeWishlistCallback onWishlistProduct;

  const _ProductGrid({
    required this.products,
    required this.isWishlisted,
    required this.isWishlistLoading,
    required this.onProductSelected,
    required this.onWishlistProduct,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 940 ? 4 : constraints.maxWidth >= 660 ? 3 : constraints.maxWidth < 290 || MediaQuery.textScalerOf(context).scale(14) > 24 ? 1 : 2;
        const double spacing = 12;
        final double itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Directionality(
          textDirection: TextDirection.ltr,
          child: Wrap(
            spacing: spacing,
            runSpacing: 12,
            textDirection: TextDirection.ltr,
            children: products.map((BuyerHomeProduct product) {
              return SizedBox(
                width: itemWidth,
                child: _ProductCard(
                  product: product,
                  isWishlisted: isWishlisted(product),
                  wishlistLoading: isWishlistLoading(product),
                  onTap: onProductSelected == null
                      ? null
                      : () => onProductSelected!(product),
                  onWishlist: () => onWishlistProduct(product),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}

class _ProductCard extends StatelessWidget {
  final BuyerHomeProduct product;
  final bool isWishlisted;
  final bool wishlistLoading;
  final VoidCallback? onTap;
  final VoidCallback onWishlist;

  const _ProductCard({required this.product, required this.isWishlisted, required this.wishlistLoading, required this.onTap, required this.onWishlist});

  @override
  Widget build(BuildContext context) => ShopProductCard(
    image: _ProductGallery(images: product.galleryImages),
    imageAspectRatio: 4.0 / 3.0,
    name: product.name, category: product.category, seller: product.sellerName,
    price: product.price, originalPrice: product.originalPrice, rating: product.rating,
    soldCount: product.soldCount,
    outOfStock: product.isOutOfStock || product.sellerOnVacation,
    availabilityLabel: product.sellerOnVacation ? 'Seller on vacation' : null,
    wishlisted: isWishlisted, wishlistLoading: wishlistLoading,
    onTap: onTap, onWishlist: onWishlist,
  );
}

class _ProductGallery extends StatefulWidget {
  final List<String> images;

  const _ProductGallery({required this.images});

  @override
  State<_ProductGallery> createState() => _ProductGalleryState();
}

class _ProductGalleryState extends State<_ProductGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.images;
    if (images.isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 34,
          color: _BuyerHomeScreenState.muted2,
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        PageView.builder(
          itemCount: images.length,
          onPageChanged: (int index) {
            if (mounted) {
              setState(() => _currentIndex = index);
            }
          },
          itemBuilder: (BuildContext context, int index) {
            return _ProductImage(url: images[index]);
          },
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(images.length, (int index) {
                final bool active = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  width: active ? 14 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active
                        ? _BuyerHomeScreenState.maroon
                        : _BuyerHomeScreenState.muted2.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

class _ProductImage extends StatelessWidget {
  final String? url;
  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty) {
      return const Center(child: Icon(Icons.inventory_2_outlined,
        color: ShopColors.faint, size: 34));
    }
    return SizedNetworkImage(url: AppConfig.resolveMediaUrl(value),
      fit: BoxFit.contain, iconSize: 34);
  }
}

class _BuyerCategoryCard extends StatelessWidget {
  final BuyerHomeCategory category;
  final VoidCallback? onTap;

  const _BuyerCategoryCard({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final IconData icon = category.icon ?? Icons.grid_view_rounded;

    return Semantics(
      button: true,
      label: 'Explore ${category.name}',
      child: Material(
        color: _BuyerHomeScreenState.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 110,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            decoration: BoxDecoration(
              border: Border.all(color: _BuyerHomeScreenState.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: _BuyerHomeScreenState.backgroundSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 21,
                    color: _BuyerHomeScreenState.maroonLight,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _BuyerHomeScreenState.text,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore',
                  style: TextStyle(
                    color: _BuyerHomeScreenState.muted,
                    fontSize: 8,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BuyerQuickAction {
  final String label;
  final String description;
  final IconData icon;
  final VoidCallback? onTap;

  const _BuyerQuickAction({
    required this.label,
    required this.description,
    required this.icon,
    required this.onTap,
  });
}

class _BuyerQuickActionCard extends StatelessWidget {
  final _BuyerQuickAction action;

  const _BuyerQuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '${action.label}, ${action.description}',
      child: Material(
        color: _BuyerHomeScreenState.card,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: _BuyerHomeScreenState.border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _BuyerHomeScreenState.backgroundSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    size: 22,
                    color: _BuyerHomeScreenState.maroon,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        action.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _BuyerHomeScreenState.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        action.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: _BuyerHomeScreenState.muted,
                          fontSize: 10.5,
                          height: 1.25,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


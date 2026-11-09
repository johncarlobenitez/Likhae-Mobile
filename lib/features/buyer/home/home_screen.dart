import '../../../shared/widgets/sized_network_image.dart';
import 'dart:async';
import '../../../core/api/api_client.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import '../../../shared/widgets/app_motion.dart';
import '../../../shared/widgets/loading_skeleton.dart';
import 'package:likhae/core/theme/app_theme.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/utils/api_value_parsers.dart';
import 'package:likhae/services/product_service.dart';
import 'package:likhae/services/buyer_mobile_service.dart';
import 'package:likhae/services/wishlist_service.dart';
import 'package:likhae/shared/widgets/buyer_navigation.dart';
import 'package:likhae/shared/widgets/buyer_navigation_badges.dart';

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
  final DateTime? flashSaleStartsAt;
  final DateTime? flashSaleEndsAt;

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
    this.flashSaleStartsAt,
    this.flashSaleEndsAt,
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

  bool get isFlashSaleExpired {
    final DateTime? end = flashSaleEndsAt;
    return end != null && !end.isAfter(DateTime.now());
  }

  bool get isFlashSaleUpcoming {
    final DateTime? start = flashSaleStartsAt;
    return !isFlashSaleExpired &&
        start != null &&
        start.isAfter(DateTime.now());
  }

  bool get isFlashSaleActive =>
      !isFlashSaleExpired &&
      !isFlashSaleUpcoming &&
      (flashSaleStartsAt != null || flashSaleEndsAt != null);

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
    final bool hasPricedVariant =
        rawVariants is List &&
        rawVariants.any(
          (dynamic row) =>
              row is Map &&
              double.tryParse(
                    (row['price'] ?? row['sale_price'] ?? '').toString(),
                  ) !=
                  null,
        );
    if (rawId == null ||
        rawName == null ||
        (rawPrice == null && !hasPricedVariant)) {
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
    final dynamic resolvedPrice =
        dealVariant?['price'] ??
        json['min_price'] ??
        (lowestVariant == null
            ? rawPrice
            : lowestVariant['price'] ?? lowestVariant['sale_price']);
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
    final dynamic rawOriginal =
        dealVariant?['original_price'] ??
        (variants.isEmpty
            ? json['old_price'] ?? json['original_price']
            : priceVariant?['old_price'] ?? priceVariant?['original_price']);
    final String productStatus = (json['status'] ?? '')
        .toString()
        .trim()
        .toLowerCase();
    final dynamic rawActive =
        json['is_active'] ??
        json['is_available'] ??
        json['active'] ??
        json['is_published'];
    final bool active = parseApiBool(
      rawActive,
      defaultValue: !<String>{
        'inactive',
        'unpublished',
        'draft',
        'deleted',
        'disabled',
      }.contains(productStatus),
    );
    final bool draft =
        parseApiBool(json['is_draft'], defaultValue: false) ||
        productStatus == 'draft';
    final bool deleted =
        parseApiBool(
          json['is_deleted'] ?? json['deleted'],
          defaultValue: false,
        ) ||
        json['deleted_at'] != null ||
        productStatus == 'deleted';
    final dynamic rawStock =
        dealVariant?['stock'] ??
        json['stock'] ??
        json['quantity'] ??
        json['variant_stock'];
    final String imageValue =
        (json['image_url'] ??
                json['image'] ??
                primaryImage?['url'] ??
                primaryImage?['file_path'] ??
                '')
            .toString()
            .trim();
    final List<String> dealVariantImages = _parseImageUrls(
      dealVariant?['image_urls'],
    );
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
          (category?['name'] ??
                  json['parent_category'] ??
                  json['category'] ??
                  '')
              .toString(),
      categorySlug: (category?['slug'] ?? json['category_slug'] ?? '')
          .toString()
          .trim(),
      sellerName: sellerValue.isEmpty ? null : sellerValue,
      sellerSlug:
          (seller?['slug'] ?? seller?['store_slug'] ?? seller?['id'] ?? '')
              .toString(),
      sellerUserId: int.tryParse(
        (seller?['user_id'] ?? json['seller_user_id'] ?? '').toString(),
      ),
      imageUrl: resolvedImages.isEmpty ? null : resolvedImages.first,
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
        seller?['is_on_vacation'] ??
            seller?['is_vacation_mode'] ??
            seller?['vacation_mode'] ??
            json['seller_on_vacation'],
        defaultValue: false,
      ),
      isFeatured: json['is_featured'] == true,
      isRecommended: json['is_recommended'] == true,
      wishlisted: json['wishlisted'] == true,
      flashSaleStartsAt: DateTime.tryParse(
        (json['flash_sale_starts_at'] ?? '').toString(),
      ),
      flashSaleEndsAt: DateTime.tryParse(
        (json['flash_sale_ends_at'] ?? '').toString(),
      ),
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
        raw =
            (image['url'] ??
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
  final VoidCallback? onViewSellerOffers;
  final VoidCallback? onViewBundleDeals;
  final VoidCallback? onViewFreeGifts;
  final VoidCallback? onViewPlatformEvents;
  final VoidCallback? onViewAllCategories;
  final BuyerHomeCategoryCallback? onCategorySelected;
  final VoidCallback? onViewFeatured;
  final VoidCallback? onShopDeals;
  final VoidCallback? onViewFlashDeals;
  final VoidCallback? onViewRecommended;
  final BuyerHomeProductCallback? onProductSelected;
  final BuyerHomeProductCallback? onSellerSelected;
  final BuyerHomeWishlistCallback? onWishlistProductAsync;
  final BuyerHomeProductCallback? onWishlistProduct;
  final BuyerHomeRefreshCallback? onRefresh;
  final int cartItemCount;
  final int unreadNotificationCount;
  final bool localPreview;
  final ScrollController? scrollController;

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
    this.onViewSellerOffers,
    this.onViewBundleDeals,
    this.onViewFreeGifts,
    this.onViewPlatformEvents,
    this.onViewAllCategories,
    this.onCategorySelected,
    this.onViewFeatured,
    this.onShopDeals,
    this.onViewFlashDeals,
    this.onViewRecommended,
    this.onProductSelected,
    this.onSellerSelected,
    this.onWishlistProductAsync,
    this.onWishlistProduct,
    this.onRefresh,
    this.cartItemCount = 0,
    this.unreadNotificationCount = 0,
    this.localPreview = false,
    this.scrollController,
  });

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen>
    with WidgetsBindingObserver {
  static const Duration _heroAutoAdvanceInterval = Duration(seconds: 6);
  static const Duration _heroTransitionDuration = Duration(milliseconds: 550);

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

  static const Color background = ShopColors.canvas;
  static const Color backgroundSoft = ShopColors.accentSoft;
  static const Color card = ShopColors.surface;
  static const Color border = ShopColors.border;
  static const Color maroon = ShopColors.accent;
  static const Color maroonLight = ShopColors.accentLight;
  static const Color text = ShopColors.text;
  static const Color muted = ShopColors.muted;
  static const Color muted2 = ShopColors.faint;
  final Set<int> _wishlistIds = <int>{};
  final Set<int> _wishlistLoading = <int>{};
  List<BuyerHomeProduct> _loadedProducts = <BuyerHomeProduct>[];
  List<BuyerHomeProduct> _bestSellingProducts = <BuyerHomeProduct>[];
  List<BuyerHomeProduct> _dealProducts = <BuyerHomeProduct>[];
  List<BuyerHomeCategory> _loadedCategories = <BuyerHomeCategory>[];
  List<Map<String, dynamic>> _platformEvents = <Map<String, dynamic>>[];
  final Set<int> _claimedPlatformEvents = <int>{};
  final Set<int> _claimingPlatformEvents = <int>{};
  final PageController _heroPageController = PageController();
  Timer? _heroAdvanceTimer;
  int _heroPage = 0;
  List<BuyerHomeProduct>? _featuredProductsCache;
  List<BuyerHomeProduct>? _recommendedProductsCache;
  Future<void>? _productsRequest;
  bool _loadingProducts = false;
  bool _loadingDeals = false;
  bool _visible = true;
  DateTime? _loadedAt;
  int _loadedRevision = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleHeroAdvance();
    _syncWishlistState();
    if (widget.localPreview) {
      _invalidateProductCaches();
      return;
    }
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
    _heroAdvanceTimer?.cancel();
    _heroPageController.dispose();
    WishlistService.productIds.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible =
        TickerMode.valuesOf(context).enabled &&
        ModalRoute.of(context)?.isCurrent != false;
    final activated = visible && !_visible;
    _visible = visible;
    if (visible) {
      _scheduleHeroAdvance();
    } else {
      _heroAdvanceTimer?.cancel();
    }
    if (activated) _refreshIfStale();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      if (_visible) {
        _refreshIfStale();
        _scheduleHeroAdvance();
      }
    } else {
      _heroAdvanceTimer?.cancel();
    }
  }

  void _scheduleHeroAdvance() {
    _heroAdvanceTimer?.cancel();
    if (!mounted || !_visible) return;
    _heroAdvanceTimer = Timer(_heroAutoAdvanceInterval, () {
      if (!mounted || !_visible || !_heroPageController.hasClients) return;
      final int nextPage = (_heroPage + 1) % 2;
      _heroPageController.animateToPage(
        nextPage,
        duration: _heroTransitionDuration,
        curve: Curves.easeInOutCubic,
      );
    });
  }

  Map<String, dynamic>? get _heroEvent {
    for (final Map<String, dynamic> event in _platformEvents) {
      final String status = _platformEventStatus(event);
      if (status == 'active' || status == 'upcoming') return event;
    }
    return null;
  }

  void _refreshIfStale() {
    if (widget.localPreview) return;
    if (widget.products.isNotEmpty || _productsRequest != null) return;
    if (_loadedAt == null ||
        _loadedRevision != ApiClient.dataRevision ||
        DateTime.now().difference(_loadedAt!) >= const Duration(minutes: 1)) {
      unawaited(Future.wait([_loadProducts(), _refreshWishlistState()]));
    }
  }

  void _invalidateProductCaches() {
    _featuredProductsCache = null;
    _recommendedProductsCache = null;
  }

  Future<void> _loadProducts() {
    if (widget.localPreview) return Future<void>.value();
    return _productsRequest ??= _loadHomeContent().whenComplete(() {
      _productsRequest = null;
    });
  }

  Future<void> _loadHomeContent() async {
    _loadedRevision = ApiClient.dataRevision;
    setState(() {
      _loadingProducts = true;
      _loadingDeals = true;
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
        if (mounted)
          ScaffoldMessenger.of(context).showSnackBar(
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
    if (widget.localPreview) return;
    if (!AppConfig.apiEnabled) return;
    try {
      final products = await BuyerMobileService.fetchWishlist();
      if (!mounted) return;
      WishlistService.replaceWithWishlist(
        products.map((product) => product.id),
      );
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
      if (name.isEmpty || slug.isEmpty || !seenSlugs.add(slug.toLowerCase())) {
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
      final String productSlug =
          product.categorySlug?.trim().toLowerCase() ?? '';
      final String productName = product.category?.trim().toLowerCase() ?? '';
      return productSlug == categorySlug ||
          productSlug.startsWith('$categorySlug-') ||
          productName == categoryName;
    }).length;
  }

  void _syncWishlistState() {
    final Set<int> incoming = <int>{};
    final List<BuyerHomeProduct> known = _allKnownProducts.toList(
      growable: false,
    );
    for (final BuyerHomeProduct product in known) {
      if (product.wishlisted) incoming.add(product.id);
    }
    if (widget.localPreview) {
      _wishlistIds
        ..clear()
        ..addAll(incoming);
      return;
    }
    WishlistService.recordKnownProducts(
      known.map(
        (BuyerHomeProduct product) =>
            (id: product.id, wishlisted: product.wishlisted),
      ),
    );
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

  Future<void> _toggleWishlist(BuyerHomeProduct product) async {
    if (widget.localPreview) return;
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
    final content = Scaffold(
      backgroundColor: AppTheme.resolve(context, background, fill: true),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.resolve(context, maroon),
          onRefresh: () async {
            await Future.wait([_loadProducts(), _refreshWishlistState()]);
          },
          child: CustomScrollView(
            controller: widget.scrollController,
            key: const PageStorageKey<String>('buyer-home-scroll'),
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverToBoxAdapter(child: _buildHeader()),
              _buildMainContent(),
            ],
          ),
        ),
      ),
    );
    if (widget.localPreview) return content;
    return BuyerNavigationFrame(
      currentIndex: 0,
      aiPage: 'home',
      aiPageTitle: 'Home',
      onHome: () {},
      onOrders: widget.onViewOrders ?? widget.onBrowseProducts ?? () {},
      onMessages: widget.onMessages ?? widget.onBrowseProducts ?? () {},
      onProfile: widget.onProfile ?? widget.onBrowseProducts ?? () {},
      child: content,
    );
  }

  Widget _buildHeader() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
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
                                color: AppTheme.resolve(context, text),
                                fontFamily: 'serif',
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Shop smart with LIKHAE',
                          style: TextStyle(
                            color: AppTheme.resolve(context, muted),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  AnimatedBuilder(
                    animation: BuyerNavigationBadges.instance,
                    builder: (BuildContext context, Widget? _) {
                      final BuyerNavigationBadges counts =
                          BuyerNavigationBadges.instance;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Badge.count(
                            count: counts.notificationCount,
                            isLabelVisible: counts.notificationCount > 0,
                            child: GlassIconButton(
                              icon: Icons.notifications_none_rounded,
                              label: 'Notifications',
                              onPressed: () {
                                unawaited(
                                  BuyerNavigationBadges.instance.refresh(
                                    force: true,
                                  ),
                                );
                                widget.onNotifications?.call();
                              },
                            ),
                          ),
                          const SizedBox(width: 9),
                          Badge.count(
                            count: counts.cartCount,
                            isLabelVisible: counts.cartCount > 0,
                            child: GlassIconButton(
                              icon: Icons.shopping_bag_outlined,
                              label: 'Cart',
                              onPressed: () {
                                unawaited(
                                  BuyerNavigationBadges.instance.refresh(
                                    force: true,
                                  ),
                                );
                                widget.onCart?.call();
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Material(
                color: AppTheme.resolve(context, card, fill: true),
                borderRadius: BorderRadius.circular(18),
                child: InkWell(
                  onTap: widget.onSearch,
                  borderRadius: BorderRadius.circular(18),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.search_rounded,
                          size: 22,
                          color: AppTheme.resolve(context, maroon),
                        ),
                        const SizedBox(width: 11),
                        Expanded(
                          child: Text(
                            'Search products, categories, local sellers...',
                            style: TextStyle(
                              color: AppTheme.resolve(context, muted),
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildMainContent() {
    final List<BuyerHomeProduct> featuredProducts = _featuredProducts;
    final List<BuyerHomeProduct> recommendedProducts = _recommendedProducts;
    final List<BuyerHomeProduct> currentDealProducts = _dealProducts
        .where(
          (BuyerHomeProduct product) =>
              (product.discountPercentage != null ||
                  product.isFlashSaleUpcoming) &&
              !product.sellerOnVacation &&
              !product.isOutOfStock &&
              !product.isFlashSaleExpired,
        )
        .take(4)
        .toList(growable: false);
    final sections = <Widget>[
      if (_loadingProducts) const AppLoadingLine(),
      _buildHero(),
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
      if (_loadingProducts && featuredProducts.isEmpty)
        const ProductGridSkeleton()
      else if (featuredProducts.isEmpty)
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
          onSellerSelected: widget.onSellerSelected,
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
        widget.onViewFlashDeals ?? widget.onShopDeals,
      ),
      const SizedBox(height: 12),
      if (currentDealProducts.isNotEmpty)
        _ProductGrid(
          products: currentDealProducts,
          isWishlisted: (product) => _wishlistIds.contains(product.id),
          isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
          onProductSelected: widget.onProductSelected,
          onSellerSelected: widget.onSellerSelected,
          onWishlistProduct: _toggleWishlist,
        )
      else if (_loadingDeals)
        const ProductGridSkeleton()
      else
        _buildHomeEmptyState(
          title: 'No discounted products are available right now',
          description: 'Check back later for current seller discounts.',
        ),
      const SizedBox(height: 30),
      _buildHeaderRow(
        'For You',
        'Recommended For You',
        'Products based on popular buyer choices.',
        'See All',
        widget.onViewRecommended,
      ),
      const SizedBox(height: 16),
      if (_loadingProducts && recommendedProducts.isEmpty)
        const ProductGridSkeleton()
      else if (recommendedProducts.isEmpty)
        _buildHomeEmptyState(
          title: 'More recommendations will appear here',
          description:
              'Explore products to help us prepare recommendations for you.',
          actionLabel: 'Explore Products',
          onAction: widget.onBrowseProducts,
        )
      else
        _ProductGrid(
          products: recommendedProducts,
          isWishlisted: (product) => _wishlistIds.contains(product.id),
          isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
          onProductSelected: widget.onProductSelected,
          onSellerSelected: widget.onSellerSelected,
          onWishlistProduct: _toggleWishlist,
        ),
    ];
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1080),
              child: SizedBox(width: double.infinity, child: sections[index]),
            ),
          ),
          childCount: sections.length,
        ),
      ),
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
        color: AppTheme.resolve(context, card, fill: true),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.resolve(context, border)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.storefront_outlined,
            color: AppTheme.resolve(context, maroonLight),
            size: 30,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.resolve(context, text),
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.resolve(context, muted),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (actionLabel != null) ...[
            const SizedBox(height: 14),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.resolve(context, maroon, fill: true),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
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
        gradient: LinearGradient(
          colors: <Color>[
            AppTheme.resolve(context, ShopColors.accentDark, fill: true),
            AppTheme.resolve(context, ShopColors.accent, fill: true),
            AppTheme.resolve(context, ShopColors.accentLight, fill: true),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppTheme.resolve(
              context,
              ShopColors.accentDark,
            ).withValues(alpha: .14),
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
                Text(
                  'CURRENT DISCOUNTS',
                  style: TextStyle(
                    color: AppTheme.resolve(context, Color(0xFFE9C7A5)),
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
                Text(
                  'Browse products with current seller discounts.',
                  style: TextStyle(
                    color: AppTheme.resolve(context, Color(0xFFF4DED4)),
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
                    backgroundColor: AppTheme.resolve(
                      context,
                      const Color(0xFFFFF7EF),
                      fill: true,
                    ),
                    foregroundColor: AppTheme.resolve(
                      context,
                      ShopColors.accentDark,
                    ),
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

  dynamic _platformEventField(Map<String, dynamic> event, String key) {
    final dynamic value = event[key];
    if (value != null) return value;
    final dynamic voucher = event['voucher'];
    return voucher is Map ? voucher[key] : null;
  }

  String _platformEventStatus(Map<String, dynamic> event) {
    final DateTime now = DateTime.now();
    final DateTime? startsAt = DateTime.tryParse(
      (_platformEventField(event, 'starts_at') ?? '').toString(),
    );
    final DateTime? endsAt = DateTime.tryParse(
      (_platformEventField(event, 'ends_at') ?? '').toString(),
    );
    final String rawStatus = (_platformEventField(event, 'status') ?? '')
        .toString()
        .trim()
        .toLowerCase();

    if (<String>{
      'inactive',
      'cancelled',
      'canceled',
      'paused',
      'draft',
    }.contains(rawStatus)) {
      return 'inactive';
    }
    if (<String>{
      'expired',
      'ended',
      'finished',
      'complete',
      'completed',
    }.contains(rawStatus)) {
      return 'expired';
    }
    if (endsAt != null && !endsAt.isAfter(now)) return 'expired';
    if (startsAt != null && startsAt.isAfter(now)) return 'upcoming';
    if (<String>{'active', 'live', 'ongoing', 'running'}.contains(rawStatus)) {
      return 'active';
    }
    if (<String>{'upcoming', 'scheduled', 'pending'}.contains(rawStatus)) {
      return startsAt == null ? 'upcoming' : 'active';
    }
    if (startsAt != null && !startsAt.isAfter(now)) return 'active';
    return 'unknown';
  }

  String _platformEventEligibility(Map<String, dynamic> event) {
    for (final String key in <String>[
      'eligibility',
      'eligibility_description',
      'applies_to_label',
      'benefit_scope',
    ]) {
      final dynamic value = _platformEventField(event, key);
      if (value is Map) {
        final Map<String, dynamic> row = Map<String, dynamic>.from(value);
        final String label =
            (row['description'] ?? row['label'] ?? row['name'] ?? '')
                .toString()
                .trim();
        if (label.isNotEmpty) return label;
      } else if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    for (final String key in <String>[
      'eligible_products',
      'products',
      'eligible_product_names',
      'eligible_product_ids',
    ]) {
      final dynamic value = _platformEventField(event, key);
      final List<dynamic> rows = value is List ? value : <dynamic>[value];
      final List<String> labels = rows
          .map((dynamic row) {
            if (row is Map) {
              final Map<String, dynamic> product = Map<String, dynamic>.from(
                row,
              );
              return (product['name'] ??
                      product['product_name'] ??
                      product['title'] ??
                      product['label'] ??
                      (product['id'] == null
                          ? ''
                          : 'Product #${product['id']}'))
                  .toString()
                  .trim();
            }
            final String label = row?.toString().trim() ?? '';
            return key == 'eligible_product_ids' && label.isNotEmpty
                ? 'Product #$label'
                : label;
          })
          .where((String label) => label.isNotEmpty)
          .toList(growable: false);
      if (labels.isNotEmpty) return labels.join(', ');
    }

    if (_platformEventField(event, 'eligible_for_all_products') == true ||
        _platformEventField(event, 'applies_to')?.toString().toLowerCase() ==
            'all_products') {
      return 'All eligible products';
    }
    return 'Eligibility details were not provided';
  }

  String _platformEventDestination(Map<String, dynamic> event) {
    for (final String key in <String>[
      'reward_destination',
      'destination_label',
      'destination',
      'reward_target',
    ]) {
      final dynamic value = _platformEventField(event, key);
      final String label = value is Map
          ? ((value['label'] ?? value['name'] ?? value['title'] ?? '')
                .toString()
                .trim())
          : (value?.toString().trim() ?? '');
      if (label.isNotEmpty) return label;
    }
    if (_platformEventField(event, 'code') != null) {
      return 'Collected vouchers are saved to Rewards';
    }
    return '';
  }

  int? _platformEventVoucherId(Map<String, dynamic> event) {
    final dynamic voucher = event['voucher'];
    final dynamic value =
        event['voucher_id'] ?? (voucher is Map ? voucher['id'] : null);
    return int.tryParse((value ?? '').toString());
  }

  String _formatCampaignDate(DateTime date) {
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
    final DateTime localDate = date.toLocal();
    final int hour = localDate.hour % 12 == 0 ? 12 : localDate.hour % 12;
    final String minute = localDate.minute.toString().padLeft(2, '0');
    final String period = localDate.hour < 12 ? 'AM' : 'PM';
    return '${months[localDate.month - 1]} ${localDate.day}, ${localDate.year} $hour:$minute $period';
  }

  void _showPlatformEventDetails(Map<String, dynamic> event) {
    final String title = (event['title'] ?? 'Platform event').toString();
    final dynamic voucher = event['voucher'];
    final dynamic rawTerms =
        _platformEventField(event, 'terms') ?? event['body'];
    final String body = rawTerms is List
        ? rawTerms.map((dynamic term) => term.toString()).join('\n')
        : rawTerms is Map
        ? (rawTerms['description'] ??
                  rawTerms['text'] ??
                  rawTerms['label'] ??
                  '')
              .toString()
        : (rawTerms ?? '').toString();
    final String code = (_platformEventField(event, 'code') ?? '')
        .toString()
        .trim();
    final int? voucherId = _platformEventVoucherId(event);
    final String status = _platformEventStatus(event);
    final bool claimedFromServer =
        _platformEventField(event, 'claimed') == true ||
        _platformEventField(event, 'is_claimed') == true ||
        (voucher is Map &&
            (voucher['claimed'] == true || voucher['is_claimed'] == true));
    if (claimedFromServer && voucherId != null) {
      _claimedPlatformEvents.add(voucherId);
    }
    final DateTime? startsAt = DateTime.tryParse(
      (_platformEventField(event, 'starts_at') ?? '').toString(),
    );
    final DateTime? endsAt = DateTime.tryParse(
      (_platformEventField(event, 'ends_at') ?? '').toString(),
    );
    final String destination = _platformEventDestination(event);
    final String statusLabel = status == 'unknown'
        ? 'Unknown'
        : '${status[0].toUpperCase()}${status.substring(1)}';
    final Color statusColor = switch (status) {
      'active' => AppTheme.resolve(context, const Color(0xFF256F4A)),
      'upcoming' => AppTheme.resolve(context, const Color(0xFF8A5A12)),
      'expired' ||
      'inactive' => AppTheme.resolve(context, const Color(0xFF8B3B35)),
      _ => AppTheme.resolve(context, muted),
    };
    final String validPeriod =
        '${startsAt == null ? 'Start time not provided' : _formatCampaignDate(startsAt)} \u2013 ${endsAt == null ? 'No end date' : _formatCampaignDate(endsAt)}';

    Widget detailBlock(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label.toUpperCase(),
          style: TextStyle(
            color: muted2,
            fontSize: 9,
            letterSpacing: .8,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: text, fontSize: 13, height: 1.4)),
      ],
    );

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: AppTheme.resolve(context, card, fill: true),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      clipBehavior: Clip.antiAlias,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) => SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'PLATFORM EVENT',
                    style: TextStyle(
                      color: AppTheme.resolve(context, maroon),
                      fontSize: 9,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: AppTheme.resolve(context, text),
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: .10),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.resolve(
                        context,
                        backgroundSoft,
                        fill: true,
                      ).withValues(alpha: .55),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: AppTheme.resolve(context, border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        detailBlock('Valid period', validPeriod),
                        const SizedBox(height: 14),
                        detailBlock(
                          'Eligibility',
                          _platformEventEligibility(event),
                        ),
                        if (destination.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 14),
                          detailBlock('Reward destination', destination),
                        ],
                      ],
                    ),
                  ),
                  if (body.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    detailBlock('About this event', body.trim()),
                  ],
                  if (code.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppTheme.resolve(
                          context,
                          maroon,
                          fill: true,
                        ).withValues(alpha: .07),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: AppTheme.resolve(
                            context,
                            maroon,
                          ).withValues(alpha: .18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            'VOUCHER CODE',
                            style: TextStyle(
                              color: AppTheme.resolve(context, maroon),
                              fontSize: 9,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SelectableText(
                            code,
                            style: TextStyle(
                              color: AppTheme.resolve(context, text),
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (voucherId != null &&
                      status == 'active' &&
                      AppConfig.apiEnabled) ...<Widget>[
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed:
                            _claimingPlatformEvents.contains(voucherId) ||
                                claimedFromServer ||
                                _claimedPlatformEvents.contains(voucherId)
                            ? null
                            : () async {
                                if (context.mounted) {
                                  setModalState(
                                    () =>
                                        _claimingPlatformEvents.add(voucherId),
                                  );
                                }
                                try {
                                  if (!claimedFromServer &&
                                      !_claimedPlatformEvents.contains(
                                        voucherId,
                                      )) {
                                    await BuyerMobileService.claimVoucher(
                                      voucherId,
                                    );
                                  }
                                  _claimedPlatformEvents.add(voucherId);
                                  if (mounted) setState(() {});
                                  if (context.mounted) setModalState(() {});
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Platform voucher added to your Rewards.',
                                        ),
                                      ),
                                    );
                                  }
                                } catch (error) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(content: Text(error.toString())),
                                    );
                                  }
                                } finally {
                                  _claimingPlatformEvents.remove(voucherId);
                                  if (context.mounted) setModalState(() {});
                                }
                              },
                        icon: _claimingPlatformEvents.contains(voucherId)
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(
                                (claimedFromServer ||
                                        _claimedPlatformEvents.contains(
                                          voucherId,
                                        ))
                                    ? Icons.check_circle_outline
                                    : Icons.card_giftcard_outlined,
                              ),
                        label: Text(
                          _claimingPlatformEvents.contains(voucherId)
                              ? 'Collecting'
                              : (claimedFromServer ||
                                    _claimedPlatformEvents.contains(voucherId))
                              ? 'Added to Rewards'
                              : 'Collect voucher',
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
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
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 8),
            itemBuilder: (BuildContext context, int index) {
              final BuyerHomeCategory category = categories[index];
              return SizedBox(
                width: 92,
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
        label: 'Free Gifts',
        description: 'Buy and get rewards',
        icon: Icons.card_giftcard_outlined,
        onTap: widget.onViewFreeGifts ?? widget.onViewSellerOffers,
      ),
      _BuyerQuickAction(
        label: 'Bundle Deals',
        description: 'Save when you shop together',
        icon: Icons.layers_outlined,
        onTap: widget.onViewBundleDeals ?? widget.onViewSellerOffers,
      ),
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
        label: 'Vouchers',
        description: 'Available vouchers',
        icon: Icons.card_giftcard_outlined,
        onTap: widget.onVouchers,
      ),
      _BuyerQuickAction(
        label: 'Discounts',
        description: 'Shop lower prices',
        icon: Icons.local_offer_outlined,
        onTap: widget.onShopDeals,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 1180
            ? actions.length
            : constraints.maxWidth >= 680
            ? 3
            : 2;
        final double spacing = constraints.maxWidth >= 680 ? 14 : 10;
        final double cardWidth =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
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

  Widget _buildHero() {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool compact = width < 620;
        final bool narrow = width < 360;
        final bool dark = Theme.of(context).brightness == Brightness.dark;
        final double heroHeight = compact
            ? (width * 0.94).clamp(320.0, 370.0).toDouble()
            : (width * 0.38).clamp(350.0, 430.0).toDouble();
        final Map<String, dynamic>? event = _heroEvent;

        return Container(
          height: heroHeight,
          width: double.infinity,
          decoration: BoxDecoration(
            color: dark ? const Color(0xFF171210) : const Color(0xFFF5E8DA),
            borderRadius: BorderRadius.circular(18),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.20 : 0.08),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                PageView(
                  controller: _heroPageController,
                  onPageChanged: (int page) {
                    if (_heroPage != page && mounted) {
                      setState(() => _heroPage = page);
                    }
                    _scheduleHeroAdvance();
                  },
                  children: <Widget>[
                    _buildHeroSlide(
                      width: width,
                      compact: compact,
                      narrow: narrow,
                      dark: dark,
                      event: null,
                      campaignSlide: false,
                    ),
                    _buildHeroSlide(
                      width: width,
                      compact: compact,
                      narrow: narrow,
                      dark: dark,
                      event: event,
                      campaignSlide: true,
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroSlide({
    required double width,
    required bool compact,
    required bool narrow,
    required bool dark,
    required Map<String, dynamic>? event,
    required bool campaignSlide,
  }) {
    final bool isEvent = campaignSlide && event != null;
    final double titleSize = compact
        ? (narrow ? 42.0 : 46.0)
        : (width < 900 ? 62.0 : 68.0);
    final Color titleColor = dark
        ? const Color(0xFFF5ECE7)
        : const Color(0xFF171311);
    final Color accentColor = dark
        ? const Color(0xFFE0A89E)
        : const Color(0xFF561C17);
    final Color descriptionColor = dark
        ? const Color(0xFFD1B09D)
        : const Color(0xFF561C17);
    final Color buttonColor = dark
        ? const Color(0xFF8E5048)
        : const Color(0xFF561C17);
    final List<Color> overlayColors = dark
        ? <Color>[
            const Color(0xFF171210).withValues(alpha: 0.96),
            const Color(0xFF171210).withValues(alpha: 0.91),
            const Color(0xFF171210).withValues(alpha: 0.76),
            const Color(0xFF171210).withValues(alpha: 0.45),
            const Color(0xFF171210).withValues(alpha: 0.12),
            Colors.transparent,
          ]
        : <Color>[
            const Color(0xFFFFFBF6).withValues(alpha: 0.99),
            const Color(0xFFFFFBF6).withValues(alpha: 0.96),
            const Color(0xFFFFFBF6).withValues(alpha: 0.88),
            const Color(0xFFFFFBF6).withValues(alpha: 0.66),
            const Color(0xFFFFFBF6).withValues(alpha: 0.30),
            Colors.transparent,
          ];
    final Map<String, dynamic> activeEvent = event ?? <String, dynamic>{};
    final String campaignTitle = isEvent
        ? (activeEvent['title'] ?? 'Marketplace event').toString().trim()
        : 'Find your\nnext favorite.';
    final String campaignDescription = isEvent
        ? _heroEventDescription(activeEvent)
        : 'Meet thoughtful finds from local sellers, made for the everyday.';
    final String campaignButtonLabel = isEvent
        ? 'View Event'
        : 'Explore featured finds';
    final VoidCallback? onTap = isEvent
        ? () => _showPlatformEventDetails(activeEvent)
        : campaignSlide
        ? (widget.onViewFeatured ?? widget.onBrowseProducts)
        : widget.onBrowseProducts;
    final String watermarkText =
        isEvent && campaignTitle.toLowerCase().contains('11:11')
        ? '11:11\nSALE'
        : isEvent
        ? campaignTitle.toUpperCase()
        : 'FINDS';

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          campaignSlide
              ? 'assets/home/hero_campaign_event.png'
              : 'assets/home/hero_editorial.jpg',
          fit: BoxFit.cover,
          alignment: compact ? const Alignment(0.76, 0) : Alignment.centerRight,
          filterQuality: FilterQuality.medium,
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: overlayColors,
              stops: const <double>[0, 0.22, 0.40, 0.60, 0.82, 1],
            ),
          ),
        ),
        if (campaignSlide)
          Positioned(
            left: compact ? width * 0.12 : width * 0.11,
            top: compact ? 10 : 4,
            child: IgnorePointer(
              child: Text(
                watermarkText,
                maxLines: 2,
                overflow: TextOverflow.fade,
                style: TextStyle(
                  color: accentColor.withValues(alpha: dark ? 0.10 : 0.07),
                  fontFamily: 'serif',
                  fontSize: compact
                      ? (narrow ? 72 : 82)
                      : (width < 900 ? 118 : 148),
                  fontWeight: FontWeight.w700,
                  letterSpacing: -5,
                  height: 0.78,
                ),
              ),
            ),
          ),
        if (isEvent)
          Positioned(
            top: compact ? 7 : 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Text(
                'LIKHAE',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: accentColor.withValues(alpha: dark ? 0.10 : 0.07),
                  fontSize: compact ? 17 : 36,
                  fontWeight: FontWeight.w500,
                  letterSpacing: compact ? 4 : 7,
                ),
              ),
            ),
          ),
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 22 : 38,
            vertical: compact ? 24 : 34,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: width * (compact ? 0.82 : 0.48),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (campaignSlide) ...<Widget>[
                      Text(
                        isEvent
                            ? 'LIKHAE MARKETPLACE EVENT'
                            : 'LOCAL FINDS FOR EVERYDAY',
                        style: TextStyle(
                          color: accentColor,
                          fontSize: compact ? 9 : 10,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: compact ? 8 : 12),
                      Text(
                        campaignTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accentColor,
                          fontFamily: 'serif',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -1.6,
                          height: 0.98,
                        ),
                      ),
                    ] else
                      Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            const TextSpan(text: 'Everything\nfor your\n'),
                            TextSpan(
                              text: 'everyday.',
                              style: TextStyle(color: accentColor),
                            ),
                          ],
                        ),
                        style: TextStyle(
                          color: titleColor,
                          fontFamily: 'serif',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w400,
                          letterSpacing: -1.6,
                          height: 0.94,
                        ),
                      ),
                    SizedBox(height: compact ? 12 : 16),
                    Text(
                      campaignSlide
                          ? campaignDescription
                          : 'Browse the things you need, and a few things you\'ll love.',
                      maxLines: compact ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: descriptionColor,
                        fontSize: compact ? 12 : 14,
                        height: 1.55,
                      ),
                    ),
                    SizedBox(height: compact ? 16 : 20),
                    Material(
                      color: buttonColor,
                      borderRadius: BorderRadius.circular(7),
                      child: InkWell(
                        onTap: onTap,
                        borderRadius: BorderRadius.circular(7),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: compact ? 17 : 22,
                            vertical: compact ? 12 : 14,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                campaignSlide
                                    ? campaignButtonLabel
                                    : 'Shop all products',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: compact ? 12 : 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 15),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                color: Colors.white,
                                size: 17,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _heroEventDescription(Map<String, dynamic> event) {
    final double? discount = double.tryParse(
      (_platformEventField(event, 'discount_value') ?? '').toString(),
    );
    final String discountType =
        (_platformEventField(event, 'discount_type') ?? '')
            .toString()
            .toUpperCase();
    if (discount != null && discount > 0) {
      String amountLabel(double amount) => amount == amount.roundToDouble()
          ? formatGroupedMoney(amount, decimalDigits: 0)
          : formatGroupedMoney(amount, trimTrailingZeros: true);
      final bool percentage = discountType == 'PERCENT';
      final String benefit = percentage
          ? '${amountLabel(discount)}% off'
          : '₱${amountLabel(discount)} off';
      final double? minimumSpend = double.tryParse(
        (_platformEventField(event, 'minimum_order_amount') ?? '').toString(),
      );
      final double? maximumSavings = double.tryParse(
        (_platformEventField(event, 'maximum_discount_amount') ?? '')
            .toString(),
      );
      final String minimumText = minimumSpend != null && minimumSpend > 0
          ? ' with a ₱${amountLabel(minimumSpend)} minimum spend'
          : '';
      final String maximumText = maximumSavings != null && maximumSavings > 0
          ? ' Save up to ₱${amountLabel(maximumSavings)}.'
          : '';
      return '$benefit$minimumText.$maximumText';
    }
    for (final String key in <String>['description', 'body', 'summary']) {
      final String value = (event[key] ?? '').toString().trim();
      if (value.isNotEmpty) return value;
    }
    return 'Explore the event details, offers, and eligibility.';
  }

  Widget _buildHeaderRow(
    String kicker,
    String title,
    String subtitle,
    String actionText,
    VoidCallback? onAction,
  ) {
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
                  color: AppTheme.resolve(context, maroonLight),
                  fontSize: 9,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.resolve(context, text),
                  fontSize: 19,
                  height: 1.15,
                  letterSpacing: -0.35,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: TextStyle(
                  color: AppTheme.resolve(context, muted),
                  fontSize: 11,
                  height: 1.4,
                ),
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
            foregroundColor: AppTheme.resolve(context, maroon),
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            visualDensity: VisualDensity.compact,
            textStyle: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
            ),
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
  final BuyerHomeProductCallback? onSellerSelected;
  final BuyerHomeWishlistCallback onWishlistProduct;

  const _ProductGrid({
    required this.products,
    required this.isWishlisted,
    required this.isWishlistLoading,
    required this.onProductSelected,
    required this.onSellerSelected,
    required this.onWishlistProduct,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int columns = constraints.maxWidth >= 940
            ? 4
            : constraints.maxWidth >= 660
            ? 3
            : constraints.maxWidth < 290 ||
                  MediaQuery.textScalerOf(context).scale(14) > 24
            ? 1
            : 2;
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
                  onSellerTap: onSellerSelected == null
                      ? null
                      : () => onSellerSelected!(product),
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
  final VoidCallback? onSellerTap;
  final VoidCallback onWishlist;

  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.wishlistLoading,
    required this.onTap,
    required this.onSellerTap,
    required this.onWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final bool saleEnded = product.isFlashSaleExpired;
    final DateTime now = DateTime.now();
    final DateTime? startsAt = product.flashSaleStartsAt?.toLocal();
    final DateTime? endsAt = product.flashSaleEndsAt?.toLocal();
    final String? saleLabel = saleEnded
        ? 'Flash sale ended; refresh price'
        : startsAt != null && startsAt.isAfter(now)
        ? 'Sale starts ${_formatSaleDate(context, startsAt)}'
        : endsAt != null
        ? 'Sale ends ${_formatSaleDate(context, endsAt)}'
        : product.isFlashSaleActive
        ? 'Flash sale active'
        : null;
    return ShopProductCard(
      key: ValueKey(product.id),
      image: _ProductGallery(images: product.galleryImages),
      imageAspectRatio: 1.0,
      imageBadge: product.isFeatured ? 'Likhae Pick' : null,
      name: product.name,
      category: product.category,
      seller: product.sellerName,
      price: saleEnded ? product.originalPrice ?? product.price : product.price,
      originalPrice: saleEnded ? null : product.originalPrice,
      priceLabel: saleEnded && product.originalPrice == null
          ? 'Refresh for price'
          : null,
      rating: product.rating,
      soldCount: product.soldCount,
      outOfStock: product.isOutOfStock || product.sellerOnVacation || saleEnded,
      availabilityLabel: product.sellerOnVacation
          ? 'Seller on vacation'
          : saleLabel,
      wishlisted: isWishlisted,
      wishlistLoading: wishlistLoading,
      onTap: onTap,
      onSellerTap: onSellerTap,
      onWishlist: onWishlist,
    );
  }

  String _formatSaleDate(BuildContext context, DateTime date) {
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
    return '${months[date.month - 1]} ${date.day} at ${TimeOfDay.fromDateTime(date).format(context)}';
  }
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
          color: AppTheme.resolve(context, _BuyerHomeScreenState.muted2),
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
                        ? AppTheme.resolve(
                            context,
                            _BuyerHomeScreenState.maroon,
                            fill: true,
                          )
                        : AppTheme.resolve(
                            context,
                            _BuyerHomeScreenState.muted2,
                            fill: true,
                          ).withValues(alpha: 0.55),
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
      return Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: AppTheme.resolve(context, ShopColors.faint),
          size: 34,
        ),
      );
    }
    return SizedNetworkImage(
      url: AppConfig.resolveMediaUrl(value),
      fit: BoxFit.cover,
      iconSize: 34,
    );
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
        color: AppTheme.resolve(
          context,
          _BuyerHomeScreenState.card,
          fill: true,
        ),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            height: 116,
            padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.resolve(context, _BuyerHomeScreenState.border),
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.backgroundSoft,
                      fill: true,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 22,
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.maroonLight,
                    ),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  category.name,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.text,
                    ),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Explore',
                  style: TextStyle(
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.muted,
                    ),
                    fontSize: 9,
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
        color: AppTheme.resolve(
          context,
          _BuyerHomeScreenState.card,
          fill: true,
        ),
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 92,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(
                color: AppTheme.resolve(context, _BuyerHomeScreenState.border),
              ),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.backgroundSoft,
                      fill: true,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    action.icon,
                    size: 22,
                    color: AppTheme.resolve(
                      context,
                      _BuyerHomeScreenState.maroon,
                    ),
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
                          color: AppTheme.resolve(
                            context,
                            _BuyerHomeScreenState.text,
                          ),
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
                          color: AppTheme.resolve(
                            context,
                            _BuyerHomeScreenState.muted,
                          ),
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

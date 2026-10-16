import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:likhae/core/theme/app_theme.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/product_service.dart';
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
  final bool isFeatured;
  final bool isRecommended;
  final bool wishlisted;

  const BuyerHomeProduct({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.sellerName,
    this.sellerSlug,
    this.sellerUserId,
    this.imageUrl,
    this.imageUrls = const <String>[],
    this.originalPrice,
    this.rating,
    this.soldCount = 0,
    this.stock,
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

  static BuyerHomeProduct fromApi(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['db_id'];
    final dynamic rawName = json['name'];
    final dynamic rawPrice = json['price'] ?? json['min_price'];
    if (rawId == null || rawName == null || rawPrice == null) {
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
    final String imageValue = (json['image_url'] ??
            json['image'] ??
            primaryImage?['url'] ??
            primaryImage?['file_path'] ??
            '')
        .toString()
        .trim();
    final List<String> galleryImages = _parseImageUrls(
      json['images'] ?? json['gallery'] ?? json['photos'],
    );
    final List<String> resolvedImages = <String>[];
    for (final String value in <String>[imageValue, ...galleryImages]) {
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
      sellerName: sellerValue.isEmpty ? null : sellerValue,
      sellerUserId: int.tryParse(
        (seller?['user_id'] ?? json['seller_user_id'] ?? '').toString(),
      ),
      imageUrl: resolvedImages.isEmpty
          ? null
          : resolvedImages.first,
      imageUrls: resolvedImages,
      price: double.tryParse(rawPrice.toString()) ?? 0,
      originalPrice:
          double.tryParse(
            (json['old_price'] ?? json['original_price'])?.toString() ?? '',
          ),
      rating: double.tryParse((json['rating'] ?? '0').toString()),
      soldCount:
          int.tryParse(
            (json['sold'] ?? json['sold_count'] ?? '0').toString(),
          ) ??
          0,
      stock:
          int.tryParse(
            (json['stock'] ?? json['variant_stock'] ?? '0').toString(),
          ) ??
          0,
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

  const BuyerHomeCategory({required this.name, required this.slug, this.icon});
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
  final DateTime? flashSaleEndsAt;
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
    this.flashSaleEndsAt,
    this.cartItemCount = 0,
    this.unreadNotificationCount = 0,
  });

  @override
  State<BuyerHomeScreen> createState() => _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
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
  List<BuyerHomeProduct>? _featuredProductsCache;
  List<BuyerHomeProduct>? _recommendedProductsCache;
  BuyerHomeProduct? _heroProductCache;
  bool _heroProductCacheReady = false;

  @override
  void initState() {
    super.initState();
    _syncWishlistState();
    _invalidateProductCaches();
    if (widget.products.isEmpty) {
      _loadProducts();
    }
  }

  void _invalidateProductCaches() {
    _featuredProductsCache = null;
    _recommendedProductsCache = null;
    _heroProductCache = null;
    _heroProductCacheReady = false;
  }

  Future<void> _loadProducts() async {
    try {
      final List<BuyerHomeProduct> fetched =
          await ProductService.fetchHomeProducts();
      if (!mounted) return;
      setState(() {
        _loadedProducts = fetched;
        _invalidateProductCaches();
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to load products right now.')),
        );
      }
    }
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
    yield* widget.featuredProducts;
    yield* widget.recommendedProducts;
    final BuyerHomeProduct? hero = widget.heroProduct;
    if (hero != null) yield hero;
  }

  void _syncWishlistState() {
    final Set<int> incoming = <int>{};
    for (final BuyerHomeProduct product in _allKnownProducts) {
      if (product.wishlisted) incoming.add(product.id);
    }
    if (!AppConfig.apiEnabled) {
      incoming.addAll(WishlistService.localProductIds);
    }
    _wishlistIds
      ..clear()
      ..addAll(incoming);
  }

  List<BuyerHomeProduct> _shuffledProducts(List<BuyerHomeProduct> products) {
    final List<BuyerHomeProduct> copy = List<BuyerHomeProduct>.from(products);
    copy.shuffle();
    return copy;
  }

  List<BuyerHomeProduct> get _featuredProducts {
    final List<BuyerHomeProduct>? cached = _featuredProductsCache;
    if (cached != null) return cached;

    late final List<BuyerHomeProduct> result;
    if (widget.featuredProducts.isNotEmpty) {
      result = _shuffledProducts(widget.featuredProducts).take(4).toList();
    } else {
      final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
        ...widget.products,
        ..._loadedProducts,
      ];
      final List<BuyerHomeProduct> featured = baseProducts
          .where((BuyerHomeProduct product) => product.isFeatured)
          .toList();
      if (featured.isNotEmpty) {
        result = _shuffledProducts(featured).take(4).toList();
      } else if (baseProducts.isNotEmpty) {
        result = _shuffledProducts(baseProducts).take(4).toList();
      } else {
        result = <BuyerHomeProduct>[];
      }
    }
    return _featuredProductsCache = result;
  }

  List<BuyerHomeProduct> get _recommendedProducts {
    final List<BuyerHomeProduct>? cached = _recommendedProductsCache;
    if (cached != null) return cached;

    late final List<BuyerHomeProduct> result;
    if (widget.recommendedProducts.isNotEmpty) {
      result = _shuffledProducts(widget.recommendedProducts).take(4).toList();
    } else {
      final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
        ...widget.products,
        ..._loadedProducts,
      ];
      final List<BuyerHomeProduct> recs = baseProducts
          .where((BuyerHomeProduct product) => product.isRecommended)
          .toList();
      if (recs.isNotEmpty) {
        result = _shuffledProducts(recs).take(4).toList();
      } else if (baseProducts.isNotEmpty) {
        result = _shuffledProducts(baseProducts).take(4).toList();
      } else {
        result = <BuyerHomeProduct>[];
      }
    }
    return _recommendedProductsCache = result;
  }

  BuyerHomeProduct? get _heroProduct {
    if (_heroProductCacheReady) return _heroProductCache;

    if (widget.heroProduct != null) {
      _heroProductCache = widget.heroProduct;
      _heroProductCacheReady = true;
      return _heroProductCache;
    }
    final List<BuyerHomeProduct> featured = _featuredProducts;
    if (featured.isNotEmpty) {
      _heroProductCache = featured.first;
    } else {
      final List<BuyerHomeProduct> base = <BuyerHomeProduct>[
        ...widget.products,
        ..._loadedProducts,
      ];
      _heroProductCache = base.isEmpty ? null : _shuffledProducts(base).first;
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
            if (_wishlistIds.contains(product.id)) {
              _wishlistIds.remove(product.id);
            } else {
              _wishlistIds.add(product.id);
            }
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
              await _loadProducts();
            },
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: <Widget>[
                SliverToBoxAdapter(child: _buildHeader()),
                SliverToBoxAdapter(child: _buildMainContent()),
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
              Text('LIKHAE', style: TextStyle(color: text, fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: 2.2)),
              const SizedBox(height: 3),
              Text('Thoughtfully local.', style: TextStyle(color: muted, fontSize: 11.5)),
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
                Expanded(child: Text('Find your next favourite', style: TextStyle(color: muted, fontSize: 13))),
                Icon(Icons.tune_rounded, size: 19, color: muted),
              ])),
            ),
          ),
        ]),
      ),
    ));
  }

  Widget _buildMainContent() {
    return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1120),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 130),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          _buildHero(_heroProduct),
          const SizedBox(height: 16),
          _buildQuickActions(),
          const SizedBox(height: 30),
          _buildHeaderRow('CURATED', 'Worth a closer look', 'Featured finds from local sellers.', 'See all', widget.onViewFeatured),
          const SizedBox(height: 16),
          _ProductGrid(
            products: _featuredProducts,
            isWishlisted: (product) => _wishlistIds.contains(product.id),
            isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
            onProductSelected: widget.onProductSelected, onWishlistProduct: _toggleWishlist,
          ),
          const SizedBox(height: 30),
          _buildHeaderRow('FOR YOU', 'Picked for you', 'A little inspiration for your everyday.', 'See all', widget.onViewRecommended),
          const SizedBox(height: 16),
          _ProductGrid(
            products: _recommendedProducts,
            isWishlisted: (product) => _wishlistIds.contains(product.id),
            isWishlistLoading: (product) => _wishlistLoading.contains(product.id),
            onProductSelected: widget.onProductSelected, onWishlistProduct: _toggleWishlist,
          ),
        ]),
      ),
    ));
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
        label: 'Vouchers',
        description: 'Deals and rewards',
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
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [ShopColors.accentDark, ShopColors.accent, ShopColors.accentLight],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: ShopColors.accent.withValues(alpha: .13), blurRadius: 26, offset: const Offset(0, 10))],
      ),
      child: LayoutBuilder(builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;
        final copy = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('THE LOCAL EDIT', style: TextStyle(color: Color(0xFFE6C5BD), fontSize: 9.5, letterSpacing: 1.8, fontWeight: FontWeight.w600)),
          const SizedBox(height: 13),
          const Text('Good finds.\nLocal stories.', style: TextStyle(color: Colors.white, fontSize: 30, letterSpacing: -.9, height: 1.08, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          const Text('Discover something\nworth keeping.', style: TextStyle(color: Color(0xFFEEDBD4), fontSize: 12, height: 1.5)),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: widget.onBrowseProducts, icon: const Icon(Icons.arrow_forward_rounded, size: 17),
            iconAlignment: IconAlignment.end, label: const Text('Explore'),
            style: FilledButton.styleFrom(backgroundColor: ShopColors.surface, foregroundColor: ShopColors.accentDark,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
          ),
        ]);
        final photo = product == null ? null : Column(children: [
          GestureDetector(
            onTap: widget.onProductSelected == null ? null : () => widget.onProductSelected!(product),
            child: ClipRRect(borderRadius: BorderRadius.circular(20),
              child: AspectRatio(aspectRatio: .83, child: _ProductGallery(images: product.galleryImages))),
          ),
          const SizedBox(height: 10),
          Text(product.name, maxLines: 2, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 11, height: 1.4, fontWeight: FontWeight.w500)),
        ]);
        if (photo == null || largeText) return copy;
        return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Expanded(flex: 3, child: copy),
          const SizedBox(width: 16),
          Expanded(flex: 2, child: photo),
        ]);
      }),
    );
  }

  Widget _buildHeaderRow(String kicker, String title, String subtitle, String actionText, VoidCallback? onAction) {
    return ShopSectionTitle(title: title, subtitle: subtitle, actionLabel: actionText, onAction: onAction);
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
    name: product.name, category: product.category, seller: product.sellerName,
    price: product.price, originalPrice: product.originalPrice, rating: product.rating,
    soldCount: product.soldCount, outOfStock: product.isOutOfStock,
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
  final String url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final String imageUrl = url.trim();
    if (imageUrl.isEmpty) {
      return Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 34,
          color: _BuyerHomeScreenState.muted2,
        ),
      );
    }

    return Image(
      image: CachedNetworkImageProvider(imageUrl),
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 34,
          color: _BuyerHomeScreenState.muted2,
        ),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _BuyerHomeScreenState.maroon,
            ),
          ),
        );
      },
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

class _PrimaryActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _PrimaryActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: ElevatedButton.icon(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: _BuyerHomeScreenState.maroon,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        iconAlignment: IconAlignment.end,
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _OutlineActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  const _OutlineActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 45,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          foregroundColor: _BuyerHomeScreenState.maroon,
          padding: const EdgeInsets.symmetric(horizontal: 15),
          side: BorderSide(color: _BuyerHomeScreenState.tan),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon, size: 16),
        label: Text(
          label,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

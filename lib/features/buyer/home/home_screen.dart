import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/product_service.dart';
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
  static const Color background = Color(0xFFFBF7F2);
  static const Color card = Color(0xFFFFFDF9);
  static const Color border = Color(0xFFEADCCC);
  static const Color maroon = Color(0xFF561C17);
  static const Color maroonLight = Color(0xFF7A2A22);
  static const Color text = Color(0xFF3B211B);
  static const Color brown = Color(0xFF6C4936);
  static const Color muted = Color(0xFF987865);
  static const Color muted2 = Color(0xFFA99386);
  static const Color tan = Color(0xFFC19771);
  static const Color star = Color(0xFFC88418);
  final Set<int> _wishlistIds = <int>{};
  final Set<int> _wishlistLoading = <int>{};
  List<BuyerHomeProduct> _loadedProducts = <BuyerHomeProduct>[];

  @override
  void initState() {
    super.initState();
    _syncWishlistState();
    if (widget.products.isEmpty) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final List<BuyerHomeProduct> fetched =
          await ProductService.fetchHomeProducts();
      if (!mounted) return;
      setState(() {
        _loadedProducts = fetched;
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
    if (widget.featuredProducts.isNotEmpty) {
      return _shuffledProducts(widget.featuredProducts).take(4).toList();
    }

    final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
      ...widget.products,
      ..._loadedProducts,
    ];
    final List<BuyerHomeProduct> featured = baseProducts
        .where((BuyerHomeProduct product) => product.isFeatured)
        .toList();
    if (featured.isNotEmpty) {
      return _shuffledProducts(featured).take(4).toList();
    }
    if (baseProducts.isNotEmpty) {
      return _shuffledProducts(baseProducts).take(4).toList();
    }
    return <BuyerHomeProduct>[];
  }

  List<BuyerHomeProduct> get _recommendedProducts {
    if (widget.recommendedProducts.isNotEmpty) {
      return _shuffledProducts(widget.recommendedProducts).take(4).toList();
    }

    final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
      ...widget.products,
      ..._loadedProducts,
    ];
    final List<BuyerHomeProduct> recs = baseProducts
        .where((BuyerHomeProduct product) => product.isRecommended)
        .toList();
    if (recs.isNotEmpty) return _shuffledProducts(recs).take(4).toList();
    if (baseProducts.isNotEmpty) {
      return _shuffledProducts(baseProducts).take(4).toList();
    }
    return <BuyerHomeProduct>[];
  }

  BuyerHomeProduct? get _heroProduct {
    if (widget.heroProduct != null) return widget.heroProduct;
    final List<BuyerHomeProduct> featured = _featuredProducts;
    if (featured.isNotEmpty) return featured.first;
    final List<BuyerHomeProduct> base = <BuyerHomeProduct>[
      ...widget.products,
      ..._loadedProducts,
    ];
    if (base.isNotEmpty) return _shuffledProducts(base).first;
    return null;
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

    try {
      if (asyncCallback != null) {
        await asyncCallback(product);
      } else {
        syncCallback!.call(product);
      }

      if (!mounted) return;
      final bool wasWishlisted = _wishlistIds.contains(product.id);
      setState(() {
        if (wasWishlisted) {
          _wishlistIds.remove(product.id);
        } else {
          _wishlistIds.add(product.id);
        }
      });
    } catch (_) {
      // ignore for offline layout mode
    } finally {
      if (mounted) {
        setState(() {
          _wishlistLoading.remove(product.id);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BuyerNavigationFrame(
      currentIndex: 0,
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
    return Container(
      color: background,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Expanded(
                child: Text(
                  'LIKHAE',
                  style: TextStyle(
                    color: maroon,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Notifications',
                onPressed: widget.onNotifications,
                icon: const Icon(Icons.notifications_none_rounded, color: text),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Cart',
                onPressed: widget.onCart,
                icon: const Icon(Icons.shopping_bag_outlined, color: text),
              ),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: widget.onSearch,
            borderRadius: BorderRadius.circular(15),
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: border),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(Icons.search_rounded, size: 21, color: muted),
                  SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      'Search products, categories...',
                      style: TextStyle(
                        color: muted2,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Icon(Icons.tune_rounded, size: 19, color: brown),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    final BuyerHomeProduct? product = _heroProduct;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _buildHero(product),
          const SizedBox(height: 30),
          _buildHeaderRow(
            'CURATED',
            'Featured Products',
            'Top picks from trusted sellers.',
            'See All',
            widget.onViewFeatured,
          ),
          const SizedBox(height: 12),
          _ProductGrid(
            products: _featuredProducts,
            isWishlisted: (BuyerHomeProduct product) =>
                _wishlistIds.contains(product.id),
            isWishlistLoading: (BuyerHomeProduct product) =>
                _wishlistLoading.contains(product.id),
            onProductSelected: widget.onProductSelected,
            onWishlistProduct: _toggleWishlist,
          ),
          const SizedBox(height: 30),
          _buildHeaderRow(
            'FOR YOU',
            'Recommended For You',
            'Marketplace recommendations selected for this section.',
            'See All',
            widget.onViewRecommended,
          ),
          const SizedBox(height: 12),
          _ProductGrid(
            products: _recommendedProducts,
            isWishlisted: (BuyerHomeProduct product) =>
                _wishlistIds.contains(product.id),
            isWishlistLoading: (BuyerHomeProduct product) =>
                _wishlistLoading.contains(product.id),
            onProductSelected: widget.onProductSelected,
            onWishlistProduct: _toggleWishlist,
          ),
        ],
      ),
    );
  }

  Widget _buildHero(BuyerHomeProduct? product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            Color(0xFFFFFDF9),
            Color(0xFFF6EFE7),
            Color(0xFFEFE7DE),
          ],
        ),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'YOUR MARKETPLACE',
            style: TextStyle(
              color: maroonLight,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.6,
            ),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              children: <InlineSpan>[
                const TextSpan(
                  text: 'Discover something\n',
                  style: TextStyle(
                    color: maroon,
                    fontSize: 34,
                    height: 0.98,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                TextSpan(
                  text: 'worth keeping.',
                  style: TextStyle(
                    color: maroonLight,
                    fontSize: 34,
                    height: 0.98,
                    letterSpacing: -1.1,
                    fontWeight: FontWeight.w700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            product == null
                ? 'Explore meaningful products from local sellers across LIKHAE.'
                : product.name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: text, fontSize: 12.5, height: 1.5),
          ),
          if (product != null) ...<Widget>[
            const SizedBox(height: 7),
            Row(
              children: <Widget>[
                Text(
                  '₱${product.price.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: maroon,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (product.originalPrice != null &&
                    product.originalPrice! > product.price) ...<Widget>[
                  const SizedBox(width: 7),
                  Text(
                    '₱${product.originalPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: muted2,
                      fontSize: 10,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ],
              ],
            ),
          ],
          const SizedBox(height: 18),
          Wrap(
            spacing: 9,
            runSpacing: 9,
            children: <Widget>[
              _PrimaryActionButton(
                label: 'Shop Now',
                icon: Icons.arrow_forward_rounded,
                onTap: widget.onBrowseProducts,
              ),
              _OutlineActionButton(
                label: 'My Orders',
                icon: Icons.receipt_long_outlined,
                onTap: widget.onViewOrders,
              ),
              if (product != null && widget.onProductSelected != null)
                _OutlineActionButton(
                  label: 'View Product',
                  icon: Icons.visibility_outlined,
                  onTap: () => widget.onProductSelected!(product),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderRow(
    String kicker,
    String title,
    String subtitle,
    String actionText,
    VoidCallback? onAction,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                kicker,
                style: const TextStyle(
                  color: maroon,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: text,
                  fontSize: 25,
                  height: 1.03,
                  letterSpacing: -0.7,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                subtitle,
                style: const TextStyle(
                  color: muted,
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
        TextButton(
          onPressed: onAction,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                actionText,
                style: const TextStyle(
                  color: brown,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_forward_rounded, size: 14, color: brown),
            ],
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
        final int columns = constraints.maxWidth < 330 ? 1 : 2;
        const double spacing = 10;
        final double itemWidth =
            (constraints.maxWidth - ((columns - 1) * spacing)) / columns;

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Wrap(
            spacing: spacing,
            runSpacing: 12,
            textDirection: TextDirection.rtl,
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

  const _ProductCard({
    required this.product,
    required this.isWishlisted,
    required this.wishlistLoading,
    required this.onTap,
    required this.onWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final double? discount = product.discountPercentage;
    return Material(
      color: const Color(0xFFFFFDF9),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEADCCC)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    Container(
                      color: const Color(0xFFF3ECE4),
                      child: _ProductGallery(images: product.galleryImages),
                    ),
                    if (discount != null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: _BuyerHomeScreenState.maroon,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '-${discount.round()}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.93),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: wishlistLoading ? null : onWishlist,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 34,
                            height: 34,
                            child: wishlistLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(8),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: _BuyerHomeScreenState.maroon,
                                    ),
                                  )
                                : Icon(
                                    isWishlisted
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: _BuyerHomeScreenState.maroon,
                                  ),
                          ),
                        ),
                      ),
                    ),
                    if (product.isOutOfStock)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.42),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.64),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 11, 11, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    if (product.category?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      Text(
                        product.category!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BuyerHomeScreenState.brown,
                          fontSize: 9,
                          letterSpacing: 0.7,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BuyerHomeScreenState.text,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (product.sellerName?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      const SizedBox(height: 5),
                      Text(
                        product.sellerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _BuyerHomeScreenState.muted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 3,
                      children: <Widget>[
                        Text(
                          '₱${product.price.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color: _BuyerHomeScreenState.maroon,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price)
                          Text(
                            '₱${product.originalPrice!.toStringAsFixed(2)}',
                            style: const TextStyle(
                              color: _BuyerHomeScreenState.muted2,
                              fontSize: 9.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        if (product.rating != null) ...<Widget>[
                          const Icon(
                            Icons.star_rounded,
                            color: _BuyerHomeScreenState.star,
                            size: 14,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            product.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: _BuyerHomeScreenState.text,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        Expanded(
                          child: Text(
                            '${product.soldCount} sold',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _BuyerHomeScreenState.muted,
                              fontSize: 9.5,
                            ),
                          ),
                        ),
                        if (product.stock != null && !product.isOutOfStock)
                          Text(
                            '${product.stock} left',
                            style: const TextStyle(
                              color: _BuyerHomeScreenState.muted,
                              fontSize: 9,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
      return const Center(
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
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          size: 34,
          color: _BuyerHomeScreenState.muted2,
        ),
      );
    }

    return Image.network(
      imageUrl,
      fit: BoxFit.contain,
      alignment: Alignment.center,
      errorBuilder: (_, _, _) => const Center(
        child: Icon(
          Icons.broken_image_outlined,
          size: 34,
          color: _BuyerHomeScreenState.muted2,
        ),
      ),
      loadingBuilder: (_, child, progress) {
        if (progress == null) return child;
        return const Center(
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
          side: const BorderSide(color: _BuyerHomeScreenState.tan),
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/product_service.dart';

typedef BuyerHomeProductCallback = void Function(
  BuyerHomeProduct product,
);

typedef BuyerHomeWishlistCallback = Future<void> Function(
  BuyerHomeProduct product,
);

typedef BuyerHomeCategoryCallback = void Function(
  String categorySlug,
);

typedef BuyerHomeRefreshCallback = Future<void> Function();

class BuyerHomeProduct {
  final int id;

  final String name;
  final String? slug;

  final String? category;

  final String? sellerName;
  final String? sellerSlug;

  final String? imageUrl;

  final double price;
  final double? originalPrice;

  final double? rating;

  final int soldCount;

  /// null = stock information was not supplied to this page.
  ///
  /// 0 = explicitly out of stock.
  ///
  /// > 0 = available stock.
  final int? stock;

  /// These values should eventually come from Laravel rather
  /// than being decided by this screen.
  final bool isFeatured;
  final bool isRecommended;

  /// The actual wishlist state supplied by the parent/API.
  final bool wishlisted;

  const BuyerHomeProduct({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.sellerName,
    this.sellerSlug,
    this.imageUrl,
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

    if (original == null ||
        original <= 0 ||
        original <= price) {
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

  static BuyerHomeProduct fromApi(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['db_id'];
    final dynamic rawName = json['name'];
    final dynamic rawPrice = json['price'];

    if (rawId == null || rawName == null || rawPrice == null) {
      return const BuyerHomeProduct(
        id: 0,
        name: 'Unknown product',
        price: 0,
      );
    }

    final String imageValue = (json['image_url'] ?? json['image'] ?? '').toString();
    final String sellerValue = (json['seller'] ?? json['seller_name'] ?? '').toString();

    return BuyerHomeProduct(
      id: int.tryParse(rawId.toString()) ?? 0,
      name: rawName.toString(),
      slug: (json['slug'] ?? '').toString(),
      category: (json['category'] ?? json['parent_category'] ?? '').toString(),
      sellerName: sellerValue.isEmpty ? null : sellerValue,
      imageUrl: imageValue.isEmpty ? null : AppConfig.resolveMediaUrl(imageValue),
      price: double.tryParse(rawPrice.toString()) ?? 0,
      originalPrice: double.tryParse((json['old_price'] ?? json['original_price'])?.toString() ?? '') ??
          double.tryParse((json['old_price'] ?? json['original_price'])?.toString() ?? ''),
      rating: double.tryParse((json['rating'] ?? '0').toString()),
      soldCount: int.tryParse((json['sold'] ?? json['sold_count'] ?? '0').toString()) ?? 0,
      stock: int.tryParse((json['stock'] ?? json['variant_stock'] ?? '0').toString()) ?? 0,
      isFeatured: json['is_featured'] == true,
      isRecommended: json['is_recommended'] == true,
      wishlisted: json['wishlisted'] == true,
    );
  }
}

class BuyerHomeCategory {
  final String name;
  final String slug;

  /// Optional because later the category can come directly
  /// from Laravel without Laravel having to know Flutter icons.
  final IconData? icon;

  const BuyerHomeCategory({
    required this.name,
    required this.slug,
    this.icon,
  });
}

class BuyerHomeScreen extends StatefulWidget {
  /// General marketplace products.
  ///
  /// This screen will NOT automatically call the first four
  /// products "featured" or products 5-8 "recommended".
  ///
  /// If [featuredProducts] and [recommendedProducts] are empty,
  /// only products explicitly marked with isFeatured or
  /// isRecommended are used for those sections.
  final List<BuyerHomeProduct> products;

  /// Preferred list when Laravel eventually returns an explicit
  /// featured collection.
  final List<BuyerHomeProduct> featuredProducts;

  /// Preferred list when Laravel eventually returns an explicit
  /// recommendation collection.
  final List<BuyerHomeProduct> recommendedProducts;

  /// Preferred product for the marketplace hero.
  ///
  /// No hard-coded product slug is used.
  final BuyerHomeProduct? heroProduct;

  /// Real category list supplied by the page/controller later.
  final List<BuyerHomeCategory> categories;

  final VoidCallback? onSearch;
  final VoidCallback? onCart;
  final VoidCallback? onNotifications;

  final VoidCallback? onBrowseProducts;
  final VoidCallback? onViewOrders;
  final VoidCallback? onWishlist;
  final VoidCallback? onMessages;
  final VoidCallback? onVouchers;

  final VoidCallback? onViewAllCategories;

  final BuyerHomeCategoryCallback? onCategorySelected;

  final VoidCallback? onViewFeatured;
  final VoidCallback? onShopDeals;
  final VoidCallback? onViewRecommended;

  final BuyerHomeProductCallback? onProductSelected;

  /// Preferred wishlist callback for future Laravel integration.
  ///
  /// The heart changes only after this Future succeeds.
  final BuyerHomeWishlistCallback? onWishlistProductAsync;

  /// Backward-compatible synchronous callback.
  ///
  /// You can remove this later after all navigation/controller
  /// wiring uses [onWishlistProductAsync].
  final BuyerHomeProductCallback? onWishlistProduct;

  final BuyerHomeRefreshCallback? onRefresh;

  final DateTime? flashSaleEndsAt;

  /// Optional values for later real database state.
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
  State<BuyerHomeScreen> createState() =>
      _BuyerHomeScreenState();
}

class _BuyerHomeScreenState extends State<BuyerHomeScreen> {
  static const Color background =
      Color(0xFFFBF7F2);

  static const Color card =
      Color(0xFFFFFDF9);

  static const Color border =
      Color(0xFFEADCCC);

  static const Color maroon =
      Color(0xFF561C17);

  static const Color maroonLight =
      Color(0xFF7A2A22);

  static const Color maroonDark =
      Color(0xFF3E130F);

  static const Color text =
      Color(0xFF3B211B);

  static const Color brown =
      Color(0xFF6C4936);

  static const Color muted =
      Color(0xFF987865);

  static const Color muted2 =
      Color(0xFFA99386);

  static const Color tan =
      Color(0xFFC19771);

  static const Color star =
      Color(0xFFC88418);

  static const Color danger =
      Color(0xFFB42318);

  Timer? _timer;

  Duration _remaining =
      Duration.zero;

  final Set<int> _wishlistIds =
      <int>{};

  final Set<int> _wishlistLoading =
      <int>{};

  List<BuyerHomeProduct> _loadedProducts =
      <BuyerHomeProduct>[];

  @override
  void initState() {
    super.initState();

    _syncWishlistState();

    _configureCountdown();

    if (widget.products.isEmpty) {
      _loadProducts();
    }
  }

  Future<void> _loadProducts() async {
    try {
      final List<BuyerHomeProduct> fetchedProducts =
          await ProductService.fetchHomeProducts();
      if (!mounted) {
        return;
      }

      setState(() {
        _loadedProducts = fetchedProducts;
      });
    } catch (_) {
      // API failures are surfaced through the empty/error states in the screen.
    }
  }

  @override
  void didUpdateWidget(
    covariant BuyerHomeScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.products != widget.products ||
        oldWidget.featuredProducts !=
            widget.featuredProducts ||
        oldWidget.recommendedProducts !=
            widget.recommendedProducts ||
        oldWidget.heroProduct !=
            widget.heroProduct) {
      _syncWishlistState();
    }

    if (oldWidget.flashSaleEndsAt !=
        widget.flashSaleEndsAt) {
      _configureCountdown();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();

    super.dispose();
  }

  List<BuyerHomeProduct> get _featuredProducts {
    if (widget.featuredProducts.isNotEmpty) {
      return widget.featuredProducts
          .take(4)
          .toList();
    }

    final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
      ...widget.products,
      ..._loadedProducts,
    ];

    return baseProducts
        .where(
          (
            BuyerHomeProduct product,
          ) =>
              product.isFeatured,
        )
        .take(4)
        .toList();
  }

  List<BuyerHomeProduct> get _recommendedProducts {
    if (widget.recommendedProducts.isNotEmpty) {
      return widget.recommendedProducts
          .take(4)
          .toList();
    }

    final List<BuyerHomeProduct> baseProducts = <BuyerHomeProduct>[
      ...widget.products,
      ..._loadedProducts,
    ];

    return baseProducts
        .where(
          (
            BuyerHomeProduct product,
          ) =>
              product.isRecommended,
        )
        .take(4)
        .toList();
  }

  BuyerHomeProduct? get _heroProduct {
    if (widget.heroProduct != null) {
      return widget.heroProduct;
    }

    final List<BuyerHomeProduct> featured =
        _featuredProducts;

    if (featured.isNotEmpty) {
      return featured.first;
    }

    return null;
  }

  Iterable<BuyerHomeProduct>
      get _allKnownProducts sync* {
    yield* widget.products;
    yield* _loadedProducts;

    yield* widget.featuredProducts;

    yield* widget.recommendedProducts;

    final BuyerHomeProduct? hero =
        widget.heroProduct;

    if (hero != null) {
      yield hero;
    }
  }

  void _syncWishlistState() {
    final Set<int> incoming =
        <int>{};

    for (final BuyerHomeProduct product
        in _allKnownProducts) {
      if (product.wishlisted) {
        incoming.add(
          product.id,
        );
      }
    }

    _wishlistIds
      ..clear()
      ..addAll(
        incoming,
      );
  }

  bool _isWishlisted(
    BuyerHomeProduct product,
  ) {
    return _wishlistIds.contains(
      product.id,
    );
  }

  Future<void> _toggleWishlist(
    BuyerHomeProduct product,
  ) async {
    if (_wishlistLoading.contains(
      product.id,
    )) {
      return;
    }

    final BuyerHomeWishlistCallback?
        asyncCallback =
        widget.onWishlistProductAsync;

    final BuyerHomeProductCallback?
        syncCallback =
        widget.onWishlistProduct;

    if (asyncCallback == null &&
        syncCallback == null) {
      _showMessage(
        'Wishlist will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _wishlistLoading.add(
        product.id,
      );
    });

    try {
      if (asyncCallback != null) {
        await asyncCallback(
          product,
        );
      } else {
        syncCallback!.call(
          product,
        );
      }

      if (!mounted) {
        return;
      }

      final bool wasWishlisted =
          _wishlistIds.contains(
        product.id,
      );

      setState(() {
        if (wasWishlisted) {
          _wishlistIds.remove(
            product.id,
          );
        } else {
          _wishlistIds.add(
            product.id,
          );
        }
      });

      _showMessage(
        wasWishlisted
            ? 'Product removed from your wishlist.'
            : 'Product saved to your wishlist.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _wishlistLoading.remove(
            product.id,
          );
        });
      }
    }
  }

  Future<void> _refresh() async {
    final BuyerHomeRefreshCallback? callback =
        widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      await callback();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    }
  }

  void _configureCountdown() {
    _timer?.cancel();

    final DateTime? end =
        widget.flashSaleEndsAt;

    if (end == null) {
      _remaining =
          Duration.zero;

      return;
    }

    _updateRemaining();

    _timer =
        Timer.periodic(
      const Duration(
        seconds: 1,
      ),
      (_) {
        _updateRemaining();
      },
    );
  }

  void _updateRemaining() {
    final DateTime? end =
        widget.flashSaleEndsAt;

    if (end == null ||
        !mounted) {
      return;
    }

    final Duration difference =
        end.difference(
      DateTime.now(),
    );

    if (difference.isNegative ||
        difference == Duration.zero) {
      _timer?.cancel();

      if (_remaining !=
          Duration.zero) {
        setState(() {
          _remaining =
              Duration.zero;
        });
      }

      return;
    }

    setState(() {
      _remaining =
          difference;
    });
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior:
              SnackBarBehavior.floating,
          backgroundColor:
              error
                  ? danger
                  : maroonDark,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          content: Text(
            message,
            style:
                const TextStyle(
              color: Colors.white,
              fontWeight:
                  FontWeight.w500,
            ),
          ),
        ),
      );
  }

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  Widget _buildFloatingIslandNav() {
    return Positioned(
      left: 18,
      right: 18,
      bottom: 18,
      child: Container(
        height: 72,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(
            36,
          ),
          boxShadow: [
            BoxShadow(
              color:
                  Colors.black.withValues(
                alpha: 0.10,
              ),
              blurRadius: 18,
              offset: const Offset(
                0,
                8,
              ),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: _BottomNavItem(
                icon:
                    Icons.home_rounded,
                label: 'Home',
                active: true,
                onTap: widget.onBrowseProducts ?? () {},
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon:
                    Icons.card_giftcard_rounded,
                label: 'Win',
                active: false,
                onTap: widget.onVouchers ?? widget.onBrowseProducts ?? () {},
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon:
                    Icons.videocam_rounded,
                label: 'Live',
                active: false,
                onTap: widget.onMessages ?? widget.onBrowseProducts ?? () {},
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon:
                    Icons.notifications_none_rounded,
                label: 'Alerts',
                active: false,
                onTap: widget.onNotifications ?? widget.onBrowseProducts ?? () {},
              ),
            ),
            Expanded(
              child: _BottomNavItem(
                icon:
                    Icons.person_rounded,
                label: 'Me',
                active: false,
                onTap: widget.onViewOrders ?? widget.onBrowseProducts ?? () {},
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          background,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            RefreshIndicator(
              color: maroon,
              onRefresh:
                  _refresh,
              child:
                  CustomScrollView(
                physics:
                    const AlwaysScrollableScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                slivers: [
                  SliverToBoxAdapter(
                    child:
                        _buildMobileHeader(),
                  ),

                  SliverToBoxAdapter(
                    child:
                        _buildMainContent(),
                  ),
                ],
              ),
            ),
            _buildFloatingIslandNav(),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      color: background,
      padding:
          const EdgeInsets.fromLTRB(
        16,
        10,
        16,
        10,
      ),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child:
                    _LikhaeLogo(),
              ),

              _HeaderIconButton(
                icon:
                    Icons
                        .notifications_none_rounded,
                tooltip:
                    'Notifications',
                badgeCount:
                    widget
                        .unreadNotificationCount,
                onTap:
                    widget
                        .onNotifications,
              ),

              const SizedBox(
                width: 7,
              ),

              _HeaderIconButton(
                icon:
                    Icons
                        .shopping_bag_outlined,
                tooltip: 'Cart',
                badgeCount:
                    widget
                        .cartItemCount,
                onTap:
                    widget.onCart,
              ),
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          InkWell(
            onTap:
                widget.onSearch,
            borderRadius:
                BorderRadius.circular(
              15,
            ),
            child: Container(
              height: 48,
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 14,
              ),
              decoration:
                  BoxDecoration(
                color: card,
                borderRadius:
                    BorderRadius.circular(
                  15,
                ),
                border:
                    Border.all(
                  color: border,
                ),
              ),
              child:
                  const Row(
                children: [
                  Icon(
                    Icons.search_rounded,
                    size: 21,
                    color: muted,
                  ),

                  SizedBox(
                    width: 9,
                  ),

                  Expanded(
                    child: Text(
                      'Search products, categories...',
                      style:
                          TextStyle(
                        color: muted2,
                        fontSize:
                            12.5,
                        fontWeight:
                            FontWeight
                                .w500,
                      ),
                    ),
                  ),

                  Icon(
                    Icons
                        .tune_rounded,
                    size: 19,
                    color: brown,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final double width =
            constraints.maxWidth;

        final double horizontalPadding =
            width < 350
                ? 12
                : 16;

        return Padding(
          padding:
              EdgeInsets.fromLTRB(
            horizontalPadding,
            6,
            horizontalPadding,
            120,
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.stretch,
            children: [
              _buildHero(),

              if (widget
                  .categories
                  .isNotEmpty) ...[
                const SizedBox(
                  height: 30,
                ),

                _buildCategories(),
              ],

              const SizedBox(
                height: 34,
              ),

              _buildFeaturedProducts(),

              const SizedBox(
                height: 34,
              ),

              _buildFlashDeals(),

              const SizedBox(
                height: 34,
              ),

              _buildRecommendedProducts(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHero() {
    final BuyerHomeProduct? product =
        _heroProduct;

    return Container(
      constraints:
          const BoxConstraints(
        minHeight: 255,
      ),
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          24,
        ),
        border:
            Border.all(
          color: border,
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            Color(
              0xFFFFFDF9,
            ),
            Color(
              0xFFF6EFE7,
            ),
            Color(
              0xFFEFE7DE,
            ),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                maroon.withValues(
              alpha: 0.07,
            ),
            blurRadius: 28,
            offset:
                const Offset(
              0,
              12,
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -42,
            top: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    maroon.withValues(
                  alpha: 0.055,
                ),
              ),
            ),
          ),

          Positioned(
            left: -45,
            bottom: -80,
            child: Container(
              width: 180,
              height: 180,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    tan.withValues(
                  alpha: 0.16,
                ),
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              20,
            ),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const _Kicker(
                  text:
                      'YOUR MARKETPLACE',
                ),

                const SizedBox(
                  height: 8,
                ),

                Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(
                        text:
                            'Discover something\n',
                      ),
                      TextSpan(
                        text:
                            'worth keeping.',
                        style:
                            const TextStyle(
                          fontStyle:
                              FontStyle.italic,
                          color:
                              maroonLight,
                        ),
                      ),
                    ],
                  ),
                  style:
                      const TextStyle(
                    color: maroon,
                    fontSize: 34,
                    height: 0.98,
                    letterSpacing:
                        -1.1,
                    fontWeight:
                        FontWeight
                            .w700,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  product == null
                      ? 'Explore meaningful products from local sellers across LIKHAE.'
                      : product.name,
                  maxLines: 2,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color: text,
                    fontSize:
                        12.5,
                    height: 1.5,
                  ),
                ),

                if (product != null) ...[
                  const SizedBox(
                    height: 7,
                  ),

                  Row(
                    children: [
                      Text(
                        _formatPrice(
                          product.price,
                        ),
                        style:
                            const TextStyle(
                          color:
                              maroon,
                          fontSize:
                              17,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      if (product
                                  .originalPrice !=
                              null &&
                          product
                                  .originalPrice! >
                              product
                                  .price) ...[
                        const SizedBox(
                          width: 7,
                        ),

                        Text(
                          _formatPrice(
                            product
                                .originalPrice!,
                          ),
                          style:
                              const TextStyle(
                            color:
                                muted2,
                            fontSize:
                                10,
                            decoration:
                                TextDecoration
                                    .lineThrough,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],

                const SizedBox(
                  height: 18,
                ),

                Wrap(
                  spacing: 9,
                  runSpacing: 9,
                  children: [
                    _PrimaryActionButton(
                      label:
                          'Shop Now',
                      icon:
                          Icons
                              .arrow_forward_rounded,
                      onTap:
                          widget
                              .onBrowseProducts,
                    ),

                    _OutlineActionButton(
                      label:
                          'My Orders',
                      icon:
                          Icons
                              .receipt_long_outlined,
                      onTap:
                          widget
                              .onViewOrders,
                    ),

                    if (product != null &&
                        widget
                                .onProductSelected !=
                            null)
                      _OutlineActionButton(
                        label:
                            'View Product',
                        icon:
                            Icons
                                .visibility_outlined,
                        onTap: () {
                          widget
                              .onProductSelected!
                              .call(
                            product,
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker:
              'BROWSE',
          title:
              'Shop by Category',
          subtitle:
              'Explore products from different collections.',
          actionText:
              'View All',
          onAction:
              widget
                  .onViewAllCategories,
        ),

        const SizedBox(
          height: 16,
        ),

        SizedBox(
          height: 112,
          child:
              ListView.separated(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount:
                widget
                    .categories
                    .length,
            separatorBuilder:
                (
              BuildContext context,
              int index,
            ) =>
                    const SizedBox(
              width: 10,
            ),
            itemBuilder:
                (
              BuildContext context,
              int index,
            ) {
              final BuyerHomeCategory category =
                  widget
                      .categories[index];

              return _CategoryCard(
                category:
                    category,
                onTap: () {
                  widget
                      .onCategorySelected
                      ?.call(
                    category.slug,
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeaturedProducts() {
    final List<BuyerHomeProduct> products =
        _featuredProducts;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker:
              'CURATED',
          title:
              'Featured Products',
          subtitle:
              'Top picks from trusted sellers.',
          actionText:
              'See All',
          onAction:
              widget
                  .onViewFeatured,
        ),

        const SizedBox(
          height: 16,
        ),

        if (products.isEmpty)
          _EmptyProducts(
            icon:
                Icons
                    .shopping_bag_outlined,
            title:
                'No featured products yet',
            description:
                'Featured products will appear here when they are provided by the marketplace.',
            actionText:
                'Browse Products',
            onAction:
                widget
                    .onBrowseProducts,
          )
        else
          _ProductGrid(
            products:
                products,
            isWishlisted:
                _isWishlisted,
            isWishlistLoading:
                (
              BuyerHomeProduct product,
            ) =>
                    _wishlistLoading
                        .contains(
              product.id,
            ),
            onProductSelected:
                widget
                    .onProductSelected,
            onWishlistProduct:
                _toggleWishlist,
          ),
      ],
    );
  }

  Widget _buildFlashDeals() {
    final bool hasCountdown =
        widget.flashSaleEndsAt != null;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        20,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            maroon,
            Color(
              0xFF642920,
            ),
            maroonDark,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color:
                maroon.withValues(
              alpha: 0.18,
            ),
            blurRadius: 28,
            offset:
                const Offset(
              0,
              14,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'LIMITED OFFERS',
            style:
                TextStyle(
              color:
                  Color(
                0xFFE8C8B2,
              ),
              fontSize: 9,
              letterSpacing:
                  1.7,
              fontWeight:
                  FontWeight
                      .w800,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Flash Picks',
            style:
                TextStyle(
              color:
                  Colors.white,
              fontSize: 31,
              height: 1,
              letterSpacing:
                  -0.7,
              fontWeight:
                  FontWeight
                      .w700,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          const Text(
            'Premium finds with limited-time prices.',
            style:
                TextStyle(
              color:
                  Color(
                0xFFF4DED4,
              ),
              fontSize:
                  11.5,
              height: 1.5,
            ),
          ),

          if (hasCountdown) ...[
            const SizedBox(
              height: 18,
            ),

            _Countdown(
              duration:
                  _remaining,
            ),
          ],

          const SizedBox(
            height: 18,
          ),

          SizedBox(
            width:
                double.infinity,
            height: 48,
            child:
                ElevatedButton(
              onPressed:
                  widget
                      .onShopDeals,
              style:
                  ElevatedButton
                      .styleFrom(
                elevation: 0,
                backgroundColor:
                    const Color(
                  0xFFFFF7EF,
                ),
                foregroundColor:
                    maroon,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius
                          .circular(
                    13,
                  ),
                ),
              ),
              child:
                  const Row(
                mainAxisAlignment:
                    MainAxisAlignment
                        .center,
                children: [
                  Text(
                    'Shop Deals',
                    style:
                        TextStyle(
                      fontSize:
                          12.5,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),

                  SizedBox(
                    width: 7,
                  ),

                  Icon(
                    Icons
                        .arrow_forward_rounded,
                    size: 17,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedProducts() {
    final List<BuyerHomeProduct> products =
        _recommendedProducts;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          kicker:
              'FOR YOU',
          title:
              'Recommended For You',
          subtitle:
              'Marketplace recommendations selected for this section.',
          actionText:
              'See All',
          onAction:
              widget
                  .onViewRecommended,
        ),

        const SizedBox(
          height: 16,
        ),

        if (products.isEmpty)
          _EmptyProducts(
            icon:
                Icons
                    .auto_awesome_outlined,
            title:
                'No recommendations yet',
            description:
                'Recommended products will appear here when recommendation data is available.',
            actionText:
                'Explore Products',
            onAction:
                widget
                    .onBrowseProducts,
          )
        else
          _ProductGrid(
            products:
                products,
            isWishlisted:
                _isWishlisted,
            isWishlistLoading:
                (
              BuyerHomeProduct product,
            ) =>
                    _wishlistLoading
                        .contains(
              product.id,
            ),
            onProductSelected:
                widget
                    .onProductSelected,
            onWishlistProduct:
                _toggleWishlist,
          ),
      ],
    );
  }

  static String _formatPrice(
    double price,
  ) {
    return '₱${price.toStringAsFixed(2)}';
  }
}

class _LikhaeLogo extends StatelessWidget {
  const _LikhaeLogo();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Text(
          'LIKHAE',
          style:
              TextStyle(
            color:
                _BuyerHomeScreenState
                    .maroon,
            fontSize: 20,
            letterSpacing:
                1.2,
            fontWeight:
                FontWeight
                    .w900,
          ),
        ),

        SizedBox(
          width: 7,
        ),

        SizedBox(
          width: 4,
          height: 4,
          child:
              DecoratedBox(
            decoration:
                BoxDecoration(
              color:
                  _BuyerHomeScreenState
                      .tan,
              shape:
                  BoxShape.circle,
            ),
          ),
        ),

        SizedBox(
          width: 7,
        ),

        Flexible(
          child: Text(
            'Marketplace',
            overflow:
                TextOverflow
                    .ellipsis,
            style:
                TextStyle(
              color:
                  _BuyerHomeScreenState
                      .muted,
              fontSize: 9.5,
              fontWeight:
                  FontWeight
                      .w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final int badgeCount;

  final VoidCallback? onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.badgeCount = 0,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Stack(
      clipBehavior:
          Clip.none,
      children: [
        Material(
          color:
              _BuyerHomeScreenState
                  .card,
          borderRadius:
              BorderRadius.circular(
            13,
          ),
          child: InkWell(
            onTap: onTap,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            child: Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                border:
                    Border.all(
                  color:
                      _BuyerHomeScreenState
                          .border,
                ),
                borderRadius:
                    BorderRadius
                        .circular(
                  13,
                ),
              ),
              alignment:
                  Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color:
                    _BuyerHomeScreenState
                        .maroon,
              ),
            ),
          ),
        ),

        if (badgeCount > 0)
          Positioned(
            right: -4,
            top: -5,
            child: Container(
              constraints:
                  const BoxConstraints(
                minWidth: 18,
                minHeight: 18,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 4,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                color:
                    _BuyerHomeScreenState
                        .maroon,
                borderRadius:
                    BorderRadius.circular(
                  100,
                ),
                border:
                    Border.all(
                  color:
                      _BuyerHomeScreenState
                          .background,
                  width: 2,
                ),
              ),
              child: Text(
                badgeCount > 99
                    ? '99+'
                    : '$badgeCount',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize: 7,
                  fontWeight:
                      FontWeight
                          .w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _Kicker extends StatelessWidget {
  final String text;

  const _Kicker({
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text(
      text,
      style:
          const TextStyle(
        color:
            _BuyerHomeScreenState
                .maroon,
        fontSize: 8.5,
        fontWeight:
            FontWeight
                .w900,
        letterSpacing:
            1.8,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String kicker;
  final String title;
  final String subtitle;
  final String actionText;

  final VoidCallback? onAction;

  const _SectionHeader({
    required this.kicker,
    required this.title,
    required this.subtitle,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment
                    .start,
            children: [
              _Kicker(
                text: kicker,
              ),

              const SizedBox(
                height: 5,
              ),

              Text(
                title,
                style:
                    const TextStyle(
                  color:
                      _BuyerHomeScreenState
                          .text,
                  fontSize: 25,
                  height: 1.03,
                  letterSpacing:
                      -0.7,
                  fontWeight:
                      FontWeight
                          .w700,
                ),
              ),

              const SizedBox(
                height: 7,
              ),

              Text(
                subtitle,
                style:
                    const TextStyle(
                  color:
                      _BuyerHomeScreenState
                          .muted,
                  fontSize:
                      10.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 10,
        ),

        TextButton(
          onPressed:
              onAction,
          style:
              TextButton.styleFrom(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 6,
            ),
            minimumSize:
                Size.zero,
            tapTargetSize:
                MaterialTapTargetSize
                    .shrinkWrap,
          ),
          child: Row(
            mainAxisSize:
                MainAxisSize.min,
            children: [
              Text(
                actionText,
                style:
                    const TextStyle(
                  color:
                      _BuyerHomeScreenState
                          .brown,
                  fontSize:
                      10.5,
                  fontWeight:
                      FontWeight
                          .w800,
                ),
              ),

              const SizedBox(
                width: 4,
              ),

              const Icon(
                Icons
                    .arrow_forward_rounded,
                size: 14,
                color:
                    _BuyerHomeScreenState
                        .brown,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final BuyerHomeCategory category;

  final VoidCallback? onTap;

  const _CategoryCard({
    required this.category,
    required this.onTap,
  });

  IconData get _icon {
    if (category.icon != null) {
      return category.icon!;
    }

    switch (category.slug
        .toLowerCase()) {
      case 'fashion':
      case 'clothing':
      case 'apparel':
        return Icons
            .checkroom_outlined;

      case 'electronics':
      case 'technology':
        return Icons
            .devices_outlined;

      case 'home':
      case 'home-living':
        return Icons
            .home_outlined;

      case 'books':
        return Icons
            .menu_book_outlined;

      case 'beauty':
        return Icons
            .spa_outlined;

      case 'sports':
        return Icons
            .sports_basketball_outlined;

      case 'toys':
        return Icons
            .toys_outlined;

      case 'automotive':
        return Icons
            .directions_car_outlined;

      default:
        return Icons
            .category_outlined;
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 88,
      child: Material(
        color:
            _BuyerHomeScreenState
                .card,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(
            16,
          ),
          child: Container(
            padding:
                const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 11,
            ),
            decoration:
                BoxDecoration(
              border:
                  Border.all(
                color:
                    _BuyerHomeScreenState
                        .border,
              ),
              borderRadius:
                  BorderRadius
                      .circular(
                16,
              ),
            ),
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment
                      .center,
              children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration:
                      const BoxDecoration(
                    color:
                        Color(
                      0xFFF1E4D7,
                    ),
                    shape:
                        BoxShape.circle,
                  ),
                  alignment:
                      Alignment.center,
                  child: Icon(
                    _icon,
                    color:
                        _BuyerHomeScreenState
                            .maroon,
                    size: 21,
                  ),
                ),

                const SizedBox(
                  height: 8,
                ),

                Text(
                  category.name,
                  maxLines: 1,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  textAlign:
                      TextAlign.center,
                  style:
                      const TextStyle(
                    color:
                        _BuyerHomeScreenState
                            .text,
                    fontSize: 9.5,
                    fontWeight:
                        FontWeight
                            .w800,
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

class _BottomNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius:
          BorderRadius.circular(
        24,
      ),
      child: Column(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: active
                ? const Color(0xFFEA5A2A)
                : const Color(0xFF8A7A72),
            size: 24,
          ),
          const SizedBox(
            height: 4,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: active
                  ? const Color(0xFFEA5A2A)
                  : const Color(0xFF8A7A72),
              fontWeight: active
                  ? FontWeight.w700
                  : FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductGrid extends StatelessWidget {
  final List<BuyerHomeProduct> products;

  final bool Function(
    BuyerHomeProduct product,
  ) isWishlisted;

  final bool Function(
    BuyerHomeProduct product,
  ) isWishlistLoading;

  final BuyerHomeProductCallback?
      onProductSelected;

  final BuyerHomeWishlistCallback
      onWishlistProduct;

  const _ProductGrid({
    required this.products,
    required this.isWishlisted,
    required this.isWishlistLoading,
    required this.onProductSelected,
    required this.onWishlistProduct,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return LayoutBuilder(
      builder: (
        BuildContext context,
        BoxConstraints constraints,
      ) {
        final int columns =
            constraints.maxWidth <
                    330
                ? 1
                : 2;

        const double spacing =
            10;

        final double itemWidth =
            (constraints.maxWidth -
                    ((columns - 1) *
                        spacing)) /
                columns;

        return Wrap(
          spacing: spacing,
          runSpacing: 12,
          children:
              products.map(
            (
              BuyerHomeProduct product,
            ) {
              return SizedBox(
                width:
                    itemWidth,
                child:
                    _ProductCard(
                  product:
                      product,
                  isWishlisted:
                      isWishlisted(
                    product,
                  ),
                  wishlistLoading:
                      isWishlistLoading(
                    product,
                  ),
                  onTap:
                      onProductSelected ==
                              null
                          ? null
                          : () {
                              onProductSelected!(
                                product,
                              );
                            },
                  onWishlist: () {
                    onWishlistProduct(
                      product,
                    );
                  },
                ),
              );
            },
          ).toList(),
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
  Widget build(
    BuildContext context,
  ) {
    final double? discount =
        product.discountPercentage;

    return Material(
      color:
          _BuyerHomeScreenState
              .card,
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Container(
          clipBehavior:
              Clip.antiAlias,
          decoration:
              BoxDecoration(
            border:
                Border.all(
              color:
                  _BuyerHomeScreenState
                      .border,
            ),
            borderRadius:
                BorderRadius.circular(
              16,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Stack(
                  fit:
                      StackFit.expand,
                  children: [
                    Container(
                      color:
                          const Color(
                        0xFFF3ECE4,
                      ),
                      child:
                          _ProductImage(
                        imageUrl:
                            product
                                .imageUrl,
                      ),
                    ),

                    if (discount !=
                        null)
                      Positioned(
                        left: 8,
                        top: 8,
                        child:
                            Container(
                          padding:
                              const EdgeInsets
                                  .symmetric(
                            horizontal:
                                7,
                            vertical:
                                5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                _BuyerHomeScreenState
                                    .maroon,
                            borderRadius:
                                BorderRadius
                                    .circular(
                              8,
                            ),
                          ),
                          child:
                              Text(
                            '-${discount.round()}%',
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  8.5,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      right: 8,
                      top: 8,
                      child:
                          Material(
                        color:
                            Colors.white
                                .withValues(
                          alpha: 0.93,
                        ),
                        shape:
                            const CircleBorder(),
                        child:
                            InkWell(
                          onTap:
                              wishlistLoading
                                  ? null
                                  : onWishlist,
                          customBorder:
                              const CircleBorder(),
                          child:
                              SizedBox(
                            width: 34,
                            height: 34,
                            child:
                                wishlistLoading
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.all(
                                          8,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              1.8,
                                          color:
                                              _BuyerHomeScreenState.maroon,
                                        ),
                                      )
                                    : Icon(
                                        isWishlisted
                                            ? Icons
                                                .favorite_rounded
                                            : Icons
                                                .favorite_border_rounded,
                                        size:
                                            18,
                                        color:
                                            _BuyerHomeScreenState.maroon,
                                      ),
                          ),
                        ),
                      ),
                    ),

                    if (product
                        .isOutOfStock)
                      Positioned.fill(
                        child:
                            Container(
                          color:
                              Colors.black
                                  .withValues(
                            alpha: 0.42,
                          ),
                          alignment:
                              Alignment.center,
                          child:
                              Container(
                            padding:
                                const EdgeInsets
                                    .symmetric(
                              horizontal:
                                  10,
                              vertical:
                                  6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black
                                      .withValues(
                                alpha: 0.64,
                              ),
                              borderRadius:
                                  BorderRadius
                                      .circular(
                                8,
                              ),
                            ),
                            child:
                                const Text(
                              'OUT OF STOCK',
                              style:
                                  TextStyle(
                                color:
                                    Colors.white,
                                fontSize:
                                    8.5,
                                letterSpacing:
                                    0.7,
                                fontWeight:
                                    FontWeight
                                        .w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  11,
                  11,
                  11,
                  12,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    if (product
                            .category
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      Text(
                        product.category!
                            .toUpperCase(),
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _BuyerHomeScreenState
                                  .brown,
                          fontSize:
                              7.5,
                          letterSpacing:
                              0.7,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),

                      const SizedBox(
                        height: 5,
                      ),
                    ],

                    Text(
                      product.name,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            _BuyerHomeScreenState
                                .text,
                        fontSize:
                            11.5,
                        height: 1.3,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    if (product
                            .sellerName
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        product
                            .sellerName!,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _BuyerHomeScreenState
                                  .muted,
                          fontSize:
                              8.5,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment
                              .center,
                      spacing: 4,
                      runSpacing: 3,
                      children: [
                        Text(
                          _price(
                            product.price,
                          ),
                          style:
                              const TextStyle(
                            color:
                                _BuyerHomeScreenState
                                    .maroon,
                            fontSize:
                                13.5,
                            fontWeight:
                                FontWeight
                                    .w900,
                          ),
                        ),

                        if (product
                                    .originalPrice !=
                                null &&
                            product
                                    .originalPrice! >
                                product
                                    .price)
                          Text(
                            _price(
                              product
                                  .originalPrice!,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  _BuyerHomeScreenState
                                      .muted2,
                              fontSize:
                                  8.5,
                              decoration:
                                  TextDecoration
                                      .lineThrough,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        if (product
                                .rating !=
                            null) ...[
                          const Icon(
                            Icons
                                .star_rounded,
                            color:
                                _BuyerHomeScreenState
                                    .star,
                            size: 14,
                          ),

                          const SizedBox(
                            width: 2,
                          ),

                          Text(
                            product
                                .rating!
                                .toStringAsFixed(
                              1,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  _BuyerHomeScreenState
                                      .text,
                              fontSize:
                                  8.5,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            width: 5,
                          ),
                        ],

                        Expanded(
                          child: Text(
                            '${product.soldCount} sold',
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  _BuyerHomeScreenState
                                      .muted,
                              fontSize:
                                  8.5,
                            ),
                          ),
                        ),

                        if (product.stock !=
                                null &&
                            !product
                                .isOutOfStock)
                          Text(
                            '${product.stock} left',
                            style:
                                const TextStyle(
                              color:
                                  _BuyerHomeScreenState
                                      .muted,
                              fontSize:
                                  7.5,
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

  static String _price(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({
    required this.imageUrl,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? url =
        imageUrl?.trim();

    if (url == null ||
        url.isEmpty) {
      return const Center(
        child: Icon(
          Icons
              .inventory_2_outlined,
          size: 34,
          color:
              _BuyerHomeScreenState
                  .muted2,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(url);

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      errorBuilder:
          (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const Center(
          child: Icon(
            Icons
                .broken_image_outlined,
            size: 34,
            color:
                _BuyerHomeScreenState
                    .muted2,
          ),
        );
      },
      loadingBuilder:
          (
        BuildContext context,
        Widget child,
        ImageChunkEvent? progress,
      ) {
        if (progress == null) {
          return child;
        }

        return const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
              color:
                  _BuyerHomeScreenState
                      .maroon,
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
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 45,
      child:
          ElevatedButton.icon(
        onPressed: onTap,
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              _BuyerHomeScreenState
                  .maroon,
          foregroundColor:
              Colors.white,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
        iconAlignment:
            IconAlignment.end,
        icon: Icon(
          icon,
          size: 16,
        ),
        label: Text(
          label,
          style:
              const TextStyle(
            fontSize: 11.5,
            fontWeight:
                FontWeight
                    .w800,
          ),
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
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      height: 45,
      child:
          OutlinedButton.icon(
        onPressed: onTap,
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              _BuyerHomeScreenState
                  .maroon,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 15,
          ),
          side:
              const BorderSide(
            color:
                _BuyerHomeScreenState
                    .tan,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              12,
            ),
          ),
        ),
        icon: Icon(
          icon,
          size: 16,
        ),
        label: Text(
          label,
          style:
              const TextStyle(
            fontSize: 11.5,
            fontWeight:
                FontWeight
                    .w800,
          ),
        ),
      ),
    );
  }
}

class _Countdown extends StatelessWidget {
  final Duration duration;

  const _Countdown({
    required this.duration,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final int totalHours =
        duration.inHours;

    final int minutes =
        duration.inMinutes
            .remainder(
      60,
    );

    final int seconds =
        duration.inSeconds
            .remainder(
      60,
    );

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
        horizontal: 10,
      ),
      decoration:
          BoxDecoration(
        color:
            Colors.white
                .withValues(
          alpha: 0.08,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              Colors.white
                  .withValues(
            alpha: 0.18,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment:
            MainAxisAlignment.center,
        children: [
          _CountdownUnit(
            value:
                totalHours
                    .toString()
                    .padLeft(
              2,
              '0',
            ),
            label:
                'Hours',
          ),

          const _CountdownSeparator(),

          _CountdownUnit(
            value:
                minutes
                    .toString()
                    .padLeft(
              2,
              '0',
            ),
            label:
                'Minutes',
          ),

          const _CountdownSeparator(),

          _CountdownUnit(
            value:
                seconds
                    .toString()
                    .padLeft(
              2,
              '0',
            ),
            label:
                'Seconds',
          ),
        ],
      ),
    );
  }
}

class _CountdownUnit extends StatelessWidget {
  final String value;

  final String label;

  const _CountdownUnit({
    required this.value,
    required this.label,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style:
                const TextStyle(
              color:
                  Colors.white,
              fontSize: 18,
              fontWeight:
                  FontWeight
                      .w900,
            ),
          ),

          const SizedBox(
            height: 2,
          ),

          Text(
            label
                .toUpperCase(),
            style:
                const TextStyle(
              color:
                  Color(
                0xFFE8C8B2,
              ),
              fontSize: 7.5,
              letterSpacing:
                  0.8,
              fontWeight:
                  FontWeight
                      .w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _CountdownSeparator extends StatelessWidget {
  const _CountdownSeparator();

  @override
  Widget build(
    BuildContext context,
  ) {
    return const Padding(
      padding:
          EdgeInsets.symmetric(
        horizontal: 3,
      ),
      child: Text(
        ':',
        style:
            TextStyle(
          color:
              Color(
            0xFFE8C8B2,
          ),
          fontSize: 17,
          fontWeight:
              FontWeight
                  .w900,
        ),
      ),
    );
  }
}

class _EmptyProducts extends StatelessWidget {
  final IconData icon;

  final String title;
  final String description;

  final String actionText;

  final VoidCallback? onAction;

  const _EmptyProducts({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionText,
    required this.onAction,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal: 20,
        vertical: 30,
      ),
      decoration:
          BoxDecoration(
        color:
            _BuyerHomeScreenState
                .card,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              _BuyerHomeScreenState
                  .border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration:
                const BoxDecoration(
              color:
                  Color(
                0xFFF1E4D7,
              ),
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child: Icon(
              icon,
              size: 25,
              color:
                  _BuyerHomeScreenState
                      .maroon,
            ),
          ),

          const SizedBox(
            height: 13,
          ),

          Text(
            title,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  _BuyerHomeScreenState
                      .text,
              fontSize: 12.5,
              fontWeight:
                  FontWeight
                      .w800,
            ),
          ),

          const SizedBox(
            height: 5,
          ),

          Text(
            description,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  _BuyerHomeScreenState
                      .muted,
              fontSize: 10,
              height: 1.45,
            ),
          ),

          const SizedBox(
            height: 15,
          ),

          OutlinedButton(
            onPressed:
                onAction,
            style:
                OutlinedButton
                    .styleFrom(
              foregroundColor:
                  _BuyerHomeScreenState
                      .maroon,
              side:
                  const BorderSide(
                color:
                    _BuyerHomeScreenState
                        .tan,
              ),
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius
                        .circular(
                  11,
                ),
              ),
            ),
            child: Text(
              actionText,
              style:
                  const TextStyle(
                fontSize: 10.5,
                fontWeight:
                    FontWeight
                        .w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
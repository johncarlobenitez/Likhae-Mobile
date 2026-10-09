import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

typedef StoreProductCallback = void Function(
  StoreProductData product,
);

typedef StoreAsyncProductCallback = Future<void> Function(
  StoreProductData product,
);

typedef StoreRefreshCallback = Future<void> Function();

class StoreSellerData {
  final int id;

  final String name;
  final String slug;

  final String? avatarUrl;
  final String? location;
  final String? joinedYear;

  final double? rating;

  /// Optional seller metrics.
  ///
  /// These must only be supplied when Laravel actually has
  /// a value for them. Flutter does not manufacture seller
  /// performance statistics.
  final String? followers;
  final String? response;
  final String? fulfillment;

  final String? description;
  final String? businessHours;

  /// true  = Laravel explicitly says verified.
  /// false = Laravel explicitly says not verified.
  /// null  = verification state was not supplied.
  final bool? verified;

  const StoreSellerData({
    required this.id,
    required this.name,
    required this.slug,
    this.avatarUrl,
    this.location,
    this.joinedYear,
    this.rating,
    this.followers,
    this.response,
    this.fulfillment,
    this.description,
    this.businessHours,
    this.verified,
  });

  factory StoreSellerData.fromApi(Map<String, dynamic> json) {
    return StoreSellerData(
      id: int.tryParse(
            (json['id'] ?? json['user_id'] ?? json['seller_user_id'])
                    ?.toString() ??
                '',
          ) ??
          0,
      name: (json['name'] ??
              json['business_name'] ??
              json['store_name'] ??
              'Seller')
          .toString(),
      slug: (json['slug'] ?? json['store_slug'] ?? json['seller_slug'] ?? '')
          .toString(),
      avatarUrl: json['logo_url']?.toString() ??
          json['avatar_url']?.toString() ??
          json['seller_avatar']?.toString(),
      location: json['location']?.toString() ??
          json['seller_location']?.toString(),
      joinedYear: json['joined_year']?.toString() ??
          json['year_joined']?.toString(),
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      description: json['description']?.toString(),
      verified: json['verified'] == true || json['is_verified'] == true,
    );
  }

  String get initials {
    final List<String> parts = name
        .trim()
        .split(
          RegExp(r'\s+'),
        )
        .where(
          (String part) => part.isNotEmpty,
        )
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'S';
    }

    return parts
        .map(
          (String part) =>
              part[0].toUpperCase(),
        )
        .join();
  }
}

class StoreProductData {
  final int id;

  final String name;

  final String? slug;
  final String? category;
  final String? imageUrl;

  final double price;
  final double? originalPrice;

  final double? rating;

  final int soldCount;

  /// null = stock was not supplied to this screen.
  ///
  /// 0 = Laravel explicitly reports no available stock.
  ///
  /// > 0 = available quantity supplied by Laravel.
  final int? stock;

  final bool wishlisted;

  const StoreProductData({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.imageUrl,
    this.originalPrice,
    this.rating,
    this.soldCount = 0,
    this.stock,
    this.wishlisted = false,
  });

  factory StoreProductData.fromApi(Map<String, dynamic> json) {
    final dynamic rawImage = json['image_url'] ??
        json['image'] ??
        json['photo'] ??
        json['primary_image'];
    final String imageValue = rawImage is Map
        ? (rawImage['url'] ?? rawImage['image_url'] ?? rawImage['file_path'] ?? '')
              .toString()
        : (rawImage ?? '').toString();
    final dynamic rawVariants = json['variants'];
    final Map<String, dynamic>? defaultVariant = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .cast<Map<String, dynamic>?>()
              .firstWhere(
                (Map<String, dynamic>? item) => item?['is_default'] == true,
                orElse: () => null,
              )
        : null;
    final double price = double.tryParse(
          (json['price'] ??
                  json['min_price'] ??
                  defaultVariant?['price'] ??
                  '')
              .toString(),
        ) ??
        0;
    final double? originalPrice = double.tryParse(
      (json['old_price'] ??
              json['original_price'] ??
              defaultVariant?['original_price'] ??
              '')
          .toString(),
    );

    return StoreProductData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? 'Product').toString(),
      slug: json['slug']?.toString(),
      category: json['category'] is Map
          ? (json['category'] as Map)['name']?.toString()
          : json['category']?.toString() ?? json['parent_category']?.toString(),
      imageUrl: imageValue.isEmpty ? null : AppConfig.resolveMediaUrl(imageValue),
      price: price,
      originalPrice: originalPrice,
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      soldCount: int.tryParse(json['sold']?.toString() ?? json['sold_count']?.toString() ?? '0') ?? 0,
      stock: int.tryParse(
        (json['stock'] ?? json['quantity'])?.toString() ?? '0',
      ),
      wishlisted: json['wishlisted'] == true || json['wishlist'] == true,
    );
  }

  double? get discountPercentage {
    final double? original =
        originalPrice;

    if (original == null ||
        original <= 0 ||
        original <= price) {
      return null;
    }

    return ((original - price) / original) * 100;
  }

  bool get isOutOfStock {
    final int? availableStock =
        stock;

    if (availableStock == null) {
      return false;
    }

    return availableStock <= 0;
  }

  bool get hasKnownStock {
    return stock != null;
  }

  StoreProductData copyWith({
    bool? wishlisted,
  }) {
    return StoreProductData(
      id: id,
      name: name,
      price: price,
      slug: slug,
      category: category,
      imageUrl: imageUrl,
      originalPrice: originalPrice,
      rating: rating,
      soldCount: soldCount,
      stock: stock,
      wishlisted:
          wishlisted ?? this.wishlisted,
    );
  }
}

enum StoreProductSort {
  defaultSort,
  priceLow,
  priceHigh,
  rating,
  sold,
}

extension StoreProductSortInfo on StoreProductSort {
  String get label {
    switch (this) {
      case StoreProductSort.defaultSort:
        return 'Default';

      case StoreProductSort.priceLow:
        return 'Price: Low to High';

      case StoreProductSort.priceHigh:
        return 'Price: High to Low';

      case StoreProductSort.rating:
        return 'Top Rated';

      case StoreProductSort.sold:
        return 'Best Selling';
    }
  }
}

class StoreScreen extends StatefulWidget {
  final StoreSellerData seller;

  final List<StoreProductData> products;

  final VoidCallback? onBack;

  final VoidCallback? onMessageSeller;

  final StoreProductCallback? onProductSelected;

  /// Toggle the real Laravel wishlist state.
  ///
  /// The local heart changes only after this callback
  /// completes successfully.
  final StoreAsyncProductCallback? onWishlistProduct;

  final StoreRefreshCallback? onRefresh;

  /// Optional synchronization with a parent Buyer shell.
  ///
  /// This is useful when Store, Products, Home and Wishlist
  /// share the same wishlist state later.
  final ValueChanged<List<StoreProductData>>?
      onProductsChanged;

  const StoreScreen({
    super.key,
    required this.seller,
    this.products = const <StoreProductData>[],
    this.onBack,
    this.onMessageSeller,
    this.onProductSelected,
    this.onWishlistProduct,
    this.onRefresh,
    this.onProductsChanged,
  });

  @override
  State<StoreScreen> createState() =>
      _StoreScreenState();
}

class _StoreScreenState
    extends State<StoreScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _softStrong =
      Color(0xFFF1E4D7);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroon2 =
      Color(0xFF642920);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _muted2 =
      Color(0xFFA99386);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _success =
      Color(0xFF256F4A);

  static const Color _danger =
      Color(0xFFB42318);

  late List<StoreProductData> _products;

  final TextEditingController
      _searchController =
      TextEditingController();

  final Set<int> _wishlistLoading =
      <int>{};

  StoreProductSort _sort =
      StoreProductSort.defaultSort;

  String _query = '';

  bool _refreshing = false;

  @override
  void initState() {
    super.initState();

    _products =
        List<StoreProductData>.from(
      widget.products,
    );
  }

  @override
  void didUpdateWidget(
    covariant StoreScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.products !=
        widget.products) {
      _products =
          List<StoreProductData>.from(
        widget.products,
      );

      final Set<int> currentProductIds =
          _products
              .map(
                (
                  StoreProductData product,
                ) =>
                    product.id,
              )
              .toSet();

      _wishlistLoading.removeWhere(
        (int productId) =>
            !currentProductIds.contains(
          productId,
        ),
      );
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<StoreProductData> get _visibleProducts {
    final String cleanQuery =
        _query.trim().toLowerCase();

    final List<StoreProductData> result =
        _products.where(
      (
        StoreProductData product,
      ) {
        if (cleanQuery.isEmpty) {
          return true;
        }

        final String searchable =
            <String>[
          product.name,
          product.category ?? '',
        ].join(' ').toLowerCase();

        return searchable.contains(
          cleanQuery,
        );
      },
    ).toList();

    switch (_sort) {
      case StoreProductSort.defaultSort:
        break;

      case StoreProductSort.priceLow:
        result.sort(
          (
            StoreProductData a,
            StoreProductData b,
          ) {
            return a.price.compareTo(
              b.price,
            );
          },
        );
        break;

      case StoreProductSort.priceHigh:
        result.sort(
          (
            StoreProductData a,
            StoreProductData b,
          ) {
            return b.price.compareTo(
              a.price,
            );
          },
        );
        break;

      case StoreProductSort.rating:
        result.sort(
          (
            StoreProductData a,
            StoreProductData b,
          ) {
            return (b.rating ?? 0)
                .compareTo(
              a.rating ?? 0,
            );
          },
        );
        break;

      case StoreProductSort.sold:
        result.sort(
          (
            StoreProductData a,
            StoreProductData b,
          ) {
            return b.soldCount.compareTo(
              a.soldCount,
            );
          },
        );
        break;
    }

    return result;
  }

  Future<void> _refresh() async {
    final StoreRefreshCallback? callback =
        widget.onRefresh;

    if (callback == null ||
        _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await callback();
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
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _toggleWishlist(
    StoreProductData product,
  ) async {
    if (_wishlistLoading.contains(
      product.id,
    )) {
      return;
    }

    final StoreAsyncProductCallback? callback =
        widget.onWishlistProduct;

    if (callback == null) {
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
      /*
       * Do not optimistically change the heart.
       *
       * Wait for the Laravel wishlist toggle to succeed.
       */
      await callback(
        product,
      );

      if (!mounted) {
        return;
      }

      final int index =
          _products.indexWhere(
        (
          StoreProductData current,
        ) =>
            current.id ==
            product.id,
      );

      if (index < 0) {
        return;
      }

      setState(() {
        _products[index] =
            _products[index].copyWith(
          wishlisted:
              !_products[index].wishlisted,
        );
      });

      widget.onProductsChanged?.call(
        List<StoreProductData>.unmodifiable(
          _products,
        ),
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

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _query = '';
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
                  ? _danger
                  : _maroonDark,
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
          content:
              Text(
            message,
            style:
                const TextStyle(
              color:
                  Colors.white,
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

  @override
  Widget build(
    BuildContext context,
  ) {
    final List<StoreProductData>
        visibleProducts =
        _visibleProducts;

    return Scaffold(
      backgroundColor:
          _background,
      body:
          SafeArea(
        bottom:
            false,
        child:
            Column(
          children: [
            _buildTopBar(),

            Expanded(
              child:
                  RefreshIndicator(
                color:
                    _maroon,
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
                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        14,
                        14,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            _buildSellerHero(),
                      ),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        12,
                        14,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            _buildSellerDetails(),
                      ),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        20,
                        14,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            _buildProductHeader(
                          visibleProducts.length,
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding:
                          const EdgeInsets.fromLTRB(
                        14,
                        13,
                        14,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            _buildSearchAndSort(),
                      ),
                    ),

                    if (visibleProducts.isEmpty)
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          14,
                          18,
                          14,
                          110,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child:
                              _buildEmptyProducts(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          14,
                          16,
                          14,
                          110,
                        ),
                        sliver:
                            SliverLayoutBuilder(
                          builder:
                              (
                            BuildContext context,
                            constraints,
                          ) {
                            final double width =
                                constraints
                                    .crossAxisExtent;

                            final int columns;

                            if (width >= 900) {
                              columns = 4;
                            } else if (width >= 600) {
                              columns = 3;
                            } else if (width < 330) {
                              columns = 1;
                            } else {
                              columns = 2;
                            }

                            return SliverGrid(
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount:
                                    columns,
                                crossAxisSpacing:
                                    10,
                                mainAxisSpacing:
                                    12,
                                childAspectRatio:
                                    columns == 1
                                        ? 1.55
                                        : 0.59,
                              ),
                              delegate:
                                  SliverChildBuilderDelegate(
                                (
                                  BuildContext context,
                                  int index,
                                ) {
                                  final StoreProductData product =
                                      visibleProducts[
                                          index];

                                  return _StoreProductCard(
                                    product:
                                        product,
                                    wishlistLoading:
                                        _wishlistLoading.contains(
                                      product.id,
                                    ),
                                    onTap:
                                        () {
                                      widget
                                          .onProductSelected
                                          ?.call(
                                        product,
                                      );
                                    },
                                    onWishlist:
                                        () {
                                      _toggleWishlist(
                                        product,
                                      );
                                    },
                                  );
                                },
                                childCount:
                                    visibleProducts.length,
                              ),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration:
          const BoxDecoration(
        color:
            _background,
        border:
            Border(
          bottom:
              BorderSide(
            color:
                Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child:
          Row(
        children: [
          IconButton(
            tooltip:
                'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon:
                const Icon(
              Icons
                  .arrow_back_rounded,
              color:
                  _text,
            ),
          ),

          const SizedBox(
            width:
                2,
          ),

          Expanded(
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Store',
                  style:
                      TextStyle(
                    color:
                        _text,
                    fontSize:
                        19,
                    height:
                        1.1,
                    letterSpacing:
                        -0.4,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                const SizedBox(
                  height:
                      2,
                ),

                Text(
                  widget.seller.name,
                  maxLines:
                      1,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    color:
                        _muted,
                    fontSize:
                        9.5,
                  ),
                ),
              ],
            ),
          ),

          if (_refreshing) ...[
            const SizedBox(
              width:
                  17,
              height:
                  17,
              child:
                  CircularProgressIndicator(
                strokeWidth:
                    2,
                color:
                    _maroon,
              ),
            ),

            const SizedBox(
              width:
                  9,
            ),
          ],

          /*
           * Only show the badge when Laravel explicitly
           * supplies verified == true.
           */
          if (widget.seller.verified ==
              true)
            Container(
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    9,
                vertical:
                    6,
              ),
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFEEF8F1,
                ),
                borderRadius:
                    BorderRadius.circular(
                  100,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFCDE5D4,
                  ),
                ),
              ),
              child:
                  const Row(
                mainAxisSize:
                    MainAxisSize.min,
                children: [
                  Icon(
                    Icons
                        .verified_rounded,
                    color:
                        _success,
                    size:
                        13,
                  ),

                  SizedBox(
                    width:
                        4,
                  ),

                  Text(
                    'Verified',
                    style:
                        TextStyle(
                      color:
                          _success,
                      fontSize:
                          8,
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerHero() {
    return Container(
      width:
          double.infinity,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          23,
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors:
              <Color>[
            _maroon,
            _maroon2,
            _maroonDark,
          ],
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                _maroon.withValues(
              alpha: 0.16,
            ),
            blurRadius:
                28,
            offset:
                const Offset(
              0,
              13,
            ),
          ),
        ],
      ),
      child:
          Stack(
        children: [
          Positioned(
            right:
                -45,
            top:
                -55,
            child:
                Container(
              width:
                  180,
              height:
                  180,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    Colors.white.withValues(
                  alpha: 0.06,
                ),
              ),
            ),
          ),

          Positioned(
            left:
                -60,
            bottom:
                -85,
            child:
                Container(
              width:
                  190,
              height:
                  190,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    _tan.withValues(
                  alpha: 0.12,
                ),
              ),
            ),
          ),

          Padding(
            padding:
                const EdgeInsets.all(
              19,
            ),
            child:
                Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    _SellerAvatar(
                      seller:
                          widget.seller,
                      size:
                          70,
                    ),

                    const SizedBox(
                      width:
                          13,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIKHAE SELLER',
                            style:
                                TextStyle(
                              color:
                                  Color(
                                0xFFE8C8B2,
                              ),
                              fontSize:
                                  7.5,
                              letterSpacing:
                                  1.4,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),

                          const SizedBox(
                            height:
                                5,
                          ),

                          Text(
                            widget.seller.name,
                            maxLines:
                                2,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Colors.white,
                              fontSize:
                                  22,
                              height:
                                  1.05,
                              letterSpacing:
                                  -0.5,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),

                          if (widget.seller.location
                                  ?.trim()
                                  .isNotEmpty ==
                              true) ...[
                            const SizedBox(
                              height:
                                  6,
                            ),

                            Row(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding:
                                      EdgeInsets.only(
                                    top:
                                        1,
                                  ),
                                  child:
                                      Icon(
                                    Icons
                                        .location_on_outlined,
                                    color:
                                        Color(
                                      0xFFE8C8B2,
                                    ),
                                    size:
                                        14,
                                  ),
                                ),

                                const SizedBox(
                                  width:
                                      4,
                                ),

                                Expanded(
                                  child:
                                      Text(
                                    widget.seller.location!,
                                    maxLines:
                                        2,
                                    overflow:
                                        TextOverflow.ellipsis,
                                    style:
                                        const TextStyle(
                                      color:
                                          Color(
                                        0xFFF4DED4,
                                      ),
                                      fontSize:
                                          9.5,
                                      height:
                                          1.35,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),

                if (widget.seller.description
                        ?.trim()
                        .isNotEmpty ==
                    true) ...[
                  const SizedBox(
                    height:
                        16,
                  ),

                  Text(
                    widget.seller.description!,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFFF4DED4,
                      ),
                      fontSize:
                          10.5,
                      height:
                          1.55,
                    ),
                  ),
                ],

                const SizedBox(
                  height:
                      17,
                ),

                SizedBox(
                  width:
                      double.infinity,
                  height:
                      46,
                  child:
                      ElevatedButton.icon(
                    onPressed:
                        widget.onMessageSeller,
                    style:
                        ElevatedButton.styleFrom(
                      elevation:
                          0,
                      backgroundColor:
                          const Color(
                        0xFFFFF7EF,
                      ),
                      foregroundColor:
                          _maroon,
                      disabledBackgroundColor:
                          Colors.white.withValues(
                        alpha: 0.18,
                      ),
                      disabledForegroundColor:
                          Colors.white.withValues(
                        alpha: 0.55,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          13,
                        ),
                      ),
                    ),
                    icon:
                        const Icon(
                      Icons
                          .chat_bubble_outline_rounded,
                      size:
                          17,
                    ),
                    label:
                        const Text(
                      'Message Seller',
                      style:
                          TextStyle(
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w800,
                      ),
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

  Widget _buildSellerDetails() {
    final List<_SellerStat> stats =
        <_SellerStat>[
      if (widget.seller.rating !=
          null)
        _SellerStat(
          label:
              'Rating',
          value:
              widget.seller.rating!
                  .toStringAsFixed(
            1,
          ),
          icon:
              Icons.star_rounded,
        ),

      if (widget.seller.followers
              ?.trim()
              .isNotEmpty ==
          true)
        _SellerStat(
          label:
              'Followers',
          value:
              widget.seller.followers!,
          icon:
              Icons.group_outlined,
        ),

      if (widget.seller.response
              ?.trim()
              .isNotEmpty ==
          true)
        _SellerStat(
          label:
              'Response',
          value:
              widget.seller.response!,
          icon:
              Icons.schedule_outlined,
        ),

      if (widget.seller.fulfillment
              ?.trim()
              .isNotEmpty ==
          true)
        _SellerStat(
          label:
              'Fulfillment',
          value:
              widget.seller.fulfillment!,
          icon:
              Icons.inventory_2_outlined,
        ),
    ];

    final bool hasJoined =
        widget.seller.joinedYear
                ?.trim()
                .isNotEmpty ==
            true;

    final bool hasHours =
        widget.seller.businessHours
                ?.trim()
                .isNotEmpty ==
            true;

    if (stats.isEmpty &&
        !hasJoined &&
        !hasHours) {
      return const SizedBox.shrink();
    }

    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (stats.isNotEmpty)
            LayoutBuilder(
              builder:
                  (
                BuildContext context,
                BoxConstraints constraints,
              ) {
                int columns;

                if (constraints.maxWidth <
                    340) {
                  columns =
                      stats.length >= 2
                          ? 2
                          : 1;
                } else {
                  columns =
                      stats.length;
                }

                if (columns >
                    4) {
                  columns =
                      4;
                }

                const double spacing =
                    8;

                final double width =
                    (constraints.maxWidth -
                            ((columns - 1) *
                                spacing)) /
                        columns;

                return Wrap(
                  spacing:
                      spacing,
                  runSpacing:
                      spacing,
                  children:
                      stats.map(
                    (
                      _SellerStat stat,
                    ) {
                      return SizedBox(
                        width:
                            width,
                        child:
                            _SellerStatCard(
                          stat:
                              stat,
                        ),
                      );
                    },
                  ).toList(),
                );
              },
            ),

          if (stats.isNotEmpty &&
              (hasJoined ||
                  hasHours))
            const SizedBox(
              height:
                  14,
            ),

          if (hasJoined)
            _SellerInfoRow(
              icon:
                  Icons
                      .calendar_month_outlined,
              label:
                  'Joined',
              value:
                  widget.seller.joinedYear!,
            ),

          if (hasJoined &&
              hasHours)
            const SizedBox(
              height:
                  10,
            ),

          if (hasHours)
            _SellerInfoRow(
              icon:
                  Icons
                      .access_time_rounded,
              label:
                  'Business Hours',
              value:
                  widget.seller.businessHours!,
            ),
        ],
      ),
    );
  }

  Widget _buildProductHeader(
    int visibleCount,
  ) {
    final bool filtering =
        _query.trim().isNotEmpty;

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.end,
      children: [
        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'STORE PRODUCTS',
                style:
                    TextStyle(
                  color:
                      _maroon,
                  fontSize:
                      8,
                  letterSpacing:
                      1.5,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    5,
              ),

              const Text(
                'Browse Products',
                style:
                    TextStyle(
                  color:
                      _text,
                  fontSize:
                      24,
                  height:
                      1.05,
                  letterSpacing:
                      -0.6,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    6,
              ),

              Text(
                filtering
                    ? '$visibleCount of ${_products.length} ${_products.length == 1 ? 'product' : 'products'}'
                    : '${_products.length} ${_products.length == 1 ? 'product' : 'products'} from this seller',
                style:
                    const TextStyle(
                  color:
                      _muted,
                  fontSize:
                      10,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndSort() {
    return Column(
      children: [
        TextField(
          controller:
              _searchController,
          textInputAction:
              TextInputAction.search,
          onChanged:
              (
            String value,
          ) {
            setState(() {
              _query =
                  value;
            });
          },
          decoration:
              InputDecoration(
            hintText:
                'Search this store...',
            hintStyle:
                const TextStyle(
              color:
                  _muted2,
              fontSize:
                  11,
            ),
            prefixIcon:
                const Icon(
              Icons
                  .search_rounded,
              color:
                  _muted,
              size:
                  20,
            ),
            suffixIcon:
                _query.trim().isEmpty
                    ? null
                    : IconButton(
                        tooltip:
                            'Clear search',
                        onPressed:
                            _clearSearch,
                        icon:
                            const Icon(
                          Icons
                              .close_rounded,
                          size:
                              18,
                          color:
                              _muted,
                        ),
                      ),
            filled:
                true,
            fillColor:
                _surface,
            contentPadding:
                const EdgeInsets.symmetric(
              horizontal:
                  13,
              vertical:
                  13,
            ),
            border:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  const BorderSide(
                color:
                    _border,
              ),
            ),
            enabledBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  const BorderSide(
                color:
                    _border,
              ),
            ),
            focusedBorder:
                OutlineInputBorder(
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              borderSide:
                  const BorderSide(
                color:
                    _tan,
                width:
                    1.3,
              ),
            ),
          ),
        ),

        const SizedBox(
          height:
              9,
        ),

        SizedBox(
          width:
              double.infinity,
          child:
              DropdownButtonFormField<
                  StoreProductSort>(
            initialValue:
                _sort,
            isExpanded:
                true,
            decoration:
                InputDecoration(
              prefixIcon:
                  const Icon(
                Icons
                    .sort_rounded,
                color:
                    _muted,
                size:
                    19,
              ),
              filled:
                  true,
              fillColor:
                  _surface,
              contentPadding:
                  const EdgeInsets.symmetric(
                horizontal:
                    13,
                vertical:
                    11,
              ),
              border:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      _border,
                ),
              ),
              enabledBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      _border,
                ),
              ),
              focusedBorder:
                  OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
                borderSide:
                    const BorderSide(
                  color:
                      _tan,
                ),
              ),
            ),
            items:
                StoreProductSort.values.map(
              (
                StoreProductSort sort,
              ) {
                return DropdownMenuItem<
                    StoreProductSort>(
                  value:
                      sort,
                  child:
                      Text(
                    sort.label,
                    style:
                        const TextStyle(
                      color:
                          _text,
                      fontSize:
                          10.5,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                );
              },
            ).toList(),
            onChanged:
                (
              StoreProductSort? value,
            ) {
              if (value == null) {
                return;
              }

              setState(() {
                _sort =
                    value;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyProducts() {
    final bool searching =
        _query.trim().isNotEmpty;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            24,
        vertical:
            45,
      ),
      decoration:
          BoxDecoration(
        color:
            _surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
      ),
      child:
          Column(
        children: [
          Container(
            width:
                62,
            height:
                62,
            decoration:
                const BoxDecoration(
              color:
                  _softStrong,
              shape:
                  BoxShape.circle,
            ),
            alignment:
                Alignment.center,
            child:
                Icon(
              searching
                  ? Icons
                      .search_off_rounded
                  : Icons
                      .inventory_2_outlined,
              color:
                  _maroon,
              size:
                  28,
            ),
          ),

          const SizedBox(
            height:
                15,
          ),

          Text(
            searching
                ? 'No matching products'
                : 'No products available',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  _text,
              fontSize:
                  16,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                6,
          ),

          Text(
            searching
                ? 'Try another product name or category.'
                : 'This seller does not have products available in this store right now.',
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  _muted,
              fontSize:
                  10,
              height:
                  1.45,
            ),
          ),

          if (searching) ...[
            const SizedBox(
              height:
                  15,
            ),

            OutlinedButton(
              onPressed:
                  _clearSearch,
              style:
                  OutlinedButton.styleFrom(
                foregroundColor:
                    _maroon,
                side:
                    const BorderSide(
                  color:
                      _tan,
                ),
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                ),
              ),
              child:
                  const Text(
                'Clear Search',
                style:
                    TextStyle(
                  fontSize:
                      10,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerAvatar
    extends StatelessWidget {
  final StoreSellerData seller;

  final double size;

  const _SellerAvatar({
    required this.seller,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? url =
        seller.avatarUrl?.trim();

    return Container(
      width:
          size,
      height:
          size,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            const Color(
          0xFFF1E4D7,
        ),
        border:
            Border.all(
          color:
              Colors.white,
          width:
              2,
        ),
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                const Color(
              0xFF3E130F,
            ).withValues(
              alpha: 0.16,
            ),
            blurRadius:
                15,
            offset:
                const Offset(
              0,
              6,
            ),
          ),
        ],
      ),
      child:
          url == null ||
                  url.isEmpty
              ? _SellerInitials(
                  initials:
                      seller.initials,
                )
              : Image.network(
                  url,
                  fit:
                      BoxFit.cover,
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
                      child:
                          SizedBox(
                        width:
                            18,
                        height:
                            18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              Color(
                            0xFF561C17,
                          ),
                        ),
                      ),
                    );
                  },
                  errorBuilder:
                      (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return _SellerInitials(
                      initials:
                          seller.initials,
                    );
                  },
                ),
    );
  }
}

class _SellerInitials
    extends StatelessWidget {
  final String initials;

  const _SellerInitials({
    required this.initials,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      color:
          const Color(
        0xFFF1E4D7,
      ),
      alignment:
          Alignment.center,
      child:
          Text(
        initials,
        style:
            const TextStyle(
          color:
              Color(
            0xFF561C17,
          ),
          fontSize:
              18,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _SellerStat {
  final String label;
  final String value;

  final IconData icon;

  const _SellerStat({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _SellerStatCard
    extends StatelessWidget {
  final _SellerStat stat;

  const _SellerStatCard({
    required this.stat,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            7,
        vertical:
            11,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFF6EFE7,
        ),
        borderRadius:
            BorderRadius.circular(
          12,
        ),
      ),
      child:
          Column(
        children: [
          Icon(
            stat.icon,
            color:
                const Color(
              0xFF561C17,
            ),
            size:
                18,
          ),

          const SizedBox(
            height:
                5,
          ),

          Text(
            stat.value,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF3B211B,
              ),
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height:
                2,
          ),

          Text(
            stat.label,
            maxLines:
                1,
            overflow:
                TextOverflow.ellipsis,
            textAlign:
                TextAlign.center,
            style:
                const TextStyle(
              color:
                  Color(
                0xFF987865,
              ),
              fontSize:
                  7.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String label;
  final String value;

  const _SellerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width:
              34,
          height:
              34,
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFF1E4D7,
            ),
            borderRadius:
                BorderRadius.circular(
              10,
            ),
          ),
          alignment:
              Alignment.center,
          child:
              Icon(
            icon,
            color:
                const Color(
              0xFF561C17,
            ),
            size:
                16,
          ),
        ),

        const SizedBox(
          width:
              9,
        ),

        Expanded(
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF987865,
                  ),
                  fontSize:
                      8,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height:
                    2,
              ),

              Text(
                value,
                style:
                    const TextStyle(
                  color:
                      Color(
                    0xFF3B211B,
                  ),
                  fontSize:
                      10,
                  height:
                      1.4,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreProductCard
    extends StatelessWidget {
  final StoreProductData product;

  final bool wishlistLoading;

  final VoidCallback onTap;
  final VoidCallback onWishlist;

  const _StoreProductCard({
    required this.product,
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
          const Color(
        0xFFFFFDF9,
      ),
      borderRadius:
          BorderRadius.circular(
        16,
      ),
      child:
          InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child:
            Container(
          clipBehavior:
              Clip.antiAlias,
          decoration:
              BoxDecoration(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            border:
                Border.all(
              color:
                  const Color(
                0xFFEADCCC,
              ),
            ),
          ),
          child:
              Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child:
                    Stack(
                  fit:
                      StackFit.expand,
                  children: [
                    Container(
                      color:
                          const Color(
                        0xFFF3ECE4,
                      ),
                      child:
                          _StoreProductImage(
                        url:
                            product.imageUrl,
                      ),
                    ),

                    if (discount !=
                        null)
                      Positioned(
                        left:
                            8,
                        top:
                            8,
                        child:
                            Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal:
                                7,
                            vertical:
                                5,
                          ),
                          decoration:
                              BoxDecoration(
                            color:
                                const Color(
                              0xFF561C17,
                            ),
                            borderRadius:
                                BorderRadius.circular(
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
                                  10,
                              fontWeight:
                                  FontWeight.w900,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      right:
                          8,
                      top:
                          8,
                      child:
                          Material(
                        color:
                            Colors.white.withValues(
                          alpha: 0.94,
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
                            width:
                                35,
                            height:
                                35,
                            child:
                                wishlistLoading
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.all(
                                          9,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              1.8,
                                          color:
                                              Color(
                                            0xFF561C17,
                                          ),
                                        ),
                                      )
                                    : Icon(
                                        product.wishlisted
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        size:
                                            18,
                                        color:
                                            const Color(
                                          0xFF561C17,
                                        ),
                                      ),
                          ),
                        ),
                      ),
                    ),

                    /*
                     * Unknown stock must NOT look like
                     * zero stock.
                     */
                    if (product.isOutOfStock)
                      Positioned.fill(
                        child:
                            Container(
                          color:
                              Colors.black.withValues(
                            alpha: 0.45,
                          ),
                          alignment:
                              Alignment.center,
                          child:
                              Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal:
                                  10,
                              vertical:
                                  6,
                            ),
                            decoration:
                                BoxDecoration(
                              color:
                                  Colors.black.withValues(
                                alpha: 0.62,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
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
                                    9,
                                letterSpacing:
                                    0.7,
                                fontWeight:
                                    FontWeight.w900,
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
                    const EdgeInsets.fromLTRB(
                  10,
                  10,
                  10,
                  11,
                ),
                child:
                    Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    if (product.category
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      Text(
                        product.category!
                            .toUpperCase(),
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF6C4936,
                          ),
                          fontSize:
                              9,
                          letterSpacing:
                              0.7,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),

                      const SizedBox(
                        height:
                            4,
                      ),
                    ],

                    Text(
                      product.name,
                      maxLines:
                          2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF3B211B,
                        ),
                        fontSize:
                            13,
                        height:
                            1.3,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      height:
                          7,
                    ),

                    Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      spacing:
                          4,
                      runSpacing:
                          2,
                      children: [
                        Text(
                          _formatPrice(
                            product.price,
                          ),
                          style:
                              const TextStyle(
                            color:
                                Color(
                              0xFF561C17,
                            ),
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight.w900,
                          ),
                        ),

                        if (product.originalPrice !=
                                null &&
                            product.originalPrice! >
                                product.price)
                          Text(
                            _formatPrice(
                              product.originalPrice!,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFFA99386,
                              ),
                              fontSize:
                                  9.5,
                              decoration:
                                  TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(
                      height:
                          7,
                    ),

                    Row(
                      children: [
                        if (product.rating !=
                            null) ...[
                          const Icon(
                            Icons.star_rounded,
                            color:
                                Color(
                              0xFFC88418,
                            ),
                            size:
                                14,
                          ),

                          const SizedBox(
                            width:
                                2,
                          ),

                          Text(
                            product.rating!
                                .toStringAsFixed(
                              1,
                            ),
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF3B211B,
                              ),
                              fontSize:
                                  9.5,
                              fontWeight:
                                  FontWeight.w700,
                            ),
                          ),

                          const SizedBox(
                            width:
                                5,
                          ),
                        ],

                        Expanded(
                          child:
                              Text(
                            '${product.soldCount} sold',
                            maxLines:
                                1,
                            overflow:
                                TextOverflow.ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF987865,
                              ),
                              fontSize:
                                  9.5,
                            ),
                          ),
                        ),

                        if (product.stock !=
                                null &&
                            product.stock! >
                                0)
                          Text(
                            '${product.stock} left',
                            style:
                                const TextStyle(
                              color:
                                  Color(
                                0xFF987865,
                              ),
                              fontSize:
                                  9,
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

  static String _formatPrice(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _StoreProductImage
    extends StatelessWidget {
  final String? url;

  const _StoreProductImage({
    required this.url,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final String? imageUrl =
        url?.trim();

    if (imageUrl == null ||
        imageUrl.isEmpty) {
      return const Center(
        child:
            Icon(
          Icons
              .inventory_2_outlined,
          color:
              Color(
            0xFFA99386,
          ),
          size:
              34,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(imageUrl);

    return Image.network(
      resolvedUrl,
      fit:
          BoxFit.cover,
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
          child:
              SizedBox(
            width:
                22,
            height:
                22,
            child:
                CircularProgressIndicator(
              strokeWidth:
                  2,
              color:
                  Color(
                0xFF561C17,
              ),
            ),
          ),
        );
      },
      errorBuilder:
          (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const Center(
          child:
              Icon(
            Icons
                .broken_image_outlined,
            color:
                Color(
              0xFFA99386,
            ),
            size:
                34,
          ),
        );
      },
    );
  }
}

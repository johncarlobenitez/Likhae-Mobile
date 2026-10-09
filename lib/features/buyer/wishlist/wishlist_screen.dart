import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

typedef WishlistProductCallback = Future<void> Function(
  WishlistProduct product,
);

typedef WishlistClearCallback = Future<void> Function();

typedef WishlistRefreshCallback =
    Future<List<WishlistProduct>> Function();

typedef WishlistProductSelectedCallback = void Function(
  WishlistProduct product,
);

class WishlistProduct {
  final int id;

  final String name;

  final String? slug;
  final String? category;

  final String? sellerName;
  final String? sellerSlug;
  final int? sellerUserId;

  final String? imageUrl;

  final double price;
  final double? originalPrice;

  final double? rating;

  final int reviewCount;
  final int soldCount;

  /// null = stock was not supplied to this page.
  ///
  /// 0 = explicitly out of stock.
  ///
  /// > 0 = available stock.
  final int? stock;

  /// Time this product was saved to the wishlist.
  ///
  /// This should eventually come from the wishlist pivot /
  /// wishlist record rather than the product's own createdAt.
  final DateTime? wishlistAddedAt;

  /// Kept as a fallback for older data mapping.
  final DateTime? createdAt;

  const WishlistProduct({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.sellerName,
    this.sellerSlug,
    this.sellerUserId,
    this.imageUrl,
    this.originalPrice,
    this.rating,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.stock,
    this.wishlistAddedAt,
    this.createdAt,
  });

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
    final int? available =
        stock;

    if (available == null) {
      return false;
    }

    return available < 1;
  }
}

enum WishlistSort {
  recent,
  priceLow,
  priceHigh,
  bestRated,
}

extension WishlistSortLabel on WishlistSort {
  String get label {
    switch (this) {
      case WishlistSort.recent:
        return 'Recently Added';

      case WishlistSort.priceLow:
        return 'Price: Low to High';

      case WishlistSort.priceHigh:
        return 'Price: High to Low';

      case WishlistSort.bestRated:
        return 'Best Rated';
    }
  }
}

class WishlistScreen extends StatefulWidget {
  final List<WishlistProduct> products;

  final VoidCallback? onBack;

  final VoidCallback? onContinueShopping;

  final VoidCallback? onCart;

  final VoidCallback? onNotifications;

  final WishlistProductSelectedCallback?
      onProductSelected;

  /// This is the important Laravel-compatible callback.
  ///
  /// Once mobile APIs are added, this should call the same
  /// wishlist toggle behavior used by the Buyer backend.
  final WishlistProductCallback? onRemoveProduct;

  /// Optional bulk-clear action.
  ///
  /// The current Laravel Buyer flow does not require a bulk
  /// clear endpoint, so the Clear Wishlist button is shown
  /// only when this callback is actually provided.
  final WishlistClearCallback? onClearWishlist;

  final WishlistRefreshCallback? onRefresh;

  final String initialSearchQuery;

  final WishlistSort initialSort;

  final int cartItemCount;

  final int unreadNotificationCount;

  const WishlistScreen({
    super.key,
    this.products =
        const <WishlistProduct>[],
    this.onBack,
    this.onContinueShopping,
    this.onCart,
    this.onNotifications,
    this.onProductSelected,
    this.onRemoveProduct,
    this.onClearWishlist,
    this.onRefresh,
    this.initialSearchQuery = '',
    this.initialSort =
        WishlistSort.recent,
    this.cartItemCount = 0,
    this.unreadNotificationCount = 0,
  });

  @override
  State<WishlistScreen> createState() =>
      _WishlistScreenState();
}

class _WishlistScreenState
    extends State<WishlistScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _backgroundSoft =
      Color(0xFFF6EFE7);

  static const Color _card =
      Color(0xFFFFFDF9);

  static const Color _border =
      Color(0xFFEADCCC);

  static const Color _borderStrong =
      Color(0xFFDBCEC1);

  static const Color _maroon =
      Color(0xFF561C17);

  static const Color _maroonDark =
      Color(0xFF3E130F);

  static const Color _text =
      Color(0xFF3B211B);

  static const Color _brown =
      Color(0xFF6C4936);

  static const Color _muted =
      Color(0xFF987865);

  static const Color _muted2 =
      Color(0xFFA99386);

  static const Color _tan =
      Color(0xFFC19771);

  static const Color _danger =
      Color(0xFFB42318);

  late final TextEditingController
      _searchController;

  late List<WishlistProduct> _wishlist;

  late String _searchQuery;

  late WishlistSort _activeSort;

  final Set<int> _removingProductIds =
      <int>{};

  bool _clearingWishlist = false;

  @override
  void initState() {
    super.initState();

    _wishlist =
        List<WishlistProduct>.from(
      widget.products,
    );

    _searchQuery =
        widget.initialSearchQuery;

    _activeSort =
        widget.initialSort;

    _searchController =
        TextEditingController(
      text: _searchQuery,
    );
  }

  @override
  void didUpdateWidget(
    covariant WishlistScreen oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.products !=
        widget.products) {
      _wishlist =
          List<WishlistProduct>.from(
        widget.products,
      );

      _removingProductIds.removeWhere(
        (int productId) {
          return !_wishlist.any(
            (
              WishlistProduct product,
            ) =>
                product.id ==
                productId,
          );
        },
      );
    }

    if (oldWidget.initialSearchQuery !=
        widget.initialSearchQuery) {
      _searchQuery =
          widget.initialSearchQuery;

      _searchController.text =
          widget.initialSearchQuery;
    }

    if (oldWidget.initialSort !=
        widget.initialSort) {
      _activeSort =
          widget.initialSort;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<WishlistProduct>
      get _visibleWishlist {
    final String query =
        _searchQuery
            .trim()
            .toLowerCase();

    final List<WishlistProduct> result =
        _wishlist.where(
      (
        WishlistProduct product,
      ) {
        if (query.isEmpty) {
          return true;
        }

        final String searchableText =
            <String>[
          product.name,
          product.category ?? '',
          product.sellerName ?? '',
        ].join(' ').toLowerCase();

        return searchableText.contains(
          query,
        );
      },
    ).toList();

    switch (_activeSort) {
      case WishlistSort.priceLow:
        result.sort(
          (
            WishlistProduct a,
            WishlistProduct b,
          ) =>
              a.price.compareTo(
            b.price,
          ),
        );
        break;

      case WishlistSort.priceHigh:
        result.sort(
          (
            WishlistProduct a,
            WishlistProduct b,
          ) =>
              b.price.compareTo(
            a.price,
          ),
        );
        break;

      case WishlistSort.bestRated:
        result.sort(
          (
            WishlistProduct a,
            WishlistProduct b,
          ) =>
              (b.rating ?? 0)
                  .compareTo(
            a.rating ?? 0,
          ),
        );
        break;

      case WishlistSort.recent:
        result.sort(
          (
            WishlistProduct a,
            WishlistProduct b,
          ) {
            final DateTime? dateA =
                a.wishlistAddedAt ??
                    a.createdAt;

            final DateTime? dateB =
                b.wishlistAddedAt ??
                    b.createdAt;

            if (dateA != null &&
                dateB != null) {
              return dateB.compareTo(
                dateA,
              );
            }

            if (dateA != null) {
              return -1;
            }

            if (dateB != null) {
              return 1;
            }

            return b.id.compareTo(
              a.id,
            );
          },
        );
        break;
    }

    return result;
  }

  Future<void> _removeProduct(
    WishlistProduct product,
  ) async {
    if (_removingProductIds.contains(
      product.id,
    )) {
      return;
    }

    final WishlistProductCallback? callback =
        widget.onRemoveProduct;

    if (callback == null) {
      _showMessage(
        'Wishlist removal will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _removingProductIds.add(
        product.id,
      );
    });

    try {
      await callback(
        product,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _wishlist.removeWhere(
          (
            WishlistProduct item,
          ) =>
              item.id ==
              product.id,
        );
      });

      _showMessage(
        '${product.name} removed from your wishlist.',
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
          _removingProductIds.remove(
            product.id,
          );
        });
      }
    }
  }

  Future<void> _confirmClearWishlist() async {
    if (_wishlist.isEmpty ||
        _clearingWishlist) {
      return;
    }

    final WishlistClearCallback? callback =
        widget.onClearWishlist;

    if (callback == null) {
      return;
    }

    final bool? confirmed =
        await showDialog<bool>(
      context: context,
      builder: (
        BuildContext dialogContext,
      ) {
        return AlertDialog(
          backgroundColor:
              _card,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              20,
            ),
          ),
          title:
              const Text(
            'Clear wishlist?',
            style:
                TextStyle(
              color:
                  _text,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'This will remove all ${_wishlist.length} saved ${_wishlist.length == 1 ? 'product' : 'products'} from your wishlist.',
            style:
                const TextStyle(
              color:
                  _muted,
              fontSize:
                  13,
              height:
                  1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  false,
                );
              },
              child:
                  const Text(
                'Cancel',
                style:
                    TextStyle(
                  color:
                      _brown,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(
                  dialogContext,
                ).pop(
                  true,
                );
              },
              style:
                  ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor:
                    _danger,
                foregroundColor:
                    Colors.white,
              ),
              child:
                  const Text(
                'Clear Wishlist',
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true ||
        !mounted) {
      return;
    }

    setState(() {
      _clearingWishlist = true;
    });

    try {
      await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _wishlist.clear();

        _searchController.clear();

        _searchQuery = '';
      });

      _showMessage(
        'Your wishlist has been cleared.',
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
          _clearingWishlist = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    final WishlistRefreshCallback? callback =
        widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      final List<WishlistProduct> refreshed = await callback();
      if (!mounted) return;
      setState(() {
        _wishlist = List<WishlistProduct>.from(refreshed);
      });
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    }
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
  }

  Future<void> _showSortSheet() async {
    final WishlistSort? selected =
        await showModalBottomSheet<WishlistSort>(
      context: context,
      backgroundColor:
          Colors.transparent,
      builder: (
        BuildContext sheetContext,
      ) {
        return SafeArea(
          child: Container(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              10,
              20,
              24,
            ),
            decoration:
                const BoxDecoration(
              color: _card,
              borderRadius:
                  BorderRadius.vertical(
                top:
                    Radius.circular(
                  26,
                ),
              ),
            ),
            child: Column(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration:
                      BoxDecoration(
                    color:
                        _borderStrong,
                    borderRadius:
                        BorderRadius.circular(
                      100,
                    ),
                  ),
                ),

                const SizedBox(
                  height: 18,
                ),

                const Row(
                  children: [
                    Text(
                      'Sort wishlist',
                      style:
                          TextStyle(
                        color:
                            _text,
                        fontSize:
                            19,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                  ],
                ),

                const SizedBox(
                  height: 10,
                ),

                for (final WishlistSort sort
                    in WishlistSort.values)
                  ListTile(
                    contentPadding:
                        EdgeInsets.zero,
                    onTap: () {
                      Navigator.of(
                        sheetContext,
                      ).pop(
                        sort,
                      );
                    },
                    title:
                        Text(
                      sort.label,
                      style:
                          TextStyle(
                        color:
                            _text,
                        fontSize:
                            13,
                        fontWeight:
                            sort ==
                                    _activeSort
                                ? FontWeight.w800
                                : FontWeight.w500,
                      ),
                    ),
                    trailing:
                        sort ==
                                _activeSort
                            ? const Icon(
                                Icons
                                    .check_circle_rounded,
                                color:
                                    _maroon,
                              )
                            : null,
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (selected == null ||
        !mounted) {
      return;
    }

    setState(() {
      _activeSort =
          selected;
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
          content: Text(
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
    final List<WishlistProduct>
        visibleProducts =
        _visibleWishlist;

    return Scaffold(
      backgroundColor:
          _background,
      body: SafeArea(
        bottom: false,
        child: Column(
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
                        16,
                        8,
                        16,
                        0,
                      ),
                      sliver:
                          SliverToBoxAdapter(
                        child:
                            Column(
                          children: [
                            _buildHero(),

                            const SizedBox(
                              height:
                                  16,
                            ),

                            if (_wishlist
                                .isNotEmpty) ...[
                              _buildSummary(),

                              const SizedBox(
                                height:
                                    14,
                              ),

                              _buildToolbar(),

                              const SizedBox(
                                height:
                                    13,
                              ),

                              _buildResultSummary(
                                visibleProducts
                                    .length,
                              ),

                              const SizedBox(
                                height:
                                    14,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    if (_wishlist.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody:
                            false,
                        child:
                            _buildEmptyWishlist(),
                      )
                    else if (visibleProducts
                        .isEmpty)
                      SliverFillRemaining(
                        hasScrollBody:
                            false,
                        child:
                            _buildNoSearchResults(),
                      )
                    else
                      _buildWishlistGrid(
                        visibleProducts,
                      ),

                    const SliverToBoxAdapter(
                      child:
                          SizedBox(
                        height: 100,
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
        8,
        6,
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
      child: Row(
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
            width: 2,
          ),

          const Expanded(
            child: Row(
              children: [
                Text(
                  'LIKHAE',
                  style:
                      TextStyle(
                    color:
                        _maroon,
                    fontSize:
                        18,
                    letterSpacing:
                        1,
                    fontWeight:
                        FontWeight.w900,
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
                          _tan,
                      shape:
                          BoxShape.circle,
                    ),
                  ),
                ),

                SizedBox(
                  width: 7,
                ),

                Flexible(
                  child:
                      Text(
                    'Wishlist',
                    overflow:
                        TextOverflow.ellipsis,
                    style:
                        TextStyle(
                      color:
                          _muted,
                      fontSize:
                          10,
                      fontWeight:
                          FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          _TopIconButton(
            icon:
                Icons
                    .notifications_none_rounded,
            tooltip:
                'Notifications',
            badgeCount:
                widget
                    .unreadNotificationCount,
            onTap:
                widget.onNotifications,
          ),

          const SizedBox(
            width: 7,
          ),

          _TopIconButton(
            icon:
                Icons
                    .shopping_bag_outlined,
            tooltip:
                'Cart',
            badgeCount:
                widget.cartItemCount,
            onTap:
                widget.onCart,
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        20,
        22,
        20,
        20,
      ),
      decoration:
          BoxDecoration(
        borderRadius:
            BorderRadius.circular(
          23,
        ),
        border:
            Border.all(
          color:
              _border,
        ),
        gradient:
            const LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: <Color>[
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
        boxShadow:
            <BoxShadow>[
          BoxShadow(
            color:
                _maroon.withValues(
              alpha: 0.055,
            ),
            blurRadius:
                24,
            offset:
                const Offset(
              0,
              9,
            ),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -55,
            child:
                Container(
              width:
                  150,
              height:
                  150,
              decoration:
                  BoxDecoration(
                shape:
                    BoxShape.circle,
                color:
                    _tan.withValues(
                  alpha: 0.15,
                ),
              ),
            ),
          ),

          Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'SAVED PRODUCTS',
                style:
                    TextStyle(
                  color:
                      _maroon,
                  fontSize:
                      8.5,
                  letterSpacing:
                      1.8,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),

              const SizedBox(
                height:
                    7,
              ),

              const Text.rich(
                TextSpan(
                  children:
                      <InlineSpan>[
                    TextSpan(
                      text:
                          'Your Wishlist',
                    ),
                    TextSpan(
                      text:
                          '.',
                      style:
                          TextStyle(
                        color:
                            _maroon,
                        fontStyle:
                            FontStyle.italic,
                      ),
                    ),
                  ],
                ),
                style:
                    TextStyle(
                  color:
                      _text,
                  fontSize:
                      31,
                  height:
                      1,
                  letterSpacing:
                      -0.8,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),

              const SizedBox(
                height:
                    10,
              ),

              const Text(
                'Keep your favorite LIKHAE products in one place and revisit them anytime. Price and stock can change while a product remains saved.',
                style:
                    TextStyle(
                  color:
                      _muted,
                  fontSize:
                      11,
                  height:
                      1.55,
                ),
              ),

              const SizedBox(
                height:
                    17,
              ),

              SizedBox(
                height:
                    44,
                child:
                    OutlinedButton.icon(
                  onPressed:
                      widget
                          .onContinueShopping,
                  style:
                      OutlinedButton.styleFrom(
                    foregroundColor:
                        _maroon,
                    side:
                        const BorderSide(
                      color:
                          _tan,
                    ),
                    padding:
                        const EdgeInsets.symmetric(
                      horizontal:
                          15,
                    ),
                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        12,
                      ),
                    ),
                  ),
                  icon:
                      const Icon(
                    Icons
                        .shopping_bag_outlined,
                    size:
                        17,
                  ),
                  label:
                      const Text(
                    'Continue Shopping',
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
        ],
      ),
    );
  }

  Widget _buildSummary() {
    final int count =
        _wishlist.length;

    final int unavailableCount =
        _wishlist
            .where(
              (
                WishlistProduct product,
              ) =>
                  product.isOutOfStock,
            )
            .length;

    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            _card,
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
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width:
                    48,
                height:
                    48,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    15,
                  ),
                ),
                alignment:
                    Alignment.center,
                child:
                    const Icon(
                  Icons
                      .favorite_rounded,
                  color:
                      _maroon,
                  size:
                      22,
                ),
              ),

              const SizedBox(
                width:
                    12,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count ${count == 1 ? 'saved product' : 'saved products'}',
                      style:
                          const TextStyle(
                        color:
                            _text,
                        fontSize:
                            13,
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),

                    const SizedBox(
                      height:
                          3,
                    ),

                    Text(
                      unavailableCount >
                              0
                          ? '$unavailableCount ${unavailableCount == 1 ? 'saved product is' : 'saved products are'} currently out of stock.'
                          : 'Revisit any saved product whenever you are ready.',
                      style:
                          const TextStyle(
                        color:
                            _muted,
                        fontSize:
                            9.5,
                        height:
                            1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (widget.onClearWishlist !=
              null) ...[
            const SizedBox(
              height:
                  12,
            ),

            SizedBox(
              width:
                  double.infinity,
              height:
                  42,
              child:
                  OutlinedButton.icon(
                onPressed:
                    _clearingWishlist
                        ? null
                        : _confirmClearWishlist,
                style:
                    OutlinedButton.styleFrom(
                  foregroundColor:
                      _danger,
                  side:
                      const BorderSide(
                    color:
                        Color(
                      0xFFE6B8AD,
                    ),
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      11,
                    ),
                  ),
                ),
                icon:
                    _clearingWishlist
                        ? const SizedBox(
                            width:
                                16,
                            height:
                                16,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  _danger,
                            ),
                          )
                        : const Icon(
                            Icons
                                .delete_outline_rounded,
                            size:
                                17,
                          ),
                label:
                    const Text(
                  'Clear Wishlist',
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
        ],
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        12,
      ),
      decoration:
          BoxDecoration(
        color:
            _card,
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
      child: Column(
        children: [
          TextField(
            controller:
                _searchController,
            keyboardType:
                TextInputType.text,
            textInputAction:
                TextInputAction.search,
            onChanged:
                (
              String value,
            ) {
              setState(() {
                _searchQuery =
                    value;
              });
            },
            decoration:
                InputDecoration(
              hintText:
                  'Search saved products...',
              hintStyle:
                  const TextStyle(
                color:
                    _muted2,
                fontSize:
                    11.5,
              ),
              prefixIcon:
                  const Icon(
                Icons
                    .search_rounded,
                color:
                    _muted2,
                size:
                    19,
              ),
              suffixIcon:
                  _searchQuery
                          .trim()
                          .isNotEmpty
                      ? IconButton(
                          tooltip:
                              'Clear search',
                          onPressed:
                              _clearSearch,
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                            size:
                                17,
                            color:
                                _muted,
                          ),
                        )
                      : null,
              filled:
                  true,
              fillColor:
                  _backgroundSoft,
              contentPadding:
                  const EdgeInsets.symmetric(
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

          Material(
            color:
                _backgroundSoft,
            borderRadius:
                BorderRadius.circular(
              13,
            ),
            child:
                InkWell(
              onTap:
                  _showSortSheet,
              borderRadius:
                  BorderRadius.circular(
                13,
              ),
              child:
                  Container(
                height:
                    46,
                padding:
                    const EdgeInsets.symmetric(
                  horizontal:
                      13,
                ),
                decoration:
                    BoxDecoration(
                  border:
                      Border.all(
                    color:
                        _border,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child:
                    Row(
                  children: [
                    const Icon(
                      Icons
                          .sort_rounded,
                      color:
                          _maroon,
                      size:
                          19,
                    ),

                    const SizedBox(
                      width:
                          8,
                    ),

                    const Text(
                      'Sort by',
                      style:
                          TextStyle(
                        color:
                            _muted,
                        fontSize:
                            10.5,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const Spacer(),

                    Flexible(
                      child:
                          Text(
                        _activeSort.label,
                        maxLines:
                            1,
                        overflow:
                            TextOverflow.ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _text,
                          fontSize:
                              10.5,
                          fontWeight:
                              FontWeight.w800,
                        ),
                      ),
                    ),

                    const SizedBox(
                      width:
                          5,
                    ),

                    const Icon(
                      Icons
                          .keyboard_arrow_down_rounded,
                      color:
                          _brown,
                      size:
                          19,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultSummary(
    int visibleCount,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child:
              Text.rich(
            TextSpan(
              children:
                  <InlineSpan>[
                const TextSpan(
                  text:
                      'Showing ',
                ),
                TextSpan(
                  text:
                      '$visibleCount',
                  style:
                      const TextStyle(
                    color:
                        _maroon,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const TextSpan(
                  text:
                      ' of ',
                ),
                TextSpan(
                  text:
                      '${_wishlist.length}',
                  style:
                      const TextStyle(
                    color:
                        _maroon,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
                const TextSpan(
                  text:
                      ' saved products',
                ),
              ],
            ),
            style:
                const TextStyle(
              color:
                  _muted,
              fontSize:
                  10.5,
              fontWeight:
                  FontWeight.w600,
            ),
          ),
        ),

        if (_searchQuery
            .trim()
            .isNotEmpty) ...[
          const SizedBox(
            width:
                8,
          ),

          Flexible(
            child:
                Text(
              '“${_searchQuery.trim()}”',
              maxLines:
                  1,
              overflow:
                  TextOverflow.ellipsis,
              textAlign:
                  TextAlign.right,
              style:
                  const TextStyle(
                color:
                    _brown,
                fontSize:
                    10.5,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWishlistGrid(
    List<WishlistProduct> products,
  ) {
    return SliverPadding(
      padding:
          const EdgeInsets.symmetric(
        horizontal:
            16,
      ),
      sliver:
          SliverLayoutBuilder(
        builder:
            (
          BuildContext context,
          constraints,
        ) {
          final double width =
              constraints.crossAxisExtent;

          final int columns;

          if (width < 340) {
            columns = 1;
          } else if (width >= 760) {
            columns = 3;
          } else {
            columns = 2;
          }

          return SliverGrid(
            delegate:
                SliverChildBuilderDelegate(
              (
                BuildContext context,
                int index,
              ) {
                final WishlistProduct product =
                    products[index];

                return _WishlistProductCard(
                  product:
                      product,
                  removing:
                      _removingProductIds.contains(
                    product.id,
                  ),
                  onTap: () {
                    widget
                        .onProductSelected
                        ?.call(
                      product,
                    );
                  },
                  onRemove: () {
                    _removeProduct(
                      product,
                    );
                  },
                );
              },
              childCount:
                  products.length,
            ),
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
                      ? 1.62
                      : 0.63,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyWishlist() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  68,
              height:
                  68,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF1E4D7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              alignment:
                  Alignment.center,
              child:
                  const Icon(
                Icons
                    .favorite_border_rounded,
                color:
                    _maroon,
                size:
                    30,
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            const Text(
              'Your wishlist is empty',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    _text,
                fontSize:
                    19,
                fontWeight:
                    FontWeight.w900,
                letterSpacing:
                    -0.4,
              ),
            ),

            const SizedBox(
              height:
                  7,
            ),

            const Text(
              'Save products you love by tapping the heart icon on a marketplace product.',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    _muted,
                fontSize:
                    11,
                height:
                    1.5,
              ),
            ),

            const SizedBox(
              height:
                  20,
            ),

            SizedBox(
              height:
                  45,
              child:
                  ElevatedButton.icon(
                onPressed:
                    widget
                        .onContinueShopping,
                style:
                    ElevatedButton.styleFrom(
                  elevation:
                      0,
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal:
                        18,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                ),
                icon:
                    const Icon(
                  Icons
                      .shopping_bag_outlined,
                  size:
                      17,
                ),
                label:
                    const Text(
                  'Explore Products',
                  style:
                      TextStyle(
                    fontSize:
                        11,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoSearchResults() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          30,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            Container(
              width:
                  68,
              height:
                  68,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFFF1E4D7,
                ),
                borderRadius:
                    BorderRadius.circular(
                  20,
                ),
              ),
              alignment:
                  Alignment.center,
              child:
                  const Icon(
                Icons
                    .search_off_rounded,
                color:
                    _maroon,
                size:
                    31,
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            const Text(
              'No matching saved products',
              textAlign:
                  TextAlign.center,
              style:
                  TextStyle(
                color:
                    _text,
                fontSize:
                    18,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height:
                  7,
            ),

            Text(
              'We could not find a wishlist product matching “${_searchQuery.trim()}”.',
              textAlign:
                  TextAlign.center,
              style:
                  const TextStyle(
                color:
                    _muted,
                fontSize:
                    11,
                height:
                    1.5,
              ),
            ),

            const SizedBox(
              height:
                  18,
            ),

            OutlinedButton.icon(
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
              icon:
                  const Icon(
                Icons
                    .refresh_rounded,
                size:
                    16,
              ),
              label:
                  const Text(
                'Clear Search',
                style:
                    TextStyle(
                  fontSize:
                      10.5,
                  fontWeight:
                      FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WishlistProductCard
    extends StatelessWidget {
  final WishlistProduct product;

  final bool removing;

  final VoidCallback onTap;

  final VoidCallback onRemove;

  const _WishlistProductCard({
    required this.product,
    required this.removing,
    required this.onTap,
    required this.onRemove,
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
      child: InkWell(
        onTap:
            removing
                ? null
                : onTap,
        borderRadius:
            BorderRadius.circular(
          16,
        ),
        child: Container(
          clipBehavior:
              Clip.antiAlias,
          decoration:
              BoxDecoration(
            color:
                const Color(
              0xFFFFFDF9,
            ),
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
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
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
                          _WishlistProductImage(
                        imageUrl:
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
                              7,
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
                                  FontWeight.w800,
                            ),
                          ),
                        ),
                      ),

                    Positioned(
                      right:
                          7,
                      top:
                          7,
                      child:
                          Material(
                        color:
                            Colors.white.withValues(
                          alpha: 0.95,
                        ),
                        shape:
                            const CircleBorder(),
                        child:
                            InkWell(
                          onTap:
                              removing
                                  ? null
                                  : onRemove,
                          customBorder:
                              const CircleBorder(),
                          child:
                              SizedBox(
                            width:
                                35,
                            height:
                                35,
                            child:
                                removing
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.all(
                                          9,
                                        ),
                                        child:
                                            CircularProgressIndicator(
                                          strokeWidth:
                                              2,
                                          color:
                                              Color(
                                            0xFF561C17,
                                          ),
                                        ),
                                      )
                                    : const Icon(
                                        Icons
                                            .favorite_rounded,
                                        color:
                                            Color(
                                          0xFF561C17,
                                        ),
                                        size:
                                            19,
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
                              Colors.black.withValues(
                            alpha: 0.42,
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
                                alpha: 0.65,
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
                                      10,
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
                  11,
                  10,
                  11,
                  12,
                ),
                child: Column(
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
                            5,
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
                            1.25,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    if (product.sellerName
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(
                        height:
                            5,
                      ),

                      Text(
                        product.sellerName!,
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
                              10,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height:
                          8,
                    ),

                    Wrap(
                      crossAxisAlignment:
                          WrapCrossAlignment.center,
                      spacing:
                          5,
                      runSpacing:
                          3,
                      children: [
                        Text(
                          _price(
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
                            _price(
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
                                13,
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

                          if (product.reviewCount >
                              0) ...[
                            const SizedBox(
                              width:
                                  2,
                            ),

                            Text(
                              '(${product.reviewCount})',
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
                            !product
                                .isOutOfStock)
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

  static String _price(
    double value,
  ) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _WishlistProductImage
    extends StatelessWidget {
  final String? imageUrl;

  const _WishlistProductImage({
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
        child:
            Icon(
          Icons
              .inventory_2_outlined,
          color:
              Color(
            0xFFA99386,
          ),
          size:
              36,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(url);

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
          child: SizedBox(
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
                36,
          ),
        );
      },
    );
  }
}

class _TopIconButton
    extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final int badgeCount;

  final VoidCallback? onTap;

  const _TopIconButton({
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
        Tooltip(
          message:
              tooltip,
          child:
              Material(
            color:
                const Color(
              0xFFFFFDF9,
            ),
            borderRadius:
                BorderRadius.circular(
              12,
            ),
            child:
                InkWell(
              onTap:
                  onTap,
              borderRadius:
                  BorderRadius.circular(
                12,
              ),
              child:
                  Container(
                width:
                    40,
                height:
                    40,
                alignment:
                    Alignment.center,
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    12,
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
                    Icon(
                  icon,
                  color:
                      const Color(
                    0xFF561C17,
                  ),
                  size:
                      19,
                ),
              ),
            ),
          ),
        ),

        if (badgeCount >
            0)
          Positioned(
            right:
                -4,
            top:
                -5,
            child:
                Container(
              constraints:
                  const BoxConstraints(
                minWidth:
                    18,
                minHeight:
                    18,
              ),
              padding:
                  const EdgeInsets.symmetric(
                horizontal:
                    4,
              ),
              alignment:
                  Alignment.center,
              decoration:
                  BoxDecoration(
                color:
                    const Color(
                  0xFF561C17,
                ),
                borderRadius:
                    BorderRadius.circular(
                  100,
                ),
                border:
                    Border.all(
                  color:
                      const Color(
                    0xFFFBF7F2,
                  ),
                  width:
                      2,
                ),
              ),
              child:
                  Text(
                badgeCount >
                        99
                    ? '99+'
                    : '$badgeCount',
                style:
                    const TextStyle(
                  color:
                      Colors.white,
                  fontSize:
                      7,
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

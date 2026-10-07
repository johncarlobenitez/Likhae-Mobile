import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/services/product_service.dart';

typedef BuyerProductCallback = void Function(BuyerProduct product);

typedef BuyerProductWishlistCallback =
    Future<void> Function(BuyerProduct product);

typedef BuyerProductsRefreshCallback = Future<void> Function();

class BuyerProduct {
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
  final int soldCount;

  /// Nullable because older marketplace payloads may not
  /// provide stock yet.
  ///
  /// null = stock not supplied to this page
  /// 0    = explicitly out of stock
  /// > 0  = available
  final int? stock;

  /// The actual wishlist state that should eventually come
  /// from Laravel.
  final bool wishlisted;

  const BuyerProduct({
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
    this.soldCount = 0,
    this.stock,
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

  static BuyerProduct? fromApi(dynamic json) {
    if (json is! Map) {
      return null;
    }

    final Map<String, dynamic> data = Map<String, dynamic>.from(json);

    final dynamic rawId = data['id'] ?? data['product_id'];
    final dynamic rawName = data['name'] ?? data['product_name'];
    final dynamic rawPrice =
        data['price'] ?? data['amount'] ?? data['min_price'];

    if (rawId == null || rawName == null || rawPrice == null) {
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

    final String slugValue = _firstNonEmptyString(
      data['slug'],
      data['product_slug'],
      data['slug_name'],
    );

    final double parsedPrice = (rawPrice is num)
        ? rawPrice.toDouble()
        : double.tryParse(rawPrice.toString()) ?? 0;

    final double? originalPrice =
        (data['original_price'] ?? data['originalPrice']) is num
        ? (data['original_price'] ?? data['originalPrice']).toDouble()
        : double.tryParse(
            (data['original_price'] ?? data['originalPrice']).toString(),
          );

    return BuyerProduct(
      id: int.tryParse(rawId.toString()) ?? 0,
      name: rawName.toString(),
      slug: slugValue.isNotEmpty ? slugValue : null,
      category: categoryValue.isNotEmpty ? categoryValue : null,
      sellerName: sellerNameValue.isNotEmpty ? sellerNameValue : null,
      imageUrl: imageValue.isNotEmpty ? imageValue : null,
      price: parsedPrice,
      originalPrice: originalPrice,
      rating: (data['rating'] is num)
          ? (data['rating'] as num).toDouble()
          : double.tryParse(data['rating']?.toString() ?? ''),
      soldCount:
          int.tryParse(data['sold_count']?.toString() ?? '') ??
          int.tryParse(data['soldCount']?.toString() ?? '') ??
          0,
      stock: data['stock'] is num
          ? (data['stock'] as num).toInt()
          : int.tryParse(data['stock']?.toString() ?? ''),
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
    String? slug,
    String? category,
    String? sellerName,
    String? sellerSlug,
    String? imageUrl,
    double? price,
    double? originalPrice,
    double? rating,
    int? soldCount,
    int? stock,
    bool? wishlisted,
  }) {
    return BuyerProduct(
      id: id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      category: category ?? this.category,
      sellerName: sellerName ?? this.sellerName,
      sellerSlug: sellerSlug ?? this.sellerSlug,
      imageUrl: imageUrl ?? this.imageUrl,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      rating: rating ?? this.rating,
      soldCount: soldCount ?? this.soldCount,
      stock: stock ?? this.stock,
      wishlisted: wishlisted ?? this.wishlisted,
    );
  }
}

enum BuyerProductSort { recommended, priceLow, priceHigh, rating, sold }

extension BuyerProductSortInfo on BuyerProductSort {
  String get label {
    switch (this) {
      case BuyerProductSort.recommended:
        return 'Recommended';

      case BuyerProductSort.priceLow:
        return 'Price: Low to High';

      case BuyerProductSort.priceHigh:
        return 'Price: High to Low';

      case BuyerProductSort.rating:
        return 'Highest Rated';

      case BuyerProductSort.sold:
        return 'Best Selling';
    }
  }

  String get badgeLabel {
    switch (this) {
      case BuyerProductSort.recommended:
        return 'RECOMMENDED';

      case BuyerProductSort.priceLow:
        return 'LOWEST PRICE';

      case BuyerProductSort.priceHigh:
        return 'HIGHEST PRICE';

      case BuyerProductSort.rating:
        return 'TOP RATED';

      case BuyerProductSort.sold:
        return 'BEST SELLING';
    }
  }
}

class ProductsScreen extends StatefulWidget {
  final List<BuyerProduct> products;

  final BuyerProductCallback? onProductSelected;

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

  const ProductsScreen({
    super.key,
    this.products = const [],
    this.onProductSelected,
    this.onWishlistProduct,
    this.onRefresh,
    this.onBack,
    this.onCart,
    this.onNotifications,
    this.initialSearchQuery = '',
    this.initialSort = BuyerProductSort.recommended,
  });

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonDark = Color(0xFF3E130F);

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _mutedLight = Color(0xFFA99386);

  static const Color _tan = Color(0xFFC19771);

  static const Color _danger = Color(0xFFB42318);

  late final TextEditingController _searchController;

  late List<BuyerProduct> _products;

  bool _isLoading = false;
  String? _errorMessage;

  late String _searchQuery;

  late BuyerProductSort _sort;

  final Set<int> _wishlistLoading = <int>{};

  @override
  void initState() {
    super.initState();

    _products = List<BuyerProduct>.from(widget.products);

    _searchQuery = widget.initialSearchQuery;

    _sort = widget.initialSort;

    _searchController = TextEditingController(text: _searchQuery);

    if (_products.isEmpty) {
      _loadProducts();
    }
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
          await ProductService.fetchProductRows();
      final List<BuyerProduct> loadedProducts = rows
          .map(BuyerProduct.fromApi)
          .whereType<BuyerProduct>()
          .where((BuyerProduct product) => product.id != 0)
          .toList(growable: false);

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
    }

    if (oldWidget.initialSearchQuery != widget.initialSearchQuery) {
      _searchQuery = widget.initialSearchQuery;

      _searchController.text = _searchQuery;
    }

    if (oldWidget.initialSort != widget.initialSort) {
      _sort = widget.initialSort;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();

    super.dispose();
  }

  List<BuyerProduct> get _filteredProducts {
    List<BuyerProduct> result = _products.where((BuyerProduct product) {
      final String query = _searchQuery.trim().toLowerCase();

      if (query.isEmpty) {
        return true;
      }

      final String searchableText = <String>[
        product.name,
        product.category ?? '',
        product.sellerName ?? '',
      ].join(' ').toLowerCase();

      return searchableText.contains(query);
    }).toList();

    switch (_sort) {
      case BuyerProductSort.recommended:
        break;

      case BuyerProductSort.priceLow:
        result.sort(
          (BuyerProduct a, BuyerProduct b) => a.price.compareTo(b.price),
        );
        break;

      case BuyerProductSort.priceHigh:
        result.sort(
          (BuyerProduct a, BuyerProduct b) => b.price.compareTo(a.price),
        );
        break;

      case BuyerProductSort.rating:
        result.sort(
          (BuyerProduct a, BuyerProduct b) =>
              (b.rating ?? 0).compareTo(a.rating ?? 0),
        );
        break;

      case BuyerProductSort.sold:
        result.sort(
          (BuyerProduct a, BuyerProduct b) =>
              b.soldCount.compareTo(a.soldCount),
        );
        break;
    }

    return result;
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

      final bool newState = !_products[index].wishlisted;

      setState(() {
        _products[index] = _products[index].copyWith(wishlisted: newState);
      });

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
    });
  }

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _searchQuery = '';
    });
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
    final List<BuyerProduct> products = _filteredProducts;

    if (_isLoading && products.isEmpty) {
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
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refreshProducts,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(child: _buildSearchArea()),

                    SliverToBoxAdapter(
                      child: _buildCatalogHeader(products.length),
                    ),

                    if (_errorMessage != null && products.isEmpty)
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
                    else if (products.isEmpty)
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: _buildEmptyState(),
                      )
                    else
                      _buildProductGrid(products),

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
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 12, 8),
      color: _background,
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(context).maybePop();
                },
            icon: const Icon(Icons.arrow_back_rounded, color: _text),
          ),

          const SizedBox(width: 2),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Products',
                  style: TextStyle(
                    color: _text,
                    fontSize: 21,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Find products from trusted local sellers.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),

          _HeaderButton(
            icon: Icons.notifications_none_rounded,
            tooltip: 'Notifications',
            onTap: widget.onNotifications,
          ),

          const SizedBox(width: 7),

          _HeaderButton(
            icon: Icons.shopping_bag_outlined,
            tooltip: 'Cart',
            onTap: widget.onCart,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (String value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Search products, shops...',
                hintStyle: const TextStyle(color: _mutedLight, fontSize: 12),
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
                child: const Icon(Icons.tune_rounded, color: _maroon, size: 21),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCatalogHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Explore Products',
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
                  count == 1 ? '1 product found' : '$count products found',
                  style: const TextStyle(color: _muted, fontSize: 10.5),
                ),
              ],
            ),
          ),

          const SizedBox(width: 10),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFF1E4D7),
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverLayoutBuilder(
        builder: (BuildContext context, constraints) {
          final double width = constraints.crossAxisExtent;

          final int columns;

          if (width < 340) {
            columns = 1;
          } else if (width >= 900) {
            columns = 4;
          } else if (width >= 700) {
            columns = 3;
          } else {
            columns = 2;
          }

          return SliverGrid(
            delegate: SliverChildBuilderDelegate((
              BuildContext context,
              int index,
            ) {
              final BuyerProduct product = products[index];

              return _ProductCard(
                product: product,
                wishlistLoading: _wishlistLoading.contains(product.id),
                onWishlist: () {
                  _toggleWishlist(product);
                },
                onTap: () {
                  widget.onProductSelected?.call(product);
                },
              );
            }, childCount: products.length),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 10,
              mainAxisSpacing: 12,
              childAspectRatio: columns == 1 ? 1.65 : 0.64,
            ),
          );
        },
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
                color: Color(0xFFF1E4D7),
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

  const _ProductCard({
    required this.product,
    required this.wishlistLoading,
    required this.onWishlist,
    required this.onTap,
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
            color: const Color(0xFFFFFDF9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFEADCCC)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: const Color(0xFFF3ECE4),
                      child: _ProductImage(imageUrl: product.imageUrl),
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
                            color: const Color(0xFF561C17),
                            borderRadius: BorderRadius.circular(7),
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
                      right: 7,
                      top: 7,
                      child: Material(
                        color: Colors.white.withValues(alpha: 0.94),
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
                                      color: Color(0xFF561C17),
                                    ),
                                  )
                                : Icon(
                                    product.wishlisted
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    color: const Color(0xFF561C17),
                                    size: 18,
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
                padding: const EdgeInsets.fromLTRB(11, 10, 11, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.category?.trim().isNotEmpty == true) ...[
                      Text(
                        product.category!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF6C4936),
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
                        color: Color(0xFF3B211B),
                        fontSize: 13,
                        height: 1.25,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (product.sellerName?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),

                      Text(
                        product.sellerName!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF987865),
                          fontSize: 10,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 5,
                      runSpacing: 2,
                      children: [
                        Text(
                          _price(product.price),
                          style: const TextStyle(
                            color: Color(0xFF561C17),
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price)
                          Text(
                            _price(product.originalPrice!),
                            style: const TextStyle(
                              color: Color(0xFFA99386),
                              fontSize: 9.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 7),

                    Row(
                      children: [
                        if (product.rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFC88418),
                            size: 13,
                          ),

                          const SizedBox(width: 2),

                          Text(
                            product.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF3B211B),
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
                              color: Color(0xFF987865),
                              fontSize: 9.5,
                            ),
                          ),
                        ),

                        if (product.stock != null && !product.isOutOfStock)
                          Text(
                            '${product.stock} left',
                            style: const TextStyle(
                              color: Color(0xFF987865),
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

  static String _price(double price) {
    return '₱${price.toStringAsFixed(2)}';
  }
}

class _ProductImage extends StatelessWidget {
  final String? imageUrl;

  const _ProductImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFFA99386),
          size: 36,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(url);

    return Image.network(
      resolvedUrl,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF561C17),
                ),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
            return const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Color(0xFFA99386),
                size: 36,
              ),
            );
          },
    );
  }
}

class _HeaderButton extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final VoidCallback? onTap;

  const _HeaderButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFFFFDF9),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFEADCCC)),
          ),
          child: Icon(icon, color: const Color(0xFF561C17), size: 19),
        ),
      ),
    );
  }
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
          color: const Color(0xFF3B211B),
          fontSize: 13,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w500,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: Color(0xFF561C17))
          : null,
    );
  }
}

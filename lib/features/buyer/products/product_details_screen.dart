import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

typedef ProductActionCallback = Future<void> Function(
  ProductDetailData product,
  int quantity,
  Map<String, String> selectedVariants,
);

typedef ProductPurchaseCallback = Future<void> Function(
  ProductPurchaseRequest request,
);

typedef ProductWishlistCallback = Future<void> Function(
  ProductDetailData product,
);

typedef ProductNavigationCallback = void Function(
  ProductDetailData product,
);

class ProductVariationData {
  final int id;

  /// Example:
  /// Color
  /// Size
  /// Cover
  final String name;

  /// Example:
  /// Red
  /// Large
  /// Softcover
  final String value;

  /// Laravel allows variation stock to be nullable.
  /// When null, the product-level stock is used.
  final int? stock;

  /// Laravel variation price can replace the base
  /// product price.
  final double? price;

  const ProductVariationData({
    required this.id,
    required this.name,
    required this.value,
    this.stock,
    this.price,
  });

  String get label {
    final String cleanName = name.trim();
    final String cleanValue = value.trim();

    if (cleanName.isEmpty) {
      return cleanValue;
    }

    if (cleanValue.isEmpty) {
      return cleanName;
    }

    return '$cleanName: $cleanValue';
  }
}

class ProductReviewData {
  final String id;

  final String buyerName;
  final String? buyerAvatarUrl;

  final int rating;

  final String body;
  final String date;

  final bool hasPhoto;

  const ProductReviewData({
    required this.id,
    required this.buyerName,
    required this.rating,
    required this.body,
    this.buyerAvatarUrl,
    this.date = '',
    this.hasPhoto = false,
  });

  String get buyerInitial {
    final String clean =
        buyerName.trim();

    if (clean.isEmpty) {
      return 'B';
    }

    return clean[0].toUpperCase();
  }
}

class ProductDetailData {
  final int id;

  final String name;
  final String? slug;

  final String? category;

  final String? imageUrl;
  final List<String> imageUrls;

  final double price;
  final double? originalPrice;

  final int stock;

  final double? rating;
  final int reviewCount;
  final int soldCount;

  final String? description;

  final String? sellerName;
  final String? sellerSlug;
  final String? sellerAvatarUrl;
  final String? sellerLocation;

  final bool sellerVerified;

  final List<ProductVariationData> variations;

  final Map<String, String> specifications;

  final List<ProductReviewData> reviews;

  final bool wishlisted;

  const ProductDetailData({
    required this.id,
    required this.name,
    required this.price,
    this.slug,
    this.category,
    this.imageUrl,
    this.imageUrls = const [],
    this.originalPrice,
    this.stock = 0,
    this.rating,
    this.reviewCount = 0,
    this.soldCount = 0,
    this.description,
    this.sellerName,
    this.sellerSlug,
    this.sellerAvatarUrl,
    this.sellerLocation,
    this.sellerVerified = true,
    this.variations = const [],
    this.specifications = const {},
    this.reviews = const [],
    this.wishlisted = false,
  });

  List<String> get galleryImages {
    final List<String> result =
        <String>[];

    for (final String image
        in imageUrls) {
      final String clean =
          image.trim();

      if (clean.isNotEmpty &&
          !result.contains(clean)) {
        result.add(clean);
      }
    }

    final String? main =
        imageUrl?.trim();

    if (main != null &&
        main.isNotEmpty &&
        !result.contains(main)) {
      result.insert(
        0,
        main,
      );
    }

    return result;
  }

  double? get discountPercentage {
    final double? original =
        originalPrice;

    if (original == null ||
        original <= 0 ||
        original <= price) {
      return null;
    }

    return ((original - price) /
            original) *
        100;
  }

  String get sellerInitial {
    final String clean =
        sellerName?.trim() ?? '';

    if (clean.isEmpty) {
      return 'S';
    }

    return clean[0].toUpperCase();
  }

  factory ProductDetailData.fromApi(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['db_id'];
    final dynamic rawPrice = json['price'];
    final dynamic rawImage = json['image_url'] ?? json['image'];
    final dynamic gallery = json['gallery'] ?? json['images'] ?? <dynamic>[];
    final dynamic variations = json['variations'] ?? <String, dynamic>{};
    final dynamic specs = json['specs'] ?? <String, dynamic>{};

    final List<String> galleryImages = <String>[];
    if (gallery is List) {
      for (final dynamic item in gallery) {
        if (item is Map) {
          final String? imageUrl = (item['image_url'] ?? item['path'] ?? item['url'])?.toString();
          if (imageUrl != null && imageUrl.trim().isNotEmpty) {
            galleryImages.add(AppConfig.resolveMediaUrl(imageUrl));
          }
        }
      }
    }

    final List<ProductVariationData> parsedVariations = <ProductVariationData>[];
    if (variations is Map<String, dynamic>) {
      variations.forEach((String groupName, dynamic groupValue) {
        if (groupValue is List) {
          for (final dynamic item in groupValue) {
            if (item is Map) {
              final Map<String, dynamic> value = Map<String, dynamic>.from(item);
              parsedVariations.add(
                ProductVariationData(
                  id: int.tryParse(value['id']?.toString() ?? '') ?? 0,
                  name: groupName,
                  value: value['value']?.toString() ?? '',
                  stock: int.tryParse(value['stock']?.toString() ?? ''),
                  price: double.tryParse(value['price']?.toString() ?? ''),
                ),
              );
            }
          }
        }
      });
    }

    final Map<String, String> parsedSpecs = <String, String>{};
    if (specs is Map) {
      for (final MapEntry<dynamic, dynamic> entry in specs.entries) {
        parsedSpecs[entry.key.toString()] = entry.value?.toString() ?? '';
      }
    }

    return ProductDetailData(
      id: int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: (json['name'] ?? 'Product').toString(),
      slug: json['slug']?.toString(),
      category: json['category']?.toString() ?? json['parent_category']?.toString(),
      imageUrl: rawImage == null ? null : AppConfig.resolveMediaUrl(rawImage.toString()),
      imageUrls: galleryImages,
      price: double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      originalPrice: double.tryParse(json['old_price']?.toString() ?? json['original_price']?.toString() ?? ''),
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? '0'),
      reviewCount: int.tryParse(json['reviews']?.toString() ?? json['review_count']?.toString() ?? '0') ?? 0,
      soldCount: int.tryParse(json['sold']?.toString() ?? json['sold_count']?.toString() ?? '0') ?? 0,
      description: json['description']?.toString(),
      sellerName: json['seller']?.toString() ?? json['seller_name']?.toString(),
      sellerSlug: json['seller_slug']?.toString(),
      sellerAvatarUrl: json['seller_avatar']?.toString(),
      sellerLocation: json['location']?.toString(),
      variations: parsedVariations,
      specifications: parsedSpecs,
      wishlisted: json['wishlisted'] == true,
    );
  }

  ProductDetailData copyWith({
    bool? wishlisted,
  }) {
    return ProductDetailData(
      id: id,
      name: name,
      price: price,
      slug: slug,
      category: category,
      imageUrl: imageUrl,
      imageUrls: imageUrls,
      originalPrice: originalPrice,
      stock: stock,
      rating: rating,
      reviewCount: reviewCount,
      soldCount: soldCount,
      description: description,
      sellerName: sellerName,
      sellerSlug: sellerSlug,
      sellerAvatarUrl: sellerAvatarUrl,
      sellerLocation: sellerLocation,
      sellerVerified:
          sellerVerified,
      variations: variations,
      specifications:
          specifications,
      reviews: reviews,
      wishlisted:
          wishlisted ??
          this.wishlisted,
    );
  }
}

class ProductPurchaseRequest {
  final int productId;
  final String? productSlug;

  final int quantity;

  final int? productVariationId;

  /// Matches the website's variation value sent as
  /// "variant".
  final String? variant;

  final Map<String, String>
      selectedVariants;

  const ProductPurchaseRequest({
    required this.productId,
    required this.quantity,
    required this.selectedVariants,
    this.productSlug,
    this.productVariationId,
    this.variant,
  });
}

class ProductDetailsScreen
    extends StatefulWidget {
  final ProductDetailData product;

  /// Preferred related-product collection.
  final List<ProductDetailData>
      relatedProducts;

  /// Kept as an alias so this screen can also accept
  /// marketplace products passed from older page wiring.
  final List<ProductDetailData>
      products;

  final int initialQuantity;
  final int? initialVariationId;

  final bool? initialWishlisted;

  final VoidCallback? onBack;
  final VoidCallback? onCart;

  /// Existing callback format from the first Flutter
  /// conversion.
  final ProductActionCallback?
      onAddToCart;

  /// Existing callback format from the first Flutter
  /// conversion.
  final ProductActionCallback?
      onBuyNow;

  /// New request callback containing the actual variation
  /// ID needed by Laravel.
  ///
  /// When supplied, this takes priority over
  /// [onAddToCart].
  final ProductPurchaseCallback?
      onAddToCartRequest;

  /// New request callback containing the actual variation
  /// ID needed by Laravel.
  ///
  /// When supplied, this takes priority over [onBuyNow].
  final ProductPurchaseCallback?
      onBuyNowRequest;

  final ProductWishlistCallback?
      onWishlistToggle;

  /// Alias supported for easier wiring.
  final ProductWishlistCallback?
      onWishlist;

  final ProductNavigationCallback?
      onViewStore;

  final ProductNavigationCallback?
      onMessageSeller;

  final ProductNavigationCallback?
      onRelatedProductSelected;

  final Future<void> Function()?
      onRefresh;

  const ProductDetailsScreen({
    super.key,
    required this.product,
    this.relatedProducts = const [],
    this.products = const [],
    this.initialQuantity = 1,
    this.initialVariationId,
    this.initialWishlisted,
    this.onBack,
    this.onCart,
    this.onAddToCart,
    this.onBuyNow,
    this.onAddToCartRequest,
    this.onBuyNowRequest,
    this.onWishlistToggle,
    this.onWishlist,
    this.onViewStore,
    this.onMessageSeller,
    this.onRelatedProductSelected,
    this.onRefresh,
  });

  @override
  State<ProductDetailsScreen>
      createState() =>
          _ProductDetailsScreenState();
}

class _ProductDetailsScreenState
    extends State<ProductDetailsScreen> {
  static const Color _background =
      Color(0xFFFBF7F2);

  static const Color _surface =
      Color(0xFFFFFDF9);

  static const Color _softStrong =
      Color(0xFFF1E4D7);

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

  static const Color _star =
      Color(0xFFC88418);

  static const Color _success =
      Color(0xFF256F4A);

  static const Color _danger =
      Color(0xFFB42318);

  final PageController
      _galleryController =
      PageController();

  late ProductDetailData _product;

  ProductVariationData?
      _selectedVariation;

  late int _quantity;

  late bool _wishlisted;

  int _currentImageIndex = 0;

  bool _addingToCart = false;
  bool _buyingNow = false;
  bool _updatingWishlist = false;

  bool _descriptionExpanded =
      false;

  @override
  void initState() {
    super.initState();

    _product = widget.product;

    _quantity = widget
        .initialQuantity
        .clamp(
          1,
          999999,
        )
        .toInt();

    _wishlisted =
        widget.initialWishlisted ??
        _product.wishlisted;

    _selectedVariation =
        _resolveInitialVariation();

    _clampQuantity();
  }

  @override
  void didUpdateWidget(
    covariant ProductDetailsScreen
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (oldWidget.product.id !=
            widget.product.id ||
        oldWidget.product !=
            widget.product) {
      _product = widget.product;

      _wishlisted =
          widget.initialWishlisted ??
          _product.wishlisted;

      _quantity = widget
          .initialQuantity
          .clamp(
            1,
            999999,
          )
          .toInt();

      _selectedVariation =
          _resolveInitialVariation();

      _currentImageIndex = 0;
      _descriptionExpanded =
          false;

      _clampQuantity();

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          if (!mounted ||
              !_galleryController
                  .hasClients) {
            return;
          }

          _galleryController.jumpToPage(
            0,
          );
        },
      );
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();

    super.dispose();
  }

  ProductVariationData?
      _resolveInitialVariation() {
    final List<ProductVariationData>
        variations =
        _product.variations;

    if (variations.isEmpty) {
      return null;
    }

    final int? requestedId =
        widget.initialVariationId;

    if (requestedId != null) {
      for (final ProductVariationData
          variation in variations) {
        if (variation.id ==
            requestedId) {
          return variation;
        }
      }
    }

    /*
     * The website normally exposes a selected variation
     * through aria-pressed. For mobile, select the first
     * available option so price/stock/quantity are always
     * synchronized immediately.
     */
    for (final ProductVariationData
        variation in variations) {
      if (_variationStock(
            variation,
          ) >
          0) {
        return variation;
      }
    }

    return variations.first;
  }

  int _variationStock(
    ProductVariationData variation,
  ) {
    return variation.stock ??
        _product.stock;
  }

  int get _availableStock {
    final ProductVariationData?
        variation =
        _selectedVariation;

    if (variation != null) {
      return _variationStock(
        variation,
      );
    }

    return _product.stock;
  }

  bool get _outOfStock {
    return _availableStock < 1;
  }

  double get _displayPrice {
    return _selectedVariation
            ?.price ??
        _product.price;
  }

  List<String> get _images {
    return _product.galleryImages;
  }

  Map<String, String>
      get _selectedVariantMap {
    final ProductVariationData?
        variation =
        _selectedVariation;

    if (variation == null) {
      return const {};
    }

    final String key =
        variation.name
                .trim()
                .isEmpty
            ? 'variant'
            : variation.name;

    return <String, String>{
      key: variation.value,
    };
  }

  ProductPurchaseRequest
      get _purchaseRequest {
    final ProductVariationData?
        variation =
        _selectedVariation;

    return ProductPurchaseRequest(
      productId: _product.id,
      productSlug: _product.slug,
      quantity: _quantity,
      productVariationId:
          variation?.id,
      variant:
          variation?.value,
      selectedVariants:
          _selectedVariantMap,
    );
  }

  List<ProductDetailData>
      get _relatedProducts {
    final List<ProductDetailData>
        source =
        widget.relatedProducts
                .isNotEmpty
            ? widget.relatedProducts
            : widget.products;

    return source
        .where(
          (
            ProductDetailData product,
          ) =>
              product.id !=
              _product.id,
        )
        .take(6)
        .toList();
  }

  void _clampQuantity() {
    final int stock =
        _availableStock;

    if (stock < 1) {
      _quantity = 1;
      return;
    }

    if (_quantity < 1) {
      _quantity = 1;
    }

    if (_quantity > stock) {
      _quantity = stock;
    }
  }

  void _selectVariation(
    ProductVariationData variation,
  ) {
    if (_selectedVariation?.id ==
        variation.id) {
      return;
    }

    setState(() {
      _selectedVariation =
          variation;

      _clampQuantity();
    });
  }

  void _decreaseQuantity() {
    if (_quantity <= 1) {
      return;
    }

    setState(() {
      _quantity--;
    });
  }

  void _increaseQuantity() {
    final int stock =
        _availableStock;

    if (stock < 1 ||
        _quantity >= stock) {
      return;
    }

    setState(() {
      _quantity++;
    });
  }

  Future<void> _toggleWishlist() async {
    if (_updatingWishlist) {
      return;
    }

    final ProductWishlistCallback?
        callback =
        widget.onWishlistToggle ??
        widget.onWishlist;

    if (callback == null) {
      _showMessage(
        'Wishlist will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _updatingWishlist = true;
    });

    try {
      await callback(
        _product,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _wishlisted =
            !_wishlisted;

        _product =
            _product.copyWith(
          wishlisted:
              _wishlisted,
        );
      });

      _showMessage(
        _wishlisted
            ? 'Product saved to your wishlist.'
            : 'Product removed from your wishlist.',
      );
    } catch (error) {
      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingWishlist = false;
        });
      }
    }
  }

  Future<void> _addToCart() async {
    if (_addingToCart ||
        _buyingNow) {
      return;
    }

    if (!_validatePurchase()) {
      return;
    }

    if (widget.onAddToCartRequest ==
            null &&
        widget.onAddToCart == null) {
      _showMessage(
        'Cart API will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _addingToCart = true;
    });

    try {
      if (widget
              .onAddToCartRequest !=
          null) {
        await widget
            .onAddToCartRequest!(
          _purchaseRequest,
        );
      } else {
        await widget.onAddToCart!(
          _product,
          _quantity,
          _selectedVariantMap,
        );
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        '$_quantity item${_quantity == 1 ? '' : 's'} added to your cart.',
      );
    } catch (error) {
      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _addingToCart = false;
        });
      }
    }
  }

  Future<void> _buyNow() async {
    if (_buyingNow ||
        _addingToCart) {
      return;
    }

    if (!_validatePurchase()) {
      return;
    }

    if (widget.onBuyNowRequest ==
            null &&
        widget.onBuyNow == null) {
      _showMessage(
        'Buy Now will be connected to checkout later.',
      );

      return;
    }

    setState(() {
      _buyingNow = true;
    });

    try {
      /*
       * This intentionally does NOT call Add to Cart.
       *
       * Website behavior:
       * Add to Cart -> /buyer/cart?add=...
       * Buy Now     -> /buyer/checkout?buy=...
       */
      if (widget.onBuyNowRequest !=
          null) {
        await widget.onBuyNowRequest!(
          _purchaseRequest,
        );
      } else {
        await widget.onBuyNow!(
          _product,
          _quantity,
          _selectedVariantMap,
        );
      }
    } catch (error) {
      _showMessage(
        _errorText(error),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _buyingNow = false;
        });
      }
    }
  }

  bool _validatePurchase() {
    if (_product.variations
            .isNotEmpty &&
        _selectedVariation == null) {
      _showMessage(
        'Choose a product option first.',
        error: true,
      );

      return false;
    }

    if (_availableStock < 1) {
      _showMessage(
        'This product option is out of stock.',
        error: true,
      );

      return false;
    }

    if (_quantity < 1 ||
        _quantity >
            _availableStock) {
      _showMessage(
        'Choose a valid quantity.',
        error: true,
      );

      return false;
    }

    return true;
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
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
            style: const TextStyle(
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

  @override
  Widget build(BuildContext context) {
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
                color: _maroon,
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
                          _buildGallery(),
                    ),

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
                            _buildProductInformation(),
                      ),
                    ),

                    if (_product
                        .variations
                        .isNotEmpty)
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
                              _buildVariations(),
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
                            _buildQuantitySection(),
                      ),
                    ),

                    if (_product
                            .sellerName
                            ?.trim()
                            .isNotEmpty ==
                        true)
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
                              _buildSellerCard(),
                        ),
                      ),

                    if (_product
                            .description
                            ?.trim()
                            .isNotEmpty ==
                        true)
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
                              _buildDescription(),
                        ),
                      ),

                    if (_product
                        .specifications
                        .isNotEmpty)
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
                              _buildSpecifications(),
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
                            _buildReviews(),
                      ),
                    ),

                    if (_relatedProducts
                        .isNotEmpty)
                      SliverPadding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          14,
                          22,
                          14,
                          0,
                        ),
                        sliver:
                            SliverToBoxAdapter(
                          child:
                              _buildRelatedProducts(),
                        ),
                      ),

                    const SliverToBoxAdapter(
                      child:
                          SizedBox(
                        height: 120,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            _buildPurchaseBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        6,
        4,
        7,
        5,
      ),
      decoration:
          const BoxDecoration(
        color: _surface,
        border: Border(
          bottom: BorderSide(
            color: _border,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon: const Icon(
              Icons
                  .arrow_back_rounded,
              color: _text,
            ),
          ),

          const Expanded(
            child: Text(
              'Product Details',
              style: TextStyle(
                color: _text,
                fontSize: 16,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          IconButton(
            tooltip: 'Wishlist',
            onPressed:
                _updatingWishlist
                    ? null
                    : _toggleWishlist,
            icon:
                _updatingWishlist
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                          color:
                              _maroon,
                        ),
                      )
                    : Icon(
                        _wishlisted
                            ? Icons
                                .favorite_rounded
                            : Icons
                                .favorite_border_rounded,
                        color:
                            _maroon,
                      ),
          ),

          IconButton(
            tooltip: 'Cart',
            onPressed:
                widget.onCart,
            icon: const Icon(
              Icons
                  .shopping_bag_outlined,
              color: _maroon,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGallery() {
    final List<String> images =
        _images;

    return Container(
      color: _surface,
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: Stack(
              children: [
                Positioned.fill(
                  child:
                      images.isEmpty
                          ? Container(
                              color:
                                  const Color(
                                0xFFF3ECE4,
                              ),
                              alignment:
                                  Alignment.center,
                              child:
                                  const Icon(
                                Icons
                                    .inventory_2_outlined,
                                color:
                                    _muted2,
                                size: 54,
                              ),
                            )
                          : PageView.builder(
                              controller:
                                  _galleryController,
                              itemCount:
                                  images.length,
                              onPageChanged:
                                  (
                                int index,
                              ) {
                                setState(() {
                                  _currentImageIndex =
                                      index;
                                });
                              },
                              itemBuilder:
                                  (
                                BuildContext
                                    context,
                                int index,
                              ) {
                                return _ProductImage(
                                  url:
                                      images[index],
                                );
                              },
                            ),
                ),

                if (_product
                        .discountPercentage !=
                    null)
                  Positioned(
                    left: 14,
                    top: 14,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration:
                          BoxDecoration(
                        color: _maroon,
                        borderRadius:
                            BorderRadius
                                .circular(
                          9,
                        ),
                      ),
                      child: Text(
                        '-${_product.discountPercentage!.round()}%',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    ),
                  ),

                if (images.length > 1)
                  Positioned(
                    right: 14,
                    bottom: 14,
                    child: Container(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 9,
                        vertical: 5,
                      ),
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.black
                                .withValues(
                          alpha: 0.58,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          100,
                        ),
                      ),
                      child: Text(
                        '${_currentImageIndex + 1}/${images.length}',
                        style:
                            const TextStyle(
                          color:
                              Colors.white,
                          fontSize:
                              9,
                          fontWeight:
                              FontWeight
                                  .w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (images.length > 1)
            SizedBox(
              height: 82,
              child:
                  ListView.separated(
                padding:
                    const EdgeInsets
                        .fromLTRB(
                  13,
                  10,
                  13,
                  10,
                ),
                scrollDirection:
                    Axis.horizontal,
                physics:
                    const BouncingScrollPhysics(),
                itemCount:
                    images.length,
                separatorBuilder:
                    (
                  BuildContext context,
                  int index,
                ) =>
                        const SizedBox(
                  width: 8,
                ),
                itemBuilder:
                    (
                  BuildContext context,
                  int index,
                ) {
                  final bool active =
                      index ==
                      _currentImageIndex;

                  return GestureDetector(
                    onTap: () {
                      _galleryController
                          .animateToPage(
                        index,
                        duration:
                            const Duration(
                          milliseconds:
                              220,
                        ),
                        curve:
                            Curves.easeOut,
                      );
                    },
                    child: Container(
                      width: 61,
                      clipBehavior:
                          Clip.antiAlias,
                      decoration:
                          BoxDecoration(
                        borderRadius:
                            BorderRadius
                                .circular(
                          11,
                        ),
                        border:
                            Border.all(
                          color:
                              active
                                  ? _maroon
                                  : _border,
                          width:
                              active
                                  ? 2
                                  : 1,
                        ),
                      ),
                      child:
                          _ProductImage(
                        url:
                            images[index],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProductInformation() {
    return Container(
      padding:
          const EdgeInsets.all(
        16,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: _border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          if (_product
                  .category
                  ?.trim()
                  .isNotEmpty ==
              true) ...[
            Text(
              _product.category!
                  .toUpperCase(),
              style:
                  const TextStyle(
                color: _brown,
                fontSize: 8,
                letterSpacing:
                    1.1,
                fontWeight:
                    FontWeight.w900,
              ),
            ),

            const SizedBox(
              height: 7,
            ),
          ],

          Text(
            _product.name,
            style:
                const TextStyle(
              color: _text,
              fontSize: 21,
              height: 1.17,
              letterSpacing:
                  -0.5,
              fontWeight:
                  FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 10,
          ),

          Wrap(
            spacing: 12,
            runSpacing: 6,
            crossAxisAlignment:
                WrapCrossAlignment.center,
            children: [
              if (_product.rating !=
                  null)
                Row(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: _star,
                      size: 16,
                    ),

                    const SizedBox(
                      width: 3,
                    ),

                    Text(
                      _product.rating!
                          .toStringAsFixed(
                        1,
                      ),
                      style:
                          const TextStyle(
                        color: _text,
                        fontSize: 10,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    Text(
                      ' (${_product.reviewCount})',
                      style:
                          const TextStyle(
                        color:
                            _muted,
                        fontSize: 9,
                      ),
                    ),
                  ],
                ),

              Text(
                '${_product.soldCount} sold',
                style:
                    const TextStyle(
                  color: _muted,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          Row(
            crossAxisAlignment:
                CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  _formatPrice(
                    _displayPrice,
                  ),
                  style:
                      const TextStyle(
                    color: _maroon,
                    fontSize: 25,
                    height: 1,
                    fontWeight:
                        FontWeight.w900,
                  ),
                ),
              ),

              if (_selectedVariation ==
                      null &&
                  _product
                          .originalPrice !=
                      null &&
                  _product
                          .originalPrice! >
                      _product.price) ...[
                const SizedBox(
                  width: 8,
                ),

                Padding(
                  padding:
                      const EdgeInsets.only(
                    bottom: 2,
                  ),
                  child: Text(
                    _formatPrice(
                      _product
                          .originalPrice!,
                    ),
                    style:
                        const TextStyle(
                      color: _muted2,
                      fontSize: 11,
                      decoration:
                          TextDecoration
                              .lineThrough,
                    ),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(
            height: 12,
          ),

          Container(
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 8,
            ),
            decoration:
                BoxDecoration(
              color:
                  _outOfStock
                      ? const Color(
                          0xFFFCECE7,
                        )
                      : const Color(
                          0xFFEEF8F1,
                        ),
              borderRadius:
                  BorderRadius
                      .circular(
                10,
              ),
            ),
            child: Row(
              mainAxisSize:
                  MainAxisSize.min,
              children: [
                Icon(
                  _outOfStock
                      ? Icons
                          .cancel_outlined
                      : Icons
                          .check_circle_outline_rounded,
                  color:
                      _outOfStock
                          ? _danger
                          : _success,
                  size: 15,
                ),

                const SizedBox(
                  width: 5,
                ),

                Text(
                  _outOfStock
                      ? 'Out of stock'
                      : '$_availableStock available',
                  style:
                      TextStyle(
                    color:
                        _outOfStock
                            ? _danger
                            : _success,
                    fontSize: 9,
                    fontWeight:
                        FontWeight
                            .w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariations() {
    return _DetailSection(
      title: 'Choose Option',
      subtitle:
          'Select the product variation you want.',
      icon:
          Icons.tune_rounded,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children:
            _product.variations.map(
          (
            ProductVariationData
                variation,
          ) {
            final bool selected =
                _selectedVariation
                        ?.id ==
                    variation.id;

            final int stock =
                _variationStock(
              variation,
            );

            return Material(
              color:
                  selected
                      ? _softStrong
                      : _surface,
              borderRadius:
                  BorderRadius.circular(
                11,
              ),
              child: InkWell(
                onTap: () {
                  _selectVariation(
                    variation,
                  );
                },
                borderRadius:
                    BorderRadius.circular(
                  11,
                ),
                child: Container(
                  padding:
                      const EdgeInsets
                          .symmetric(
                    horizontal: 13,
                    vertical: 10,
                  ),
                  decoration:
                      BoxDecoration(
                    borderRadius:
                        BorderRadius
                            .circular(
                      11,
                    ),
                    border:
                        Border.all(
                      color:
                          selected
                              ? _maroon
                              : stock < 1
                              ? _borderStrong
                              : _border,
                      width:
                          selected
                              ? 1.5
                              : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      if (selected) ...[
                        const Icon(
                          Icons
                              .check_circle_rounded,
                          color:
                              _maroon,
                          size: 15,
                        ),

                        const SizedBox(
                          width: 5,
                        ),
                      ],

                      Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            variation
                                .label,
                            style:
                                TextStyle(
                              color:
                                  selected
                                      ? _maroon
                                      : stock <
                                              1
                                          ? _muted2
                                          : _text,
                              fontSize:
                                  10,
                              fontWeight:
                                  FontWeight
                                      .w800,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            stock < 1
                                ? 'Out of stock'
                                : '$stock available',
                            style:
                                TextStyle(
                              color:
                                  stock < 1
                                      ? _danger
                                      : _muted,
                              fontSize:
                                  7.5,
                            ),
                          ),

                          if (variation
                                  .price !=
                              null) ...[
                            const SizedBox(
                              height: 2,
                            ),

                            Text(
                              _formatPrice(
                                variation
                                    .price!,
                              ),
                              style:
                                  const TextStyle(
                                color:
                                    _maroon,
                                fontSize:
                                    8.5,
                                fontWeight:
                                    FontWeight
                                        .w800,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ).toList(),
      ),
    );
  }

  Widget _buildQuantitySection() {
    return _DetailSection(
      title: 'Quantity',
      subtitle:
          _outOfStock
              ? 'This option is currently unavailable.'
              : 'Maximum $_availableStock for this option.',
      icon:
          Icons
              .shopping_bag_outlined,
      child: Row(
        children: [
          _QuantityButton(
            icon:
                Icons.remove_rounded,
            enabled:
                !_outOfStock &&
                _quantity > 1,
            onTap:
                _decreaseQuantity,
          ),

          Container(
            width: 65,
            height: 44,
            alignment:
                Alignment.center,
            decoration:
                const BoxDecoration(
              border: Border.symmetric(
                horizontal:
                    BorderSide(
                  color: _border,
                ),
              ),
            ),
            child: Text(
              '$_quantity',
              style:
                  const TextStyle(
                color: _text,
                fontSize: 13,
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          _QuantityButton(
            icon:
                Icons.add_rounded,
            enabled:
                !_outOfStock &&
                _quantity <
                    _availableStock,
            onTap:
                _increaseQuantity,
          ),

          const Spacer(),

          if (!_outOfStock)
            Text(
              '$_availableStock left',
              style:
                  const TextStyle(
                color: _muted,
                fontSize: 9.5,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSellerCard() {
    return Container(
      padding:
          const EdgeInsets.all(
        14,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border:
            Border.all(
          color: _border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SellerAvatar(
                product:
                    _product,
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _product
                                .sellerName!,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  _text,
                              fontSize:
                                  12,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
                        ),

                        if (_product
                            .sellerVerified) ...[
                          const SizedBox(
                            width: 4,
                          ),

                          const Icon(
                            Icons
                                .verified_rounded,
                            color:
                                _success,
                            size: 15,
                          ),
                        ],
                      ],
                    ),

                    if (_product
                            .sellerLocation
                            ?.trim()
                            .isNotEmpty ==
                        true) ...[
                      const SizedBox(
                        height: 3,
                      ),

                      Text(
                        _product
                            .sellerLocation!,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              _muted,
                          fontSize: 8.5,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 13,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton.icon(
                  onPressed:
                      widget
                                  .onMessageSeller ==
                              null
                          ? null
                          : () {
                              widget
                                  .onMessageSeller!(
                                _product,
                              );
                            },
                  style:
                      OutlinedButton
                          .styleFrom(
                    foregroundColor:
                        _maroon,
                    side:
                        const BorderSide(
                      color: _tan,
                    ),
                    minimumSize:
                        const Size.fromHeight(
                      42,
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
                  icon:
                      const Icon(
                    Icons
                        .chat_bubble_outline_rounded,
                    size: 16,
                  ),
                  label:
                      const Text(
                    'Message',
                    style:
                        TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                ),
              ),

              const SizedBox(
                width: 8,
              ),

              Expanded(
                child:
                    ElevatedButton.icon(
                  onPressed:
                      widget.onViewStore ==
                              null
                          ? null
                          : () {
                              widget
                                  .onViewStore!(
                                _product,
                              );
                            },
                  style:
                      ElevatedButton
                          .styleFrom(
                    elevation: 0,
                    backgroundColor:
                        _maroon,
                    foregroundColor:
                        Colors.white,
                    minimumSize:
                        const Size.fromHeight(
                      42,
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
                  icon:
                      const Icon(
                    Icons
                        .storefront_outlined,
                    size: 16,
                  ),
                  label:
                      const Text(
                    'View Store',
                    style:
                        TextStyle(
                      fontSize: 9.5,
                      fontWeight:
                          FontWeight
                              .w800,
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

  Widget _buildDescription() {
    final String description =
        _product.description!.trim();

    final bool longDescription =
        description.length > 320;

    return _DetailSection(
      title: 'Description',
      subtitle:
          'Product information from the seller.',
      icon:
          Icons.description_outlined,
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration:
                const Duration(
              milliseconds: 180,
            ),
            crossFadeState:
                _descriptionExpanded ||
                        !longDescription
                    ? CrossFadeState
                        .showSecond
                    : CrossFadeState
                        .showFirst,
            firstChild: Text(
              description,
              maxLines: 6,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  const TextStyle(
                color: _brown,
                fontSize: 10.5,
                height: 1.65,
              ),
            ),
            secondChild: Text(
              description,
              style:
                  const TextStyle(
                color: _brown,
                fontSize: 10.5,
                height: 1.65,
              ),
            ),
          ),

          if (longDescription) ...[
            const SizedBox(
              height: 7,
            ),

            TextButton(
              onPressed: () {
                setState(() {
                  _descriptionExpanded =
                      !_descriptionExpanded;
                });
              },
              style:
                  TextButton.styleFrom(
                foregroundColor:
                    _maroon,
                padding:
                    EdgeInsets.zero,
                minimumSize:
                    Size.zero,
                tapTargetSize:
                    MaterialTapTargetSize
                        .shrinkWrap,
              ),
              child: Text(
                _descriptionExpanded
                    ? 'Show Less'
                    : 'Read More',
                style:
                    const TextStyle(
                  fontSize: 9.5,
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

  Widget _buildSpecifications() {
    final List<MapEntry<String, String>>
        specifications =
        _product
            .specifications.entries
            .toList();

    return _DetailSection(
      title: 'Specifications',
      subtitle:
          'Product details and specifications.',
      icon:
          Icons.list_alt_rounded,
      child: Column(
        children:
            List.generate(
          specifications.length,
          (
            int index,
          ) {
            final MapEntry<String, String>
                specification =
                specifications[index];

            return Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                vertical: 10,
              ),
              decoration:
                  BoxDecoration(
                border:
                    index ==
                            specifications
                                    .length -
                                1
                        ? null
                        : const Border(
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
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 105,
                    child: Text(
                      specification.key,
                      style:
                          const TextStyle(
                        color:
                            _muted,
                        fontSize: 9.5,
                        fontWeight:
                            FontWeight
                                .w700,
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Expanded(
                    child: Text(
                      specification.value,
                      style:
                          const TextStyle(
                        color: _text,
                        fontSize: 9.5,
                        height: 1.4,
                        fontWeight:
                            FontWeight
                                .w600,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildReviews() {
    return _DetailSection(
      title: 'Ratings & Reviews',
      subtitle:
          _product.reviewCount == 0
              ? 'No reviews yet.'
              : '${_product.reviewCount} ${_product.reviewCount == 1 ? 'review' : 'reviews'} from buyers.',
      icon:
          Icons.star_outline_rounded,
      child:
          _product.reviews.isEmpty
              ? Container(
                  width:
                      double.infinity,
                  padding:
                      const EdgeInsets
                          .symmetric(
                    vertical: 25,
                  ),
                  child:
                      const Column(
                    children: [
                      Icon(
                        Icons
                            .rate_review_outlined,
                        color:
                            _muted2,
                        size: 30,
                      ),

                      SizedBox(
                        height: 8,
                      ),

                      Text(
                        'No product reviews yet.',
                        textAlign:
                            TextAlign.center,
                        style:
                            TextStyle(
                          color:
                              _muted,
                          fontSize:
                              10,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children:
                      List.generate(
                    _product
                        .reviews.length,
                    (
                      int index,
                    ) {
                      final ProductReviewData
                          review =
                          _product
                              .reviews[index];

                      return _ReviewCard(
                        review:
                            review,
                        showDivider:
                            index !=
                            _product
                                    .reviews
                                    .length -
                                1,
                      );
                    },
                  ),
                ),
    );
  }

  Widget _buildRelatedProducts() {
    final List<ProductDetailData>
        products =
        _relatedProducts;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'YOU MAY ALSO LIKE',
          style:
              TextStyle(
            color: _maroon,
            fontSize: 8,
            letterSpacing: 1.5,
            fontWeight:
                FontWeight.w900,
          ),
        ),

        const SizedBox(
          height: 5,
        ),

        const Text(
          'Related Products',
          style:
              TextStyle(
            color: _text,
            fontSize: 22,
            fontWeight:
                FontWeight.w900,
            letterSpacing:
                -0.5,
          ),
        ),

        const SizedBox(
          height: 14,
        ),

        SizedBox(
          height: 252,
          child:
              ListView.separated(
            scrollDirection:
                Axis.horizontal,
            physics:
                const BouncingScrollPhysics(),
            itemCount:
                products.length,
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
              final ProductDetailData product =
                  products[index];

              return SizedBox(
                width: 165,
                child:
                    _RelatedProductCard(
                  product:
                      product,
                  onTap:
                      widget.onRelatedProductSelected ==
                              null
                          ? null
                          : () {
                              widget
                                  .onRelatedProductSelected!(
                                product,
                              );
                            },
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPurchaseBar() {
    final bool busy =
        _addingToCart ||
        _buyingNow;

    return Container(
      padding:
          const EdgeInsets.fromLTRB(
        10,
        9,
        10,
        9,
      ),
      decoration:
          BoxDecoration(
        color: _surface,
        border:
            const Border(
          top: BorderSide(
            color: _border,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color:
                _maroon.withValues(
              alpha: 0.08,
            ),
            blurRadius: 20,
            offset:
                const Offset(
              0,
              -4,
            ),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            SizedBox(
              width: 49,
              height: 49,
              child:
                  OutlinedButton(
                onPressed:
                    _updatingWishlist
                        ? null
                        : _toggleWishlist,
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      _maroon,
                  padding:
                      EdgeInsets.zero,
                  side:
                      const BorderSide(
                    color: _tan,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                ),
                child:
                    _updatingWishlist
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  _maroon,
                            ),
                          )
                        : Icon(
                            _wishlisted
                                ? Icons
                                    .favorite_rounded
                                : Icons
                                    .favorite_border_rounded,
                            size: 20,
                          ),
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child:
                  OutlinedButton(
                onPressed:
                    busy ||
                            _outOfStock
                        ? null
                        : _addToCart,
                style:
                    OutlinedButton
                        .styleFrom(
                  foregroundColor:
                      _maroon,
                  side:
                      const BorderSide(
                    color: _maroon,
                  ),
                  minimumSize:
                      const Size.fromHeight(
                    49,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                ),
                child:
                    _addingToCart
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  _maroon,
                            ),
                          )
                        : const Text(
                            'Add to Cart',
                            style:
                                TextStyle(
                              fontSize:
                                  10.5,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
              ),
            ),

            const SizedBox(
              width: 7,
            ),

            Expanded(
              child:
                  ElevatedButton(
                onPressed:
                    busy ||
                            _outOfStock
                        ? null
                        : _buyNow,
                style:
                    ElevatedButton
                        .styleFrom(
                  elevation: 0,
                  backgroundColor:
                      _maroon,
                  foregroundColor:
                      Colors.white,
                  disabledBackgroundColor:
                      _maroon.withValues(
                    alpha: 0.35,
                  ),
                  minimumSize:
                      const Size.fromHeight(
                    49,
                  ),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius
                            .circular(
                      12,
                    ),
                  ),
                ),
                child:
                    _buyingNow
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child:
                                CircularProgressIndicator(
                              strokeWidth:
                                  2,
                              color:
                                  Colors.white,
                            ),
                          )
                        : Text(
                            _outOfStock
                                ? 'Out of Stock'
                                : 'Buy Now',
                            style:
                                const TextStyle(
                              fontSize:
                                  10.5,
                              fontWeight:
                                  FontWeight
                                      .w900,
                            ),
                          ),
              ),
            ),
          ],
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

class _DetailSection
    extends StatelessWidget {
  final String title;
  final String subtitle;

  final IconData icon;

  final Widget child;

  const _DetailSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.all(
        15,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFFDF9,
        ),
        borderRadius:
            BorderRadius.circular(
          18,
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
          Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration:
                    BoxDecoration(
                  color:
                      const Color(
                    0xFFF1E4D7,
                  ),
                  borderRadius:
                      BorderRadius
                          .circular(
                    11,
                  ),
                ),
                alignment:
                    Alignment.center,
                child: Icon(
                  icon,
                  color:
                      const Color(
                    0xFF561C17,
                  ),
                  size: 18,
                ),
              ),

              const SizedBox(
                width: 9,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF3B211B,
                        ),
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 2,
                    ),

                    Text(
                      subtitle,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF987865,
                        ),
                        fontSize: 8.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 14,
          ),

          child,
        ],
      ),
    );
  }
}

class _QuantityButton
    extends StatelessWidget {
  final IconData icon;

  final bool enabled;

  final VoidCallback onTap;

  const _QuantityButton({
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          enabled
              ? const Color(
                  0xFFFFFDF9,
                )
              : const Color(
                  0xFFF3ECE4,
                ),
      child: InkWell(
        onTap:
            enabled
                ? onTap
                : null,
        child: Container(
          width: 44,
          height: 44,
          alignment:
              Alignment.center,
          decoration:
              BoxDecoration(
            border:
                Border.all(
              color:
                  const Color(
                0xFFEADCCC,
              ),
            ),
          ),
          child: Icon(
            icon,
            color:
                enabled
                    ? const Color(
                        0xFF561C17,
                      )
                    : const Color(
                        0xFFA99386,
                      ),
            size: 18,
          ),
        ),
      ),
    );
  }
}

class _SellerAvatar
    extends StatelessWidget {
  final ProductDetailData product;

  const _SellerAvatar({
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    final String? url =
        product.sellerAvatarUrl;

    return Container(
      width: 49,
      height: 49,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          BoxDecoration(
        shape: BoxShape.circle,
        color:
            const Color(
          0xFFF1E4D7,
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
          url == null ||
                  url.trim().isEmpty
              ? _SellerInitial(
                  value:
                      product.sellerInitial,
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder:
                      (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent?
                        progress,
                  ) {
                    if (progress ==
                        null) {
                      return child;
                    }

                    return const Center(
                      child: SizedBox(
                        width: 17,
                        height: 17,
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
                    StackTrace?
                        stackTrace,
                  ) {
                    return _SellerInitial(
                      value:
                          product
                              .sellerInitial,
                    );
                  },
                ),
    );
  }
}

class _SellerInitial
    extends StatelessWidget {
  final String value;

  const _SellerInitial({
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment:
          Alignment.center,
      color:
          const Color(
        0xFFF1E4D7,
      ),
      child: Text(
        value,
        style:
            const TextStyle(
          color:
              Color(
            0xFF561C17,
          ),
          fontSize: 16,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

class _ReviewCard
    extends StatelessWidget {
  final ProductReviewData review;

  final bool showDivider;

  const _ReviewCard({
    required this.review,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        vertical: 12,
      ),
      decoration:
          BoxDecoration(
        border:
            showDivider
                ? const Border(
                    bottom:
                        BorderSide(
                      color:
                          Color(
                        0xFFF0E8DF,
                      ),
                    ),
                  )
                : null,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          _ReviewAvatar(
            review:
                review,
          ),

          const SizedBox(
            width: 9,
          ),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.buyerName,
                        maxLines: 1,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF3B211B,
                          ),
                          fontSize: 10,
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                    ),

                    if (review
                        .date
                        .isNotEmpty)
                      Text(
                        review.date,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFFA99386,
                          ),
                          fontSize: 7.5,
                        ),
                      ),
                  ],
                ),

                const SizedBox(
                  height: 4,
                ),

                Row(
                  children:
                      List.generate(
                    5,
                    (
                      int index,
                    ) {
                      return Icon(
                        index <
                                review
                                    .rating
                            ? Icons
                                .star_rounded
                            : Icons
                                .star_border_rounded,
                        color:
                            const Color(
                          0xFFC88418,
                        ),
                        size: 14,
                      );
                    },
                  ),
                ),

                const SizedBox(
                  height: 6,
                ),

                Text(
                  review.body,
                  style:
                      const TextStyle(
                    color:
                        Color(
                      0xFF6C4936,
                    ),
                    fontSize: 9.5,
                    height: 1.5,
                  ),
                ),

                if (review.hasPhoto) ...[
                  const SizedBox(
                    height: 7,
                  ),

                  const Row(
                    children: [
                      Icon(
                        Icons
                            .photo_outlined,
                        color:
                            Color(
                          0xFF987865,
                        ),
                        size: 14,
                      ),

                      SizedBox(
                        width: 4,
                      ),

                      Text(
                        'Review includes a photo',
                        style:
                            TextStyle(
                          color:
                              Color(
                            0xFF987865,
                          ),
                          fontSize: 8,
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
    );
  }
}

class _ReviewAvatar
    extends StatelessWidget {
  final ProductReviewData review;

  const _ReviewAvatar({
    required this.review,
  });

  @override
  Widget build(BuildContext context) {
    final String? url =
        review.buyerAvatarUrl;

    return Container(
      width: 35,
      height: 35,
      clipBehavior:
          Clip.antiAlias,
      decoration:
          const BoxDecoration(
        shape: BoxShape.circle,
        color:
            Color(
          0xFFF1E4D7,
        ),
      ),
      child:
          url == null ||
                  url.trim().isEmpty
              ? Center(
                  child: Text(
                    review.buyerInitial,
                    style:
                        const TextStyle(
                      color:
                          Color(
                        0xFF561C17,
                      ),
                      fontSize: 10,
                      fontWeight:
                          FontWeight
                              .w900,
                    ),
                  ),
                )
              : Image.network(
                  url,
                  fit: BoxFit.cover,
                  errorBuilder:
                      (
                    BuildContext context,
                    Object error,
                    StackTrace?
                        stackTrace,
                  ) {
                    return Center(
                      child: Text(
                        review
                            .buyerInitial,
                        style:
                            const TextStyle(
                          color:
                              Color(
                            0xFF561C17,
                          ),
                          fontSize:
                              10,
                          fontWeight:
                              FontWeight
                                  .w900,
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _RelatedProductCard
    extends StatelessWidget {
  final ProductDetailData product;

  final VoidCallback? onTap;

  const _RelatedProductCard({
    required this.product,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final List<String> images =
        product.galleryImages;

    return Material(
      color:
          const Color(
        0xFFFFFDF9,
      ),
      borderRadius:
          BorderRadius.circular(
        15,
      ),
      child: InkWell(
        onTap:
            onTap,
        borderRadius:
            BorderRadius.circular(
          15,
        ),
        child: Container(
          clipBehavior:
              Clip.antiAlias,
          decoration:
              BoxDecoration(
            border:
                Border.all(
              color:
                  const Color(
                0xFFEADCCC,
              ),
            ),
            borderRadius:
                BorderRadius.circular(
              15,
            ),
          ),
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width:
                      double.infinity,
                  color:
                      const Color(
                    0xFFF3ECE4,
                  ),
                  child:
                      images.isEmpty
                          ? const Icon(
                              Icons
                                  .inventory_2_outlined,
                              color:
                                  Color(
                                0xFFA99386,
                              ),
                            )
                          : _ProductImage(
                              url:
                                  images.first,
                            ),
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.all(
                  10,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF3B211B,
                        ),
                        fontSize: 10,
                        height: 1.3,
                        fontWeight:
                            FontWeight
                                .w800,
                      ),
                    ),

                    const SizedBox(
                      height: 7,
                    ),

                    Text(
                      '₱${product.price.toStringAsFixed(2)}',
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFF561C17,
                        ),
                        fontSize: 12,
                        fontWeight:
                            FontWeight
                                .w900,
                      ),
                    ),

                    const SizedBox(
                      height: 5,
                    ),

                    Row(
                      children: [
                        if (product
                                .rating !=
                            null) ...[
                          const Icon(
                            Icons
                                .star_rounded,
                            size: 12,
                            color:
                                Color(
                              0xFFC88418,
                            ),
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
                                  Color(
                                0xFF6C4936,
                              ),
                              fontSize:
                                  7.5,
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
                                  Color(
                                0xFF987865,
                              ),
                              fontSize:
                                  7.5,
                            ),
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

class _ProductImage
    extends StatelessWidget {
  final String? url;

  const _ProductImage({
    required this.url,
  });

  @override
  Widget build(BuildContext context) {
    final String? imageUrl =
        url?.trim();

    if (imageUrl == null ||
        imageUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons
              .inventory_2_outlined,
          color:
              Color(
            0xFFA99386,
          ),
          size: 40,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(imageUrl);

    return Image.network(
      resolvedUrl,
      width:
          double.infinity,
      height:
          double.infinity,
      fit: BoxFit.cover,
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
            width: 24,
            height: 24,
            child:
                CircularProgressIndicator(
              strokeWidth: 2,
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
          child: Icon(
            Icons
                .broken_image_outlined,
            color:
                Color(
              0xFFA99386,
            ),
            size: 40,
          ),
        );
      },
    );
  }
}
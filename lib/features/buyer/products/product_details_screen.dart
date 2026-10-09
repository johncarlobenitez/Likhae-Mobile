import 'package:flutter/material.dart';
import 'package:likhae/core/config/app_config.dart';

typedef ProductActionCallback =
    Future<void> Function(
      ProductDetailData product,
      int quantity,
      Map<String, String> selectedVariants,
    );

typedef ProductPurchaseCallback =
    Future<void> Function(ProductPurchaseRequest request);

typedef ProductWishlistCallback =
    Future<void> Function(ProductDetailData product);

typedef ProductNavigationCallback = void Function(ProductDetailData product);

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

  /// Option values that make up this concrete SKU, for example:
  /// {"Color": "Black", "Size": "XL"}.
  final Map<String, String> optionValues;

  /// Image(s) belonging to this concrete SKU. Clothing products commonly
  /// use these to show a different product photo for every color.
  final String? imageUrl;
  final List<String> imageUrls;

  const ProductVariationData({
    required this.id,
    required this.name,
    required this.value,
    this.stock,
    this.price,
    this.optionValues = const <String, String>{},
    this.imageUrl,
    this.imageUrls = const <String>[],
  });

  List<String> get galleryImages {
    final List<String> result = <String>[];

    for (final String image in imageUrls) {
      final String clean = image.trim();
      if (clean.isNotEmpty && !result.contains(clean)) {
        result.add(clean);
      }
    }

    final String? main = imageUrl?.trim();
    if (main != null && main.isNotEmpty && !result.contains(main)) {
      result.insert(0, main);
    }

    return result;
  }

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

class ProductOptionData {
  final String name;
  final List<String> values;

  const ProductOptionData({required this.name, required this.values});
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
    final String clean = buyerName.trim();

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
  final int? sellerUserId;
  final String? sellerAvatarUrl;
  final String? sellerLocation;

  final bool sellerVerified;

  final List<ProductVariationData> variations;

  final List<ProductOptionData> options;

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
    this.sellerUserId,
    this.sellerAvatarUrl,
    this.sellerLocation,
    this.sellerVerified = false,
    this.variations = const [],
    this.options = const [],
    this.specifications = const {},
    this.reviews = const [],
    this.wishlisted = false,
  });

  List<String> get galleryImages {
    final List<String> result = <String>[];

    for (final String image in imageUrls) {
      final String clean = image.trim();

      if (clean.isNotEmpty && !result.contains(clean)) {
        result.add(clean);
      }
    }

    final String? main = imageUrl?.trim();

    if (main != null && main.isNotEmpty && !result.contains(main)) {
      result.insert(0, main);
    }

    return result;
  }

  double? get discountPercentage {
    final double? original = originalPrice;

    if (original == null || original <= 0 || original <= price) {
      return null;
    }

    return ((original - price) / original) * 100;
  }

  String get sellerInitial {
    final String clean = sellerName?.trim() ?? '';

    if (clean.isEmpty) {
      return 'S';
    }

    return clean[0].toUpperCase();
  }

  factory ProductDetailData.fromApi(Map<String, dynamic> json) {
    final dynamic rawId = json['id'] ?? json['db_id'];
    final dynamic rawPrice = json['price'] ?? json['min_price'];
    final dynamic rawPrimaryImage = json['primary_image'];
    final Map<String, dynamic>? primaryImage = rawPrimaryImage is Map
        ? Map<String, dynamic>.from(rawPrimaryImage)
        : null;
    final dynamic rawImage =
        json['image_url'] ??
        json['image'] ??
        primaryImage?['url'] ??
        primaryImage?['file_path'];
    final dynamic gallery = json['gallery'] ?? json['images'] ?? <dynamic>[];
    final dynamic variations = json['variations'] ?? json['variants'] ?? <String, dynamic>{};
    final dynamic rawOptions = json['options'] ?? <dynamic>[];
    final dynamic specs =
        json['specs'] ?? json['specifications'] ?? <String, dynamic>{};
    final dynamic rawReviews =
        json['customer_reviews'] ?? json['review_items'] ?? <dynamic>[];

    final List<String> galleryImages = <String>[];

    if (gallery is List) {
      for (final dynamic item in gallery) {
        String? value;

        if (item is Map) {
          value = (item['image_url'] ?? item['url'] ?? item['path'])
              ?.toString();
        } else if (item != null) {
          value = item.toString();
        }

        if (value != null && value.trim().isNotEmpty) {
          final String resolved = AppConfig.resolveMediaUrl(value.trim());

          if (!galleryImages.contains(resolved)) {
            galleryImages.add(resolved);
          }
        }
      }
    }

    final List<ProductVariationData> parsedVariations =
        <ProductVariationData>[];

    if (variations is List) {
      for (final dynamic item in variations) {
        if (item is! Map) {
          continue;
        }
        final Map<String, dynamic> value = Map<String, dynamic>.from(item);
        final dynamic rawOptionValues = value['option_values'];
        final Map<String, String> optionValues = <String, String>{};
        if (rawOptionValues is List) {
          for (final dynamic rawOption in rawOptionValues) {
            if (rawOption is! Map) {
              continue;
            }
            final String optionName = (rawOption['option'] ??
                    rawOption['option_name'] ??
                    rawOption['name'] ??
                    '')
                .toString()
                .trim();
            final String optionValue = (rawOption['value'] ?? '').toString().trim();
            if (optionName.isNotEmpty && optionValue.isNotEmpty) {
              optionValues[optionName] = optionValue;
            }
          }
        }
        final String optionDescription = optionValues.values.join(' / ');
        final String description = (value['description'] ?? '')
            .toString()
            .trim();
        final List<String> variationImages = _parseImageUrls(
          value['images'] ?? value['gallery'] ?? value['photos'],
        );
        final String? variationImage = _parseImageUrl(
          value['image_url'] ?? value['image'] ?? value['photo'],
        );
        parsedVariations.add(
          ProductVariationData(
            id: int.tryParse(value['id']?.toString() ?? '') ?? 0,
            name: 'Variant',
            value: description.isNotEmpty
                ? description
                : optionDescription.isNotEmpty
                ? optionDescription
                : 'Default',
            stock: int.tryParse(value['stock']?.toString() ?? ''),
            price: double.tryParse(value['price']?.toString() ?? ''),
            optionValues: optionValues,
            imageUrl: variationImage,
            imageUrls: variationImages,
          ),
        );
      }
    } else if (variations is Map) {
      for (final MapEntry<dynamic, dynamic> entry in variations.entries) {
        final String groupName = entry.key.toString();
        final dynamic groupValue = entry.value;

        if (groupValue is! List) {
          continue;
        }

        for (final dynamic item in groupValue) {
          if (item is! Map) {
            continue;
          }

          final Map<String, dynamic> value = Map<String, dynamic>.from(item);

          final List<String> variationImages = _parseImageUrls(
            value['images'] ?? value['gallery'] ?? value['photos'],
          );
          final String? variationImage = _parseImageUrl(
            value['image_url'] ?? value['image'] ?? value['photo'],
          );

          parsedVariations.add(
            ProductVariationData(
              id: int.tryParse(value['id']?.toString() ?? '') ?? 0,
              name: groupName,
              value: value['value']?.toString() ?? '',
              stock: int.tryParse(value['stock']?.toString() ?? ''),
              price: double.tryParse(value['price']?.toString() ?? ''),
              optionValues: <String, String>{
                groupName: value['value']?.toString() ?? '',
              },
              imageUrl: variationImage,
              imageUrls: variationImages,
            ),
          );
        }
      }
    }

    final List<ProductOptionData> parsedOptions = <ProductOptionData>[];
    if (rawOptions is List) {
      for (final dynamic rawOption in rawOptions) {
        if (rawOption is! Map) {
          continue;
        }
        final String name = (rawOption['name'] ?? '').toString().trim();
        final dynamic rawValues = rawOption['values'];
        final List<String> values = rawValues is List
            ? rawValues
                  .map((dynamic value) => value is Map
                      ? (value['value'] ?? '').toString().trim()
                      : value.toString().trim())
                  .where((String value) => value.isNotEmpty)
                  .toSet()
                  .toList()
            : <String>[];
        if (name.isNotEmpty && values.isNotEmpty) {
          parsedOptions.add(ProductOptionData(name: name, values: values));
        }
      }
    }

    if (parsedOptions.isEmpty) {
      final Map<String, List<String>> derivedOptions = <String, List<String>>{};
      for (final ProductVariationData variation in parsedVariations) {
        final String fallbackName = variation.name.trim().isEmpty
            ? 'Variant'
            : variation.name.trim();
        final Map<String, String> values = variation.optionValues.isNotEmpty
            ? variation.optionValues
            : <String, String>{fallbackName: variation.value};
        for (final MapEntry<String, String> entry in values.entries) {
          derivedOptions.putIfAbsent(entry.key, () => <String>[]);
          if (!derivedOptions[entry.key]!.contains(entry.value)) {
            derivedOptions[entry.key]!.add(entry.value);
          }
        }
      }
      parsedOptions.addAll(
        derivedOptions.entries.map(
          (MapEntry<String, List<String>> entry) => ProductOptionData(
            name: entry.key,
            values: entry.value,
          ),
        ),
      );
    }

    final Map<String, String> parsedSpecs = <String, String>{};

    if (specs is Map) {
      for (final MapEntry<dynamic, dynamic> entry in specs.entries) {
        final String key = entry.key.toString().trim();
        final String value = entry.value?.toString().trim() ?? '';

        if (key.isNotEmpty && value.isNotEmpty) {
          parsedSpecs[key] = value;
        }
      }
    }

    final List<ProductReviewData> parsedReviews = <ProductReviewData>[];

    if (rawReviews is List) {
      for (int index = 0; index < rawReviews.length; index++) {
        final dynamic item = rawReviews[index];

        if (item is! Map) {
          continue;
        }

        final Map<String, dynamic> review = Map<String, dynamic>.from(item);

        final String buyerName =
            (review['buyer_name'] ??
                    review['name'] ??
                    review['buyer'] ??
                    'Buyer')
                .toString();

        final String body =
            (review['body'] ?? review['review'] ?? review['comment'] ?? '')
                .toString();

        final String? rawAvatar =
            (review['buyer_avatar_url'] ??
                    review['avatar_url'] ??
                    review['avatar'])
                ?.toString();

        final dynamic photoValue =
            review['photos'] ??
            review['images'] ??
            review['photo'] ??
            review['image_url'];

        final bool hasPhoto = photoValue is List
            ? photoValue.isNotEmpty
            : photoValue != null && photoValue.toString().trim().isNotEmpty;

        parsedReviews.add(
          ProductReviewData(
            id: (review['id'] ?? index).toString(),
            buyerName: buyerName,
            buyerAvatarUrl: rawAvatar == null || rawAvatar.trim().isEmpty
                ? null
                : AppConfig.resolveMediaUrl(rawAvatar.trim()),
            rating: int.tryParse(review['rating']?.toString() ?? '') ?? 0,
            body: body,
            date: (review['date'] ?? review['created_at'] ?? '').toString(),
            hasPhoto: hasPhoto,
          ),
        );
      }
    }

    final String? rawSellerAvatar =
        json['seller_avatar']?.toString() ??
        json['seller_avatar_url']?.toString();

    final int parsedReviewCount =
        int.tryParse(
          json['review_count']?.toString() ??
              json['reviews_count']?.toString() ??
              (json['reviews'] is num ? json['reviews'].toString() : null) ??
              '',
        ) ??
        parsedReviews.length;

    final dynamic rawSeller = json['seller'];
    final Map<String, dynamic>? seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : null;
    final dynamic rawCategory = json['category'];
    final Map<String, dynamic>? category = rawCategory is Map
        ? Map<String, dynamic>.from(rawCategory)
        : null;

    return ProductDetailData(
      id: int.tryParse(rawId?.toString() ?? '') ?? 0,
      name: (json['name'] ?? 'Product').toString(),
      slug: json['slug']?.toString(),
      category:
          category?['name']?.toString() ??
          json['parent_category']?.toString() ??
          (json['category'] is String ? json['category'] as String : null),
      imageUrl: rawImage == null || rawImage.toString().trim().isEmpty
          ? null
          : AppConfig.resolveMediaUrl(rawImage.toString().trim()),
      imageUrls: galleryImages,
      price: double.tryParse(rawPrice?.toString() ?? '') ?? 0,
      originalPrice: double.tryParse(
        json['old_price']?.toString() ??
            json['original_price']?.toString() ??
            '',
      ),
      stock: int.tryParse(json['stock']?.toString() ?? '0') ?? 0,
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      reviewCount: parsedReviewCount,
      soldCount:
          int.tryParse(
            json['sold']?.toString() ?? json['sold_count']?.toString() ?? '0',
          ) ??
          0,
      description: json['description']?.toString(),
      sellerName:
          seller?['business_name']?.toString() ??
          json['seller_name']?.toString() ??
          (rawSeller is String ? rawSeller : null),
      sellerSlug: json['seller_slug']?.toString(),
      sellerUserId: int.tryParse(
        (seller?['user_id'] ?? json['seller_user_id'] ?? '').toString(),
      ),
      sellerAvatarUrl: rawSellerAvatar == null || rawSellerAvatar.trim().isEmpty
          ? null
          : AppConfig.resolveMediaUrl(rawSellerAvatar.trim()),
      sellerLocation:
          json['location']?.toString() ?? json['seller_location']?.toString(),
      sellerVerified:
          json['seller_verified'] == true ||
          json['seller_is_verified'] == true ||
          json['verified'] == true,
      variations: parsedVariations,
      options: parsedOptions,
      specifications: parsedSpecs,
      reviews: parsedReviews,
      wishlisted: json['wishlisted'] == true,
    );
  }

  static String? _parseImageUrl(dynamic raw) {
    if (raw is Map) {
      raw = raw['url'] ?? raw['image_url'] ?? raw['path'] ?? raw['file_path'];
    }

    if (raw == null) {
      return null;
    }

    final String value = raw.toString().trim();
    return value.isEmpty ? null : AppConfig.resolveMediaUrl(value);
  }

  static List<String> _parseImageUrls(dynamic raw) {
    if (raw is! List) {
      return const <String>[];
    }

    return raw
        .map(_parseImageUrl)
        .whereType<String>()
        .where((String value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  ProductDetailData copyWith({bool? wishlisted}) {
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
      sellerUserId: sellerUserId,
      sellerAvatarUrl: sellerAvatarUrl,
      sellerLocation: sellerLocation,
      sellerVerified: sellerVerified,
      variations: variations,
      options: options,
      specifications: specifications,
      reviews: reviews,
      wishlisted: wishlisted ?? this.wishlisted,
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

  final Map<String, String> selectedVariants;

  const ProductPurchaseRequest({
    required this.productId,
    required this.quantity,
    required this.selectedVariants,
    this.productSlug,
    this.productVariationId,
    this.variant,
  });
}

class ProductDetailsScreen extends StatefulWidget {
  final ProductDetailData product;

  /// Preferred related-product collection.
  final List<ProductDetailData> relatedProducts;

  /// Kept as an alias so this screen can also accept
  /// marketplace products passed from older page wiring.
  final List<ProductDetailData> products;

  final int initialQuantity;
  final int? initialVariationId;

  final bool? initialWishlisted;

  final VoidCallback? onBack;
  final VoidCallback? onCart;

  /// Existing callback format from the first Flutter
  /// conversion.
  final ProductActionCallback? onAddToCart;

  /// Existing callback format from the first Flutter
  /// conversion.
  final ProductActionCallback? onBuyNow;

  /// New request callback containing the actual variation
  /// ID needed by Laravel.
  ///
  /// When supplied, this takes priority over
  /// [onAddToCart].
  final ProductPurchaseCallback? onAddToCartRequest;

  /// New request callback containing the actual variation
  /// ID needed by Laravel.
  ///
  /// When supplied, this takes priority over [onBuyNow].
  final ProductPurchaseCallback? onBuyNowRequest;

  final ProductWishlistCallback? onWishlistToggle;

  /// Alias supported for easier wiring.
  final ProductWishlistCallback? onWishlist;

  final ProductNavigationCallback? onViewStore;

  final ProductNavigationCallback? onMessageSeller;

  final ProductNavigationCallback? onRelatedProductSelected;

  final Future<void> Function()? onRefresh;

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
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonDark = Color(0xFF3E130F);

  static const Color _text = Color(0xFF3B211B);

  static const Color _brown = Color(0xFF6C4936);

  static const Color _muted = Color(0xFF987865);

  static const Color _muted2 = Color(0xFFA99386);

  static const Color _tan = Color(0xFFC19771);

  static const Color _star = Color(0xFFC88418);

  static const Color _success = Color(0xFF256F4A);

  static const Color _danger = Color(0xFFB42318);

  final PageController _galleryController = PageController();

  late ProductDetailData _product;

  ProductVariationData? _selectedVariation;

  Map<String, String> _selectedOptionValues = <String, String>{};

  late int _quantity;

  late bool _wishlisted;

  int _currentImageIndex = 0;

  bool _addingToCart = false;
  bool _buyingNow = false;
  bool _updatingWishlist = false;

  bool _descriptionExpanded = false;

  @override
  void initState() {
    super.initState();

    _product = widget.product;

    _quantity = widget.initialQuantity.clamp(1, 999999).toInt();

    _wishlisted = widget.initialWishlisted ?? _product.wishlisted;

    _selectedVariation = _resolveInitialVariation();
    _selectedOptionValues = _selectedVariation == null
        ? <String, String>{}
        : _optionValuesForVariation(_selectedVariation!);

    _clampQuantity();
  }

  @override
  void didUpdateWidget(covariant ProductDetailsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product != widget.product) {
      _product = widget.product;

      _wishlisted = widget.initialWishlisted ?? _product.wishlisted;

      _quantity = widget.initialQuantity.clamp(1, 999999).toInt();

      _selectedVariation = _resolveInitialVariation();
      _selectedOptionValues = _selectedVariation == null
          ? <String, String>{}
          : _optionValuesForVariation(_selectedVariation!);

      _currentImageIndex = 0;
      _descriptionExpanded = false;

      _clampQuantity();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_galleryController.hasClients) {
          return;
        }

        _galleryController.jumpToPage(0);
      });
    }
  }

  @override
  void dispose() {
    _galleryController.dispose();

    super.dispose();
  }

  ProductVariationData? _resolveInitialVariation() {
    final List<ProductVariationData> variations = _product.variations;

    if (variations.isEmpty) {
      return null;
    }

    // Do not silently choose the first SKU for products with options. The
    // buyer must explicitly choose every option before Buy Now can continue.
    if (_product.options.isNotEmpty || variations.length > 1) {
      return null;
    }

    final int? requestedId = widget.initialVariationId;

    if (requestedId != null) {
      for (final ProductVariationData variation in variations) {
        if (variation.id == requestedId) {
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
    for (final ProductVariationData variation in variations) {
      if (_variationStock(variation) > 0) {
        return variation;
      }
    }

    return variations.first;
  }

  int _variationStock(ProductVariationData variation) {
    return variation.stock ?? _product.stock;
  }

  int get _availableStock {
    final ProductVariationData? variation = _selectedVariation;

    if (variation != null) {
      return _variationStock(variation);
    }

    if (_hasSelectableOptions) {
      // Keep the action usable so it can open the option picker. Validation
      // still blocks checkout until a complete SKU is selected.
      return _product.stock;
    }

    return _product.stock;
  }

  bool get _outOfStock {
    return _availableStock < 1;
  }

  double get _displayPrice {
    return _selectedVariation?.price ?? _product.price;
  }

  List<String> get _images {
    final ProductVariationData? preview =
        _findVariationForPreview(_selectedOptionValues);
    final List<String> variantImages = preview?.galleryImages ?? const <String>[];

    if (variantImages.isEmpty) {
      return _product.galleryImages;
    }

    final List<String> images = <String>[...variantImages];
    for (final String image in _product.galleryImages) {
      if (!images.contains(image)) {
        images.add(image);
      }
    }
    return images;
  }

  Map<String, String> get _selectedVariantMap {
    final ProductVariationData? variation = _selectedVariation;

    if (variation == null) {
      return const {};
    }

    return _optionValuesForVariation(variation);
  }

  Map<String, String> _optionValuesForVariation(
    ProductVariationData variation,
  ) {
    if (variation.optionValues.isNotEmpty) {
      return Map<String, String>.from(variation.optionValues);
    }

    final String name = variation.name.trim().isEmpty
        ? 'Variant'
        : variation.name.trim();
    return <String, String>{name: variation.value};
  }

  List<ProductOptionData> get _optionGroups {
    if (_product.options.isNotEmpty) {
      return _product.options;
    }

    final Map<String, List<String>> groups = <String, List<String>>{};
    for (final ProductVariationData variation in _product.variations) {
      final Map<String, String> values = _optionValuesForVariation(variation);
      for (final MapEntry<String, String> entry in values.entries) {
        groups.putIfAbsent(entry.key, () => <String>[]);
        if (!groups[entry.key]!.contains(entry.value)) {
          groups[entry.key]!.add(entry.value);
        }
      }
    }

    return groups.entries
        .map(
          (MapEntry<String, List<String>> entry) => ProductOptionData(
            name: entry.key,
            values: entry.value,
          ),
        )
        .toList(growable: false);
  }

  bool get _hasSelectableOptions {
    return _optionGroups.isNotEmpty &&
        (_product.options.isNotEmpty || _product.variations.length > 1);
  }

  ProductVariationData? _findVariationForSelections(
    Map<String, String> selections,
  ) {
    final List<ProductOptionData> groups = _optionGroups;
    if (groups.isEmpty) {
      return _selectedVariation;
    }

    for (final ProductVariationData variation in _product.variations) {
      final Map<String, String> values = _optionValuesForVariation(variation);
      final bool matches = groups.every(
        (ProductOptionData group) =>
            selections[group.name] != null &&
            values[group.name] == selections[group.name],
      );
      if (matches) {
        return variation;
      }
    }

    return null;
  }

  ProductVariationData? _findVariationForPreview(
    Map<String, String> selections,
  ) {
    if (selections.isEmpty) {
      return null;
    }

    final ProductVariationData? exact = _findVariationForSelections(selections);
    if (exact != null && exact.galleryImages.isNotEmpty) {
      return exact;
    }

    // A color can be selected before a size. Use any SKU with that color so
    // the hero photo changes immediately, even before the full SKU is valid.
    for (final ProductVariationData variation in _product.variations) {
      final Map<String, String> values = _optionValuesForVariation(variation);
      final bool matches = selections.entries.every(
        (MapEntry<String, String> entry) => values[entry.key] == entry.value,
      );
      if (matches && variation.galleryImages.isNotEmpty) {
        return variation;
      }
    }

    return exact;
  }

  ProductVariationData? _variationForOptionValue(
    ProductOptionData group,
    String value,
    Map<String, String> selections,
  ) {
    final Map<String, String> previewSelections =
        Map<String, String>.from(selections)..[group.name] = value;
    return _findVariationForPreview(previewSelections);
  }

  bool _isColorOption(String name) {
    final String normalized = name.toLowerCase();
    return normalized.contains('color') || normalized.contains('colour');
  }

  Color _colorForOption(String value) {
    final String normalized = value.toLowerCase().trim();
    if (normalized.contains('black')) return const Color(0xFF252525);
    if (normalized.contains('white')) return const Color(0xFFF8F8F8);
    if (normalized.contains('navy')) return const Color(0xFF1E365E);
    if (normalized.contains('red')) return const Color(0xFFB73535);
    if (normalized.contains('khaki')) return const Color(0xFFB9A06C);
    if (normalized.contains('peach')) return const Color(0xFFE7A18E);
    if (normalized.contains('mocha') || normalized.contains('brown')) {
      return const Color(0xFF876452);
    }
    if (normalized.contains('olive')) return const Color(0xFF7A8156);
    if (normalized.contains('blue')) return const Color(0xFF557CA8);
    if (normalized.contains('green')) return const Color(0xFF5D8A63);
    if (normalized.contains('pink')) return const Color(0xFFD98B9A);
    if (normalized.contains('orange')) return const Color(0xFFD6813A);
    if (normalized.contains('yellow')) return const Color(0xFFE0B948);
    if (normalized.contains('purple')) return const Color(0xFF8B6FA7);
    if (normalized.contains('gray') || normalized.contains('grey')) {
      return const Color(0xFF969696);
    }
    return const Color(0xFFD7C9BE);
  }

  void _resetGalleryToSelectedOption() {
    _currentImageIndex = 0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _galleryController.hasClients) {
        _galleryController.jumpToPage(0);
      }
    });
  }

  ProductPurchaseRequest get _purchaseRequest {
    final ProductVariationData? variation = _selectedVariation;

    return ProductPurchaseRequest(
      productId: _product.id,
      productSlug: _product.slug,
      quantity: _quantity,
      productVariationId: variation?.id,
      variant: variation?.value,
      selectedVariants: _selectedVariantMap,
    );
  }

  List<ProductDetailData> get _relatedProducts {
    final List<ProductDetailData> source = widget.relatedProducts.isNotEmpty
        ? widget.relatedProducts
        : widget.products;

    return source
        .where((ProductDetailData product) => product.id != _product.id)
        .take(6)
        .toList();
  }

  void _clampQuantity() {
    final int stock = _availableStock;

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

  void _selectVariation(ProductVariationData variation) {
    if (_selectedVariation?.id == variation.id) {
      return;
    }

    setState(() {
      _selectedVariation = variation;
      _selectedOptionValues = _optionValuesForVariation(variation);

      _clampQuantity();
      _resetGalleryToSelectedOption();
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
    final int stock = _availableStock;

    if (stock < 1 || _quantity >= stock) {
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

    final ProductWishlistCallback? callback =
        widget.onWishlistToggle ?? widget.onWishlist;

    if (callback == null) {
      _showMessage('Wishlist will be connected to Laravel later.');

      return;
    }

    setState(() {
      _updatingWishlist = true;
    });

    try {
      await callback(_product);

      if (!mounted) {
        return;
      }

      setState(() {
        _wishlisted = !_wishlisted;

        _product = _product.copyWith(wishlisted: _wishlisted);
      });

      _showMessage(
        _wishlisted
            ? 'Product saved to your wishlist.'
            : 'Product removed from your wishlist.',
      );
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _updatingWishlist = false;
        });
      }
    }
  }

  Future<void> _addToCart() async {
    if (_addingToCart || _buyingNow) {
      return;
    }

    if (_hasSelectableOptions) {
      final bool? selected = await _showVariationPicker(
        actionLabel: 'Add to Cart',
      );
      if (selected != true || !mounted) {
        return;
      }
    }

    if (!_validatePurchase()) {
      return;
    }

    if (widget.onAddToCartRequest == null && widget.onAddToCart == null) {
      _showMessage('Cart API will be connected to Laravel later.');

      return;
    }

    setState(() {
      _addingToCart = true;
    });

    try {
      if (widget.onAddToCartRequest != null) {
        await widget.onAddToCartRequest!(_purchaseRequest);
      } else {
        await widget.onAddToCart!(_product, _quantity, _selectedVariantMap);
      }

      if (!mounted) {
        return;
      }

      _showMessage(
        '$_quantity item${_quantity == 1 ? '' : 's'} added to your cart.',
      );
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _addingToCart = false;
        });
      }
    }
  }

  Future<void> _buyNow() async {
    if (_buyingNow || _addingToCart) {
      return;
    }

    if (_hasSelectableOptions) {
      final bool? selected = await _showVariationPicker();
      if (selected != true || !mounted) {
        return;
      }
    }

    if (!_validatePurchase()) {
      return;
    }

    if (widget.onBuyNowRequest == null && widget.onBuyNow == null) {
      _showMessage('Buy Now will be connected to checkout later.');

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
      if (widget.onBuyNowRequest != null) {
        await widget.onBuyNowRequest!(_purchaseRequest);
      } else {
        await widget.onBuyNow!(_product, _quantity, _selectedVariantMap);
      }
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _buyingNow = false;
        });
      }
    }
  }

  Future<bool?> _showVariationPicker({String actionLabel = 'Continue to checkout'}) {
    final List<ProductOptionData> groups = _optionGroups;
    final Map<String, String> pendingSelections =
        Map<String, String>.from(_selectedOptionValues);

    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            final ProductVariationData? matchingVariation =
                _findVariationForSelections(pendingSelections);
            final ProductVariationData? previewVariation =
                _findVariationForPreview(pendingSelections);
            final List<String> previewImages =
                previewVariation?.galleryImages ?? _product.galleryImages;
            final int previewStock = matchingVariation == null
                ? _product.stock
                : _variationStock(matchingVariation);
            final bool canContinue = matchingVariation != null &&
                previewStock > 0;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  18,
                  12,
                  18,
                  18 + MediaQuery.viewInsetsOf(context).bottom,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 650),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Choose product options',
                              style: TextStyle(
                                color: _text,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            icon: const Icon(Icons.close_rounded),
                            color: _muted,
                          ),
                        ],
                      ),
                      Text(
                        _product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: _muted, fontSize: 13),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 92,
                            height: 92,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3ECE4),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: _border),
                            ),
                            child: previewImages.isEmpty
                                ? const Icon(
                                    Icons.inventory_2_outlined,
                                    color: _muted2,
                                  )
                                : _ProductImage(url: previewImages.first),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _formatPrice(
                                    matchingVariation?.price ?? _product.price,
                                  ),
                                  style: const TextStyle(
                                    color: _maroon,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  matchingVariation == null
                                      ? 'Select options'
                                      : previewStock > 0
                                      ? 'Stock: $previewStock'
                                      : 'Out of stock',
                                  style: TextStyle(
                                    color: previewStock > 0 ? _muted : _danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                if (matchingVariation != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    matchingVariation.value,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: _brown,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Flexible(
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              for (final ProductOptionData group in groups) ...[
                                Text(
                                  group.name,
                                  style: const TextStyle(
                                    color: _brown,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: group.values.map((String value) {
                                    final bool selected =
                                        pendingSelections[group.name] == value;
                                    final ProductVariationData? optionPreview =
                                        _variationForOptionValue(
                                          group,
                                          value,
                                          pendingSelections,
                                        );
                                    final List<String> optionImages =
                                        optionPreview?.galleryImages ??
                                            const <String>[];
                                    return Material(
                                      color: selected
                                          ? const Color(0xFFF5E4DA)
                                          : const Color(0xFFF8F7F5),
                                      borderRadius: BorderRadius.circular(9),
                                      child: InkWell(
                                        onTap: () {
                                          setModalState(() {
                                            pendingSelections[group.name] = value;
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(9),
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: _isColorOption(group.name)
                                                ? 7
                                                : 13,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(9),
                                            border: Border.all(
                                              color: selected ? _maroon : _border,
                                              width: selected ? 1.4 : 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (_isColorOption(group.name))
                                                Container(
                                                  width: 30,
                                                  height: 30,
                                                  clipBehavior: Clip.antiAlias,
                                                  decoration: BoxDecoration(
                                                    shape: BoxShape.circle,
                                                    color: _colorForOption(value),
                                                    border: Border.all(
                                                      color: selected
                                                          ? _maroon
                                                          : _border,
                                                    ),
                                                  ),
                                                  child: optionImages.isEmpty
                                                      ? null
                                                      : _ProductImage(
                                                          url: optionImages.first,
                                                        ),
                                                ),
                                              if (_isColorOption(group.name))
                                                const SizedBox(width: 6),
                                              Text(
                                                value,
                                                style: TextStyle(
                                                  color: selected ? _maroon : _text,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 16),
                              ],
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF8F1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: _border),
                                ),
                                child: Text(
                                  matchingVariation == null
                                      ? 'Select all options to see the available price and stock.'
                                      : matchingVariation.stock == null
                                      ? 'Selected option: ${matchingVariation.value}'
                                      : '${_formatPrice(matchingVariation.price ?? _product.price)} · ${_variationStock(matchingVariation)} available',
                                  style: const TextStyle(
                                    color: _brown,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Quantity',
                                      style: TextStyle(
                                        color: _brown,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  _QuantityButton(
                                    icon: Icons.remove_rounded,
                                    enabled: _quantity > 1,
                                    onTap: () {
                                      setModalState(() {
                                        if (_quantity > 1) _quantity--;
                                      });
                                    },
                                  ),
                                  Container(
                                    width: 42,
                                    height: 40,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: _surface,
                                      border: Border.symmetric(
                                        horizontal: BorderSide(color: _border),
                                      ),
                                    ),
                                    child: Text(
                                      '$_quantity',
                                      style: const TextStyle(
                                        color: _text,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  _QuantityButton(
                                    icon: Icons.add_rounded,
                                    enabled: previewStock > 0 &&
                                        _quantity < previewStock,
                                    onTap: () {
                                      setModalState(() {
                                        if (_quantity < previewStock) _quantity++;
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton(
                          onPressed: canContinue
                              ? () {
                                  setState(() {
                                    _selectedOptionValues =
                                        Map<String, String>.from(
                                          pendingSelections,
                                        );
                                    _selectedVariation = matchingVariation;
                                    _clampQuantity();
                                    _resetGalleryToSelectedOption();
                                  });
                                  Navigator.of(sheetContext).pop(true);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: _maroon,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor:
                                _maroon.withValues(alpha: 0.25),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            actionLabel,
                            style: TextStyle(fontWeight: FontWeight.w900),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  bool _validatePurchase() {
    if (_hasSelectableOptions && _selectedVariation == null) {
      _showMessage('Choose a product option first.', error: true);

      return false;
    }

    if (_availableStock < 1) {
      _showMessage('This product option is out of stock.', error: true);

      return false;
    }

    if (_quantity < 1 || _quantity > _availableStock) {
      _showMessage('Choose a valid quantity.', error: true);

      return false;
    }

    return true;
  }

  Future<void> _refresh() async {
    if (widget.onRefresh != null) {
      await widget.onRefresh!();
    }
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
    final bool wide = MediaQuery.sizeOf(context).width >= 900;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refresh,
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverToBoxAdapter(
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              wide ? 22 : 14,
                              wide ? 18 : 12,
                              wide ? 22 : 14,
                              wide ? 32 : 118,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (wide) ...[
                                  _buildBreadcrumb(),

                                  const SizedBox(height: 14),
                                ],

                                if (wide)
                                  _buildDesktopHero()
                                else ...[
                                  _buildGalleryCard(),

                                  const SizedBox(height: 14),

                                  _buildProductPanel(showDesktopActions: false),
                                ],

                                const SizedBox(height: 16),

                                if (_product.sellerName?.trim().isNotEmpty ==
                                    true)
                                  _buildSellerBand(),

                                if (_product.sellerName?.trim().isNotEmpty ==
                                    true)
                                  const SizedBox(height: 16),

                                _buildDescriptionAndSpecifications(wide: wide),

                                const SizedBox(height: 16),

                                _buildReviewsPanel(),

                                if (_relatedProducts.isNotEmpty) ...[
                                  const SizedBox(height: 26),

                                  _buildRelatedProducts(wide: wide),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!wide) _buildPurchaseBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      height: 62,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: Color(0xFFF0E6DC))),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed:
                widget.onBack ??
                () {
                  Navigator.of(context).maybePop();
                },
            icon: const Icon(Icons.arrow_back_rounded, color: _text, size: 22),
          ),

          const SizedBox(width: 2),

          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Details',
                  style: TextStyle(
                    color: _text,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.25,
                  ),
                ),

                SizedBox(height: 1),

                Text(
                  'LIKHAE Marketplace',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          IconButton(
            tooltip: 'Wishlist',
            onPressed: _updatingWishlist ? null : _toggleWishlist,
            icon: _updatingWishlist
                ? const SizedBox(
                    width: 19,
                    height: 19,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _maroon,
                    ),
                  )
                : Icon(
                    _wishlisted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: _maroon,
                    size: 21,
                  ),
          ),

          IconButton(
            tooltip: 'Cart',
            onPressed: widget.onCart,
            icon: const Icon(
              Icons.shopping_bag_outlined,
              color: _maroon,
              size: 21,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBreadcrumb() {
    final String category = _product.category?.trim() ?? '';

    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 7,
      runSpacing: 4,
      children: [
        const Text(
          'Products',
          style: TextStyle(
            color: _brown,
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
          ),
        ),

        const Text('/', style: TextStyle(color: _muted2, fontSize: 10.5)),

        if (category.isNotEmpty) ...[
          Text(category, style: const TextStyle(color: _brown, fontSize: 10.5)),

          const Text('/', style: TextStyle(color: _muted2, fontSize: 10.5)),
        ],

        Text(
          _product.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: _text,
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHero() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 11, child: _buildGalleryCard()),

        const SizedBox(width: 18),

        Expanded(flex: 10, child: _buildProductPanel(showDesktopActions: true)),
      ],
    );
  }

  Widget _buildGalleryCard() {
    final List<String> images = _images;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 1.03,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(17),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: const Color(0xFFF3ECE4),
                    child: images.isEmpty
                        ? const Center(
                            child: Icon(
                              Icons.inventory_2_outlined,
                              color: _muted2,
                              size: 52,
                            ),
                          )
                        : PageView.builder(
                            controller: _galleryController,
                            itemCount: images.length,
                            onPageChanged: (int index) {
                              setState(() {
                                _currentImageIndex = index;
                              });
                            },
                            itemBuilder: (BuildContext context, int index) {
                              return _ProductImage(url: images[index]);
                            },
                          ),
                  ),

                  if (_product.discountPercentage != null)
                    Positioned(
                      left: 12,
                      top: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _maroon,
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '-${_product.discountPercentage!.round()}%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            letterSpacing: 0.4,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),

                  if (images.length > 1)
                    Positioned(
                      right: 12,
                      bottom: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _maroonDark.withValues(alpha: 0.82),
                          borderRadius: BorderRadius.circular(100),
                        ),
                        child: Text(
                          '${_currentImageIndex + 1}/${images.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (images.length > 1) ...[
            const SizedBox(height: 10),

            SizedBox(
              height: 62,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: images.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (BuildContext context, int index) {
                  final bool active = index == _currentImageIndex;

                  return GestureDetector(
                    onTap: () {
                      _galleryController.animateToPage(
                        index,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                      );
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 62,
                      clipBehavior: Clip.antiAlias,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: active ? _maroon : _border,
                          width: active ? 1.8 : 1,
                        ),
                      ),
                      child: _ProductImage(url: images[index]),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProductPanel({required bool showDesktopActions}) {
    final String category = _product.category?.trim() ?? '';

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (category.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF6EAE3),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                category.toUpperCase(),
                style: const TextStyle(
                  color: _maroon,
                  fontSize: 9.5,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

          if (category.isNotEmpty) const SizedBox(height: 10),

          Text(
            _product.name,
            style: TextStyle(
              color: _text,
              fontSize: showDesktopActions ? 29 : 23,
              height: 1.08,
              letterSpacing: -0.7,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 11),

          Wrap(
            spacing: 10,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (_product.rating != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded, color: _star, size: 15),

                    const SizedBox(width: 3),

                    Text(
                      _product.rating!.toStringAsFixed(1),
                      style: const TextStyle(
                        color: _brown,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),

              Text(
                '${_product.reviewCount} ${_product.reviewCount == 1 ? 'review' : 'reviews'}',
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),

              Text(
                '${_product.soldCount} sold',
                style: const TextStyle(color: _muted, fontSize: 10.5),
              ),
            ],
          ),

          const SizedBox(height: 15),

          _buildPricePanel(),

          if (_product.variations.isNotEmpty) ...[
            const SizedBox(height: 16),

            _buildInlineVariations(),
          ],

          const SizedBox(height: 16),

          const Divider(height: 1, color: _border),

          const SizedBox(height: 14),

          _buildInlineQuantity(),

          const SizedBox(height: 16),

          _buildDeliveryProtection(),

          if (showDesktopActions) ...[
            const SizedBox(height: 17),

            _buildDesktopActions(),
          ],
        ],
      ),
    );
  }

  Widget _buildPricePanel() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7EBDD),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE6CCB6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              Text(
                _formatPrice(_displayPrice),
                style: const TextStyle(
                  color: _maroon,
                  fontSize: 25,
                  height: 1,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w900,
                ),
              ),

              if (_selectedVariation == null &&
                  _product.originalPrice != null &&
                  _product.originalPrice! > _product.price)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    _formatPrice(_product.originalPrice!),
                    style: const TextStyle(
                      color: _muted2,
                      fontSize: 11.5,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Icon(
                _outOfStock
                    ? Icons.cancel_outlined
                    : Icons.check_circle_outline_rounded,
                color: _outOfStock ? _danger : _success,
                size: 14,
              ),

              const SizedBox(width: 5),

              Text(
                _outOfStock ? 'Out of stock' : '$_availableStock available',
                style: TextStyle(
                  color: _outOfStock ? _danger : _success,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const Spacer(),

              const Text(
                'Price shown before delivery fee',
                style: TextStyle(color: _muted, fontSize: 9.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInlineVariations() {
    final List<ProductOptionData> groups = _optionGroups;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final ProductOptionData group in groups) ...[
          Text(
            group.name.toUpperCase(),
            style: const TextStyle(
              color: _brown,
              fontSize: 10,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: group.values.map((String value) {
              final bool selected = _selectedOptionValues[group.name] == value;
              final ProductVariationData? previewVariation =
                  _variationForOptionValue(group, value, _selectedOptionValues);
              final List<String> previewImages =
                  previewVariation?.galleryImages ?? const <String>[];
              return Material(
                color: selected ? const Color(0xFFF5E4DA) : _surface,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: () {
                    final Map<String, String> nextSelections =
                        Map<String, String>.from(_selectedOptionValues)
                          ..[group.name] = value;
                    final ProductVariationData? matching =
                        _findVariationForSelections(nextSelections);
                    setState(() {
                      _selectedOptionValues = nextSelections;
                      _selectedVariation = matching;
                      _clampQuantity();
                      _resetGalleryToSelectedOption();
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: selected ? _maroon : _border,
                        width: selected ? 1.4 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isColorOption(group.name)) ...[
                          Container(
                            width: 22,
                            height: 22,
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _colorForOption(value),
                              border: Border.all(
                                color: selected
                                    ? _maroon
                                    : _border,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: previewImages.isEmpty
                                ? null
                                : _ProductImage(url: previewImages.first),
                          ),

                          const SizedBox(width: 7),
                        ],

                        if (selected) ...[
                          const Icon(
                            Icons.check_rounded,
                            color: _maroon,
                            size: 14,
                          ),

                          const SizedBox(width: 4),
                        ],

                        Text(
                          value,
                          style: TextStyle(
                            color: selected ? _maroon : _text,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          if (group.name != groups.last.name) const SizedBox(height: 13),
        ],
      ],
    );
  }

  Widget _buildInlineQuantity() {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'QUANTITY',
                style: TextStyle(
                  color: _brown,
                  fontSize: 10,
                  letterSpacing: 0.8,
                  fontWeight: FontWeight.w900,
                ),
              ),

              SizedBox(height: 3),

              Text(
                'Choose how many you want.',
                style: TextStyle(color: _muted, fontSize: 10),
              ),
            ],
          ),
        ),

        _QuantityButton(
          icon: Icons.remove_rounded,
          enabled: !_outOfStock && _quantity > 1,
          onTap: _decreaseQuantity,
        ),

        Container(
          width: 50,
          height: 40,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: _surface,
            border: Border.symmetric(horizontal: BorderSide(color: _border)),
          ),
          child: Text(
            '$_quantity',
            style: const TextStyle(
              color: _text,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),

        _QuantityButton(
          icon: Icons.add_rounded,
          enabled: !_outOfStock && _quantity < _availableStock,
          onTap: _increaseQuantity,
        ),
      ],
    );
  }

  Widget _buildDeliveryProtection() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF6),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _SmallInfoTile(
              icon: Icons.local_shipping_outlined,
              title: 'Delivery',
              body: 'Courier and fee are confirmed at checkout.',
            ),
          ),

          SizedBox(width: 12),

          Expanded(
            child: _SmallInfoTile(
              icon: Icons.verified_user_outlined,
              title: 'Buyer protection',
              body: 'Order progress is tracked through LIKHAE.',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopActions() {
    final bool busy = _addingToCart || _buyingNow;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: busy || _outOfStock ? null : _addToCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _maroon),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: _addingToCart
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _maroon,
                        ),
                      )
                    : const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 9),

            Expanded(
              child: ElevatedButton(
                  onPressed: busy || (_outOfStock && !_hasSelectableOptions)
                      ? null
                      : _buyNow,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _maroon.withValues(alpha: 0.35),
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: _buyingNow
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _outOfStock && !_hasSelectableOptions
                            ? 'Out of Stock'
                            : _hasSelectableOptions && _selectedVariation == null
                            ? 'Choose Options'
                            : 'Buy Now',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 9),

        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _updatingWishlist ? null : _toggleWishlist,
            style: OutlinedButton.styleFrom(
              foregroundColor: _maroon,
              side: const BorderSide(color: _tan),
              minimumSize: const Size.fromHeight(42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            icon: _updatingWishlist
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: _maroon,
                    ),
                  )
                : Icon(
                    _wishlisted
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 15,
                  ),
            label: Text(
              _wishlisted ? 'Saved to Wishlist' : 'Save to Wishlist',
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSellerBand() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool compact = constraints.maxWidth < 560;

          final Widget sellerInfo = Row(
            children: [
              _SellerAvatar(product: _product),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            _product.sellerVerified
                                ? 'VERIFIED SELLER'
                                : 'SELLER',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: _product.sellerVerified
                                  ? _success
                                  : _muted,
                              fontSize: 9.5,
                              letterSpacing: 0.8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),

                        if (_product.sellerVerified) ...[
                          const SizedBox(width: 4),

                          const Icon(
                            Icons.verified_rounded,
                            color: _success,
                            size: 13,
                          ),
                        ],
                      ],
                    ),

                    const SizedBox(height: 3),

                    Text(
                      _product.sellerName!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    if (_product.sellerLocation?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),

                      Text(
                        _product.sellerLocation!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _muted,
                          fontSize: 10,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          );

          final Widget buttons = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: widget.onViewStore == null
                    ? null
                    : () {
                        widget.onViewStore!(_product);
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _tan),
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'View Store',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),

              const SizedBox(width: 7),

              ElevatedButton(
                onPressed: widget.onMessageSeller == null
                    ? null
                    : () {
                        widget.onMessageSeller!(_product);
                      },
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Text(
                  'Message',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          );

          if (compact) {
            return Column(
              children: [
                sellerInfo,

                const SizedBox(height: 12),

                Align(alignment: Alignment.centerRight, child: buttons),
              ],
            );
          }

          return Row(
            children: [
              Expanded(child: sellerInfo),

              const SizedBox(width: 12),

              buttons,
            ],
          );
        },
      ),
    );
  }

  Widget _buildDescriptionAndSpecifications({required bool wide}) {
    final bool hasDescription = _product.description?.trim().isNotEmpty == true;

    final bool hasSpecifications = _product.specifications.isNotEmpty;

    if (!hasDescription && !hasSpecifications) {
      return const SizedBox.shrink();
    }

    final Widget? description = hasDescription ? _buildDescriptionCard() : null;

    final Widget? specs = hasSpecifications ? _buildSpecificationsCard() : null;

    if (wide && description != null && specs != null) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 7, child: description),

          const SizedBox(width: 16),

          Expanded(flex: 3, child: specs),
        ],
      );
    }

    return Column(
      children: [
        ?description,

        if (description != null && specs != null) const SizedBox(height: 14),

        ?specs,
      ],
    );
  }

  Widget _buildDescriptionCard() {
    final String description = _product.description!.trim();

    final bool longDescription = description.length > 360;

    return _EditorialCard(
      eyebrow: 'PRODUCT STORY',
      title: 'Description',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            crossFadeState: _descriptionExpanded || !longDescription
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Text(
              description,
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _brown,
                fontSize: 11.5,
                height: 1.65,
              ),
            ),
            secondChild: Text(
              description,
              style: const TextStyle(
                color: _brown,
                fontSize: 11.5,
                height: 1.65,
              ),
            ),
          ),

          if (longDescription) ...[
            const SizedBox(height: 8),

            TextButton(
              onPressed: () {
                setState(() {
                  _descriptionExpanded = !_descriptionExpanded;
                });
              },
              style: TextButton.styleFrom(
                foregroundColor: _maroon,
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                _descriptionExpanded ? 'Show less' : 'Read more',
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSpecificationsCard() {
    final List<MapEntry<String, String>> items = _product.specifications.entries
        .toList();

    return _EditorialCard(
      eyebrow: 'DETAILS',
      title: 'Specifications',
      child: Column(
        children: List.generate(items.length, (int index) {
          final MapEntry<String, String> item = items[index];

          return Container(
            padding: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              border: index == items.length - 1
                  ? null
                  : const Border(bottom: BorderSide(color: Color(0xFFF0E7DE))),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 4,
                  child: Text(
                    item.key,
                    style: const TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ),

                const SizedBox(width: 8),

                Expanded(
                  flex: 6,
                  child: Text(
                    item.value,
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: _text,
                      fontSize: 10.5,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildReviewsPanel() {
    final double displayRating = _product.rating ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CUSTOMER FEEDBACK',
                      style: TextStyle(
                        color: _maroon,
                        fontSize: 9.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    SizedBox(height: 5),

                    Text(
                      'Ratings & Reviews',
                      style: TextStyle(
                        color: _text,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${displayRating.toStringAsFixed(1)} ',
                    style: const TextStyle(
                      color: _maroon,
                      fontSize: 24,
                      height: 1,
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 3),

                  _StarDisplay(rating: displayRating),

                  const SizedBox(height: 3),

                  Text(
                    '${_product.reviewCount} ${_product.reviewCount == 1 ? 'rating' : 'ratings'}',
                    style: const TextStyle(color: _muted, fontSize: 9.5),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          const Divider(height: 1, color: _border),

          if (_product.reviews.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Icon(Icons.rate_review_outlined, color: _muted2, size: 18),

                  SizedBox(width: 8),

                  Text(
                    'No written reviews yet.',
                    style: TextStyle(color: _muted, fontSize: 11),
                  ),
                ],
              ),
            )
          else
            Column(
              children: List.generate(_product.reviews.length, (int index) {
                return _ReviewCard(
                  review: _product.reviews[index],
                  showDivider: index != _product.reviews.length - 1,
                );
              }),
            ),
        ],
      ),
    );
  }

  Widget _buildRelatedProducts({required bool wide}) {
    final List<ProductDetailData> products = _relatedProducts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'KEEP EXPLORING',
          style: TextStyle(
            color: _maroon,
            fontSize: 9.5,
            letterSpacing: 1.4,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 4),

        const Text(
          'Related Products',
          style: TextStyle(
            color: _text,
            fontSize: 21,
            letterSpacing: -0.6,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 3),

        const Text(
          'More finds you may like.',
          style: TextStyle(color: _muted, fontSize: 10.5),
        ),

        const SizedBox(height: 13),

        if (wide)
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              const double spacing = 12;

              final int columns = constraints.maxWidth >= 1040 ? 4 : 3;

              final double width =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                spacing: spacing,
                runSpacing: 12,
                children: products.map((ProductDetailData product) {
                  return SizedBox(
                    width: width,
                    child: _RelatedProductCard(
                      product: product,
                      onTap: widget.onRelatedProductSelected == null
                          ? null
                          : () {
                              widget.onRelatedProductSelected!(product);
                            },
                    ),
                  );
                }).toList(),
              );
            },
          )
        else
          SizedBox(
            height: 250,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: products.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(width: 10),
              itemBuilder: (BuildContext context, int index) {
                final ProductDetailData product = products[index];

                return SizedBox(
                  width: 166,
                  child: _RelatedProductCard(
                    product: product,
                    onTap: widget.onRelatedProductSelected == null
                        ? null
                        : () {
                            widget.onRelatedProductSelected!(product);
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
    final bool busy = _addingToCart || _buyingNow;

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        decoration: BoxDecoration(
          color: _surface,
          border: const Border(top: BorderSide(color: _border)),
          boxShadow: [
            BoxShadow(
              color: _maroon.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 47,
              height: 47,
              child: OutlinedButton(
                onPressed: _updatingWishlist ? null : _toggleWishlist,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  padding: EdgeInsets.zero,
                  side: const BorderSide(color: _tan),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _updatingWishlist
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _maroon,
                        ),
                      )
                    : Icon(
                        _wishlisted
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 19,
                      ),
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: OutlinedButton(
                onPressed: busy || _outOfStock ? null : _addToCart,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _maroon),
                  minimumSize: const Size.fromHeight(47),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _addingToCart
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: _maroon,
                        ),
                      )
                    : const Text(
                        'Add to Cart',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),

            const SizedBox(width: 7),

            Expanded(
              child: ElevatedButton(
                onPressed: busy || (_outOfStock && !_hasSelectableOptions)
                    ? null
                    : _buyNow,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: _maroon.withValues(alpha: 0.35),
                  minimumSize: const Size.fromHeight(47),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _buyingNow
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        _outOfStock && !_hasSelectableOptions
                            ? 'Out of Stock'
                            : _hasSelectableOptions && _selectedVariation == null
                            ? 'Choose Options'
                            : 'Buy Now',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatPrice(double value) {
    final String raw = value.toStringAsFixed(2);

    final List<String> parts = raw.split('.');

    final String whole = parts.first;

    final String decimals = parts.length > 1 ? parts.last : '00';

    final StringBuffer buffer = StringBuffer();

    for (int index = 0; index < whole.length; index++) {
      final int remaining = whole.length - index;

      buffer.write(whole[index]);

      if (remaining > 1 && remaining % 3 == 1) {
        buffer.write(',');
      }
    }

    return '₱${buffer.toString()}.$decimals';
  }
}

class _EditorialCard extends StatelessWidget {
  final String eyebrow;
  final String title;
  final Widget child;

  const _EditorialCard({
    required this.eyebrow,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: const TextStyle(
              color: Color(0xFF561C17),
              fontSize: 9.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3B211B),
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 13),

          child,
        ],
      ),
    );
  }
}

class _SmallInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _SmallInfoTile({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: const Color(0xFFF3E6DA),
            borderRadius: BorderRadius.circular(9),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: const Color(0xFF561C17), size: 15),
        ),

        const SizedBox(width: 8),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Color(0xFF3B211B),
                  fontSize: 10.5,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                body,
                style: const TextStyle(
                  color: Color(0xFF987865),
                  fontSize: 9.5,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StarDisplay extends StatelessWidget {
  final double rating;

  const _StarDisplay({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int index) {
        return Icon(
          index + 1 <= rating.round()
              ? Icons.star_rounded
              : Icons.star_border_rounded,
          color: const Color(0xFFC88418),
          size: 12,
        );
      }),
    );
  }
}

class _QuantityButton extends StatelessWidget {
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
      color: enabled ? const Color(0xFFFFFDF9) : const Color(0xFFF3ECE4),
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFEADCCC)),
          ),
          child: Icon(
            icon,
            color: enabled ? const Color(0xFF561C17) : const Color(0xFFA99386),
            size: 17,
          ),
        ),
      ),
    );
  }
}

class _SellerAvatar extends StatelessWidget {
  final ProductDetailData product;

  const _SellerAvatar({required this.product});

  @override
  Widget build(BuildContext context) {
    final String? url = product.sellerAvatarUrl;

    return Container(
      width: 52,
      height: 52,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        color: const Color(0xFF6A2019),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: url == null || url.trim().isEmpty
          ? _SellerInitial(value: product.sellerInitial)
          : Image.network(
              AppConfig.resolveMediaUrl(url),
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
                        width: 17,
                        height: 17,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      ),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _SellerInitial(value: product.sellerInitial);
                  },
            ),
    );
  }
}

class _SellerInitial extends StatelessWidget {
  final String value;

  const _SellerInitial({required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: const Color(0xFF6A2019),
      child: Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _ReviewCard extends StatelessWidget {
  final ProductReviewData review;
  final bool showDivider;

  const _ReviewCard({required this.review, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: showDivider
            ? const Border(bottom: BorderSide(color: Color(0xFFF0E8DF)))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ReviewAvatar(review: review),

          const SizedBox(width: 9),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        review.buyerName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF3B211B),
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),

                    if (review.date.isNotEmpty)
                      Text(
                        review.date,
                        style: const TextStyle(
                          color: Color(0xFFA99386),
                          fontSize: 9.5,
                        ),
                      ),
                  ],
                ),

                const SizedBox(height: 4),

                Row(
                  children: List<Widget>.generate(5, (int index) {
                    return Icon(
                      index < review.rating
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: const Color(0xFFC88418),
                      size: 13,
                    );
                  }),
                ),

                if (review.body.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),

                  Text(
                    review.body,
                    style: const TextStyle(
                      color: Color(0xFF6C4936),
                      fontSize: 10.5,
                      height: 1.5,
                    ),
                  ),
                ],

                if (review.hasPhoto) ...[
                  const SizedBox(height: 6),

                  const Row(
                    children: [
                      Icon(
                        Icons.photo_outlined,
                        color: Color(0xFF987865),
                        size: 13,
                      ),

                      SizedBox(width: 4),

                      Text(
                        'Review includes a photo',
                        style: TextStyle(
                          color: Color(0xFF987865),
                          fontSize: 9.5,
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

class _ReviewAvatar extends StatelessWidget {
  final ProductReviewData review;

  const _ReviewAvatar({required this.review});

  @override
  Widget build(BuildContext context) {
    final String? url = review.buyerAvatarUrl;

    return Container(
      width: 34,
      height: 34,
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFFF1E4D7),
      ),
      child: url == null || url.trim().isEmpty
          ? Center(
              child: Text(
                review.buyerInitial,
                style: const TextStyle(
                  color: Color(0xFF561C17),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            )
          : Image.network(
              AppConfig.resolveMediaUrl(url),
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Center(
                      child: Text(
                        review.buyerInitial,
                        style: const TextStyle(
                          color: Color(0xFF561C17),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    );
                  },
            ),
    );
  }
}

class _RelatedProductCard extends StatelessWidget {
  final ProductDetailData product;
  final VoidCallback? onTap;

  const _RelatedProductCard({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final List<String> images = product.galleryImages;

    return Material(
      color: const Color(0xFFFFFDF9),
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFEADCCC)),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: 1,
                child: Container(
                  width: double.infinity,
                  color: const Color(0xFFF3ECE4),
                  child: images.isEmpty
                      ? const Icon(
                          Icons.inventory_2_outlined,
                          color: Color(0xFFA99386),
                        )
                      : _ProductImage(url: images.first),
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(10),
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
                          fontSize: 10,
                          letterSpacing: 0.6,
                          fontWeight: FontWeight.w800,
                        ),
                      ),

                      const SizedBox(height: 4),
                    ],

                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3B211B),
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Text(
                      _ProductDetailsScreenState._formatPrice(product.price),
                      style: const TextStyle(
                        color: Color(0xFF561C17),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        if (product.rating != null) ...[
                          const Icon(
                            Icons.star_rounded,
                            size: 11,
                            color: Color(0xFFC88418),
                          ),

                          const SizedBox(width: 2),

                          Text(
                            product.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: Color(0xFF6C4936),
                              fontSize: 10,
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
                              fontSize: 10,
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

class _ProductImage extends StatelessWidget {
  final String? url;

  const _ProductImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final String? imageUrl = url?.trim();

    if (imageUrl == null || imageUrl.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFFA99386),
          size: 38,
        ),
      );
    }

    final String resolvedUrl = AppConfig.resolveMediaUrl(imageUrl);

    return Image.network(
      resolvedUrl,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 23,
                height: 23,
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
                size: 38,
              ),
            );
          },
    );
  }
}

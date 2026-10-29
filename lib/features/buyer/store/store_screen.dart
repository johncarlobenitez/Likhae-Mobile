import 'dart:async';

import '../../../shared/widgets/sized_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/core/utils/api_value_parsers.dart';
import 'package:likhae/shared/widgets/price_range_filter.dart';
import 'package:likhae/services/product_service.dart';
import 'package:likhae/services/wishlist_service.dart';

typedef StoreProductCallback = void Function(StoreProductData product);

typedef StoreAsyncProductCallback =
    Future<void> Function(StoreProductData product);

typedef StoreRefreshCallback = Future<void> Function();

typedef StoreFollowCallback =
    Future<StoreFollowResult> Function(bool following);

typedef StoreVoucherCallback = void Function(StoreVoucherData voucher);

typedef StoreVoucherClaimCallback = Future<void> Function(int voucherId);

class StoreFollowResult {
  final bool following;
  final int? followers;

  const StoreFollowResult({required this.following, this.followers});
}

class StoreVoucherData {
  final String id;
  final String code;
  final String name;
  final String discountType;
  final double discountValue;
  final double minimumOrderAmount;
  final double? maximumDiscountAmount;
  final String expires;
  final bool isCollected;

  const StoreVoucherData({
    required this.id,
    required this.code,
    required this.name,
    required this.discountType,
    required this.discountValue,
    required this.minimumOrderAmount,
    required this.expires,
    this.maximumDiscountAmount,
    this.isCollected = false,
  });

  factory StoreVoucherData.fromApi(Map<String, dynamic> json) {
    return StoreVoucherData(
      id: (json['id'] ?? '').toString(),
      code: (json['code'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      discountType: (json['discount_type'] ?? '').toString().toUpperCase(),
      discountValue:
          double.tryParse((json['discount_value'] ?? 0).toString()) ?? 0,
      minimumOrderAmount:
          double.tryParse((json['minimum_order_amount'] ?? 0).toString()) ?? 0,
      maximumDiscountAmount: json['maximum_discount_amount'] == null
          ? null
          : double.tryParse(json['maximum_discount_amount'].toString()),
      expires: (json['expires'] ?? '').toString(),
      isCollected:
          json['is_collected'] == true || json['collected'] == true,
    );
  }

  String get benefitLabel {
    if (discountType == 'PERCENT') {
      final String amount = discountValue == discountValue.roundToDouble()
          ? discountValue.toStringAsFixed(0)
          : discountValue
                .toStringAsFixed(2)
                .replaceFirst(RegExp(r'0+$'), '')
                .replaceFirst(RegExp(r'\.$'), '');
      return '$amount% off';
    }
    return '₱${discountValue.toStringAsFixed(2)} off';
  }
}

class StoreSellerData {
  final int id;

  final String name;
  final String slug;

  final String? avatarUrl;
  final String? coverImageUrl;
  final String? location;
  final String? joinedYear;

  final double? rating;

  /// Optional seller metrics.
  ///
  /// These must only be supplied when Laravel actually has
  /// a value for them. Flutter does not manufacture seller
  /// performance statistics.
  final String? followers;
  final bool isFollowing;
  final String? response;
  final String? fulfillment;

  final String? description;
  final String? businessHours;

  /// true  = Laravel explicitly says verified.
  /// false = Laravel explicitly says not verified.
  /// null  = verification state was not supplied.
  final bool? verified;
  final bool onVacation;
  final List<StoreVoucherData> vouchers;

  const StoreSellerData({
    required this.id,
    required this.name,
    required this.slug,
    this.avatarUrl,
    this.coverImageUrl,
    this.location,
    this.joinedYear,
    this.rating,
    this.followers,
    this.isFollowing = false,
    this.response,
    this.fulfillment,
    this.description,
    this.businessHours,
    this.verified,
    this.onVacation = false,
    this.vouchers = const <StoreVoucherData>[],
  });

  factory StoreSellerData.fromApi(Map<String, dynamic> json) {
    final double? parsedRating = double.tryParse(
      (json['rating'] ?? json['average_rating'])?.toString() ?? '',
    );
    return StoreSellerData(
      id:
          int.tryParse(
            (json['id'] ?? json['user_id'] ?? json['seller_user_id'])
                    ?.toString() ??
                '',
          ) ??
          0,
      name:
          (json['name'] ??
                  json['business_name'] ??
                  json['store_name'] ??
                  'Seller')
              .toString(),
      slug: (json['slug'] ?? json['store_slug'] ?? json['seller_slug'] ?? '')
          .toString(),
      avatarUrl: _mediaValue(
        json['avatar_url'] ??
            json['logo_url'] ??
            json['avatar_path'] ??
            json['seller_avatar'],
      ),
      coverImageUrl: _mediaValue(
        json['cover_image_url'] ??
            json['cover_photo_url'] ??
            json['cover_url'] ??
            json['banner_url'] ??
            json['banner_path'] ??
            json['cover_image'] ??
            json['cover_photo'] ??
            json['banner'],
      ),
      location: _formatLocation(json['location'] ?? json['seller_location']),
      joinedYear: _formatJoinedDate(
        json['joined_at'] ??
            json['created_at'] ??
            json['joined_year'] ??
            json['year_joined'],
      ),
      rating: parsedRating != null && parsedRating > 0 ? parsedRating : null,
      followers: _metricText(json['followers'] ?? json['followers_count']),
      isFollowing: parseApiBool(
        json['is_following'] ?? json['following'],
        defaultValue: false,
      ),
      response: _metricText(
        json['response'] ?? json['response_rate'] ?? json['response_time'],
      ),
      fulfillment: _metricText(json['fulfillment'] ?? json['fulfillment_rate']),
      description: json['description']?.toString(),
      verified: json.containsKey('verified') || json.containsKey('is_verified')
          ? parseApiBool(
              json['verified'] ?? json['is_verified'],
              defaultValue: false,
            )
          : null,
      onVacation: parseApiBool(
        json['is_on_vacation'] ??
            json['is_vacation_mode'] ??
            json['vacation_mode'],
        defaultValue: false,
      ),
      vouchers: json['vouchers'] is List
          ? (json['vouchers'] as List)
                .whereType<Map>()
                .map(
                  (Map row) =>
                      StoreVoucherData.fromApi(Map<String, dynamic>.from(row)),
                )
                .where((StoreVoucherData voucher) => voucher.code.isNotEmpty)
                .toList(growable: false)
          : const <StoreVoucherData>[],
    );
  }

  static String? _mediaValue(dynamic raw) {
    final dynamic value = raw is Map
        ? (raw['url'] ?? raw['image_url'] ?? raw['path'] ?? raw['src'])
        : raw;
    final String normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? null : normalized;
  }

  static String? _formatJoinedDate(dynamic raw) {
    final String value = raw?.toString().trim() ?? '';
    if (value.isEmpty) return null;
    final DateTime? date = DateTime.tryParse(value);
    if (date == null) return value;
    const List<String> months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${months[date.month - 1]} ${date.year}';
  }

  static String? _formatLocation(dynamic raw) {
    if (raw is! Map) {
      final String value = raw?.toString().trim() ?? '';
      return value.isEmpty ? null : value;
    }
    final List<String> values =
        <dynamic>[
              raw['name'],
              raw['city'],
              raw['municipality'],
              raw['province'],
            ]
            .where(
              (dynamic value) =>
                  value != null && value.toString().trim().isNotEmpty,
            )
            .map((dynamic value) => value.toString().trim())
            .toSet()
            .toList(growable: false);
    return values.isEmpty ? null : values.join(', ');
  }

  static String? _metricText(dynamic raw) {
    final String value = raw?.toString().trim() ?? '';
    return value.isEmpty ? null : value;
  }

  String get initials {
    final List<String> parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .take(2)
        .toList();

    if (parts.isEmpty) {
      return 'S';
    }

    return parts.map((String part) => part[0].toUpperCase()).join();
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
  final bool isActive;
  final bool isDraft;
  final bool isDeleted;

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
    this.isActive = true,
    this.isDraft = false,
    this.isDeleted = false,
  });

  factory StoreProductData.fromApi(Map<String, dynamic> json) {
    final dynamic rawImage =
        json['image_url'] ??
        json['image'] ??
        json['photo'] ??
        json['primary_image'];
    final String imageValue = rawImage is Map
        ? (rawImage['url'] ??
                  rawImage['image_url'] ??
                  rawImage['file_path'] ??
                  '')
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
    final List<Map<String, dynamic>> variants = rawVariants is List
        ? rawVariants
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList()
        : <Map<String, dynamic>>[];
    Map<String, dynamic>? cheapestVariant;
    for (final Map<String, dynamic> variant in variants) {
      final double candidate =
          double.tryParse(
            (variant['price'] ?? variant['sale_price'] ?? '').toString(),
          ) ??
          double.infinity;
      final double current = cheapestVariant == null
          ? double.infinity
          : double.tryParse(
                  (cheapestVariant['price'] ??
                          cheapestVariant['sale_price'] ??
                          '')
                      .toString(),
                ) ??
                double.infinity;
      if (candidate < current) cheapestVariant = variant;
    }
    final double price =
        double.tryParse(
          (json['min_price'] ??
                  cheapestVariant?['price'] ??
                  cheapestVariant?['sale_price'] ??
                  json['price'] ??
                  defaultVariant?['price'] ??
                  '')
              .toString(),
        ) ??
        0;
    Map<String, dynamic>? priceVariant = cheapestVariant;
    for (final Map<String, dynamic> variant in variants) {
      final double? variantPrice = double.tryParse(
        (variant['price'] ?? variant['sale_price'])?.toString() ?? '',
      );
      if (variantPrice == price) {
        priceVariant = variant;
        break;
      }
    }
    final dynamic rawOriginalPrice = variants.isEmpty
        ? (json['old_price'] ??
              json['original_price'] ??
              (defaultVariant == null
                  ? null
                  : defaultVariant['original_price']))
        : (priceVariant == null
              ? null
              : (priceVariant['old_price'] ?? priceVariant['original_price']));
    final double? originalPrice = double.tryParse(
      rawOriginalPrice?.toString() ?? '',
    );

    return StoreProductData(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: (json['name'] ?? 'Product').toString(),
      slug: json['slug']?.toString(),
      category: json['category'] is Map
          ? (json['category'] as Map)['name']?.toString()
          : json['category']?.toString() ?? json['parent_category']?.toString(),
      imageUrl: imageValue.isEmpty
          ? null
          : AppConfig.resolveMediaUrl(imageValue),
      price: price,
      originalPrice: originalPrice,
      rating: double.tryParse(json['rating']?.toString() ?? ''),
      soldCount:
          int.tryParse(
            json['sold']?.toString() ?? json['sold_count']?.toString() ?? '0',
          ) ??
          0,
      stock: int.tryParse(
        (json['stock'] ?? json['quantity'])?.toString() ?? '',
      ),
      wishlisted: json['wishlisted'] == true || json['wishlist'] == true,
      isActive: parseApiBool(
        json['is_active'] ??
            json['is_available'] ??
            json['active'] ??
            json['is_published'],
        defaultValue: !<String>{
          'inactive',
          'unpublished',
          'draft',
          'deleted',
          'disabled',
        }.contains((json['status'] ?? '').toString().toLowerCase()),
      ),
      isDraft:
          parseApiBool(json['is_draft'], defaultValue: false) ||
          (json['status'] ?? '').toString().toLowerCase() == 'draft',
      isDeleted:
          parseApiBool(
            json['is_deleted'] ?? json['deleted'],
            defaultValue: false,
          ) ||
          json['deleted_at'] != null ||
          (json['status'] ?? '').toString().toLowerCase() == 'deleted',
    );
  }

  double? get discountPercentage {
    final double? original = originalPrice;

    if (original == null || original <= 0 || original <= price) {
      return null;
    }

    return ((original - price) / original) * 100;
  }

  bool get isOutOfStock {
    final int? availableStock = stock;

    if (availableStock == null) {
      return false;
    }

    return availableStock <= 0;
  }

  bool get hasKnownStock {
    return stock != null;
  }

  StoreProductData copyWith({bool? wishlisted}) {
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
      wishlisted: wishlisted ?? this.wishlisted,
      isActive: isActive,
      isDraft: isDraft,
      isDeleted: isDeleted,
    );
  }
}

enum StoreProductSort { defaultSort, priceLow, priceHigh, rating, sold }

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

  final StoreFollowCallback? onFollowShop;

  final StoreVoucherCallback? onUseVoucher;

  final StoreVoucherClaimCallback? onClaimVoucher;

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
  final ValueChanged<List<StoreProductData>>? onProductsChanged;

  const StoreScreen({
    super.key,
    required this.seller,
    this.products = const <StoreProductData>[],
    this.onBack,
    this.onMessageSeller,
    this.onFollowShop,
    this.onUseVoucher,
    this.onClaimVoucher,
    this.onProductSelected,
    this.onWishlistProduct,
    this.onRefresh,
    this.onProductsChanged,
  });

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _softStrong = ShopColors.accentSoft;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroon2 = Color(0xFF642920);

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _muted = ShopColors.muted;

  static const Color _muted2 = ShopColors.faint;

  static const Color _tan = ShopColors.tan;

  static const Color _danger = Color(0xFFB42318);

  late List<StoreProductData> _products;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _storeScrollController = ScrollController();
  final GlobalKey _productsSectionKey = GlobalKey();
  final GlobalKey _categorySectionKey = GlobalKey();
  Timer? _suggestionDebounce;
  int _suggestionRequestVersion = 0;
  List<ProductSearchSuggestion> _searchSuggestions =
      <ProductSearchSuggestion>[];

  final Set<int> _wishlistLoading = <int>{};
  final Set<int> _claimingVoucherIds = <int>{};
  final Set<int> _collectedVoucherIds = <int>{};

  StoreProductSort _sort = StoreProductSort.defaultSort;

  String? _selectedCategory;
  bool _filtersExpanded = false;

  String _query = '';
  double? _minimumPrice;
  double? _maximumPrice;
  double? _minimumRating;
  int _pageIndex = 0;
  static const int _pageSize = 20;

  bool _refreshing = false;

  int _selectedStoreTab = 0;

  bool _isFollowing = false;
  bool _followLoading = false;
  String? _followersLabel;

  @override
  void initState() {
    super.initState();

    _products = List<StoreProductData>.from(widget.products);
    _isFollowing = widget.seller.isFollowing;
    _followersLabel = widget.seller.followers;
    _collectedVoucherIds.addAll(
      widget.seller.vouchers
          .where((StoreVoucherData voucher) => voucher.isCollected)
          .map((StoreVoucherData voucher) => int.tryParse(voucher.id))
          .whereType<int>(),
    );
    WishlistService.productIds.addListener(_onWishlistChanged);
    WishlistService.recordKnownProducts(
      _products.map(
        (StoreProductData product) =>
            (id: product.id, wishlisted: product.wishlisted),
      ),
    );
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
  }

  void _scheduleSearchSuggestions(String query) {
    _suggestionDebounce?.cancel();
    final int requestVersion = ++_suggestionRequestVersion;
    if (!AppConfig.apiEnabled ||
        query.trim().length < 2 ||
        widget.seller.id <= 0) {
      setState(() => _searchSuggestions = <ProductSearchSuggestion>[]);
      return;
    }
    _suggestionDebounce = Timer(const Duration(milliseconds: 1100), () {
      unawaited(_loadSearchSuggestions(query.trim(), requestVersion));
    });
  }

  Future<void> _loadSearchSuggestions(String query, int requestVersion) async {
    try {
      final List<ProductSearchSuggestion> suggestions =
          await ProductService.fetchSearchSuggestions(
            query,
            sellerId: widget.seller.id,
          );
      if (!mounted ||
          requestVersion != _suggestionRequestVersion ||
          query != _query.trim()) {
        return;
      }
      setState(() => _searchSuggestions = suggestions);
    } catch (_) {
      if (!mounted || requestVersion != _suggestionRequestVersion) return;
      setState(() => _searchSuggestions = <ProductSearchSuggestion>[]);
    }
  }

  void _selectSearchSuggestion(ProductSearchSuggestion suggestion) {
    final String query = suggestion.query.trim();
    if (query.isEmpty) return;
    _suggestionDebounce?.cancel();
    _suggestionRequestVersion++;
    _searchController.text = query;
    setState(() {
      _query = query;
      _searchSuggestions = <ProductSearchSuggestion>[];
      _pageIndex = 0;
    });
  }

  @override
  void didUpdateWidget(covariant StoreScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.seller.id != widget.seller.id ||
        oldWidget.seller.slug != widget.seller.slug) {
      _isFollowing = widget.seller.isFollowing;
      _followersLabel = widget.seller.followers;
      _collectedVoucherIds
        ..clear()
        ..addAll(
          widget.seller.vouchers
              .where((StoreVoucherData voucher) => voucher.isCollected)
              .map((StoreVoucherData voucher) => int.tryParse(voucher.id))
              .whereType<int>(),
        );
      _claimingVoucherIds.clear();
      _followLoading = false;
      _selectedCategory = null;
      _minimumPrice = null;
      _maximumPrice = null;
      _minimumRating = null;
      _filtersExpanded = false;
      _selectedStoreTab = 0;
      _query = '';
      _searchController.clear();
      _suggestionDebounce?.cancel();
      _suggestionRequestVersion++;
      _searchSuggestions = <ProductSearchSuggestion>[];
      _pageIndex = 0;
    } else {
      _collectedVoucherIds.addAll(
        widget.seller.vouchers
            .where((StoreVoucherData voucher) => voucher.isCollected)
            .map((StoreVoucherData voucher) => int.tryParse(voucher.id))
            .whereType<int>(),
      );
      if (oldWidget.seller.isFollowing != widget.seller.isFollowing) {
        _isFollowing = widget.seller.isFollowing;
      }
      if (oldWidget.seller.followers != widget.seller.followers) {
        _followersLabel = widget.seller.followers;
      }
    }

    if (oldWidget.products != widget.products) {
      _products = List<StoreProductData>.from(widget.products);

      final Set<int> currentProductIds = _products
          .map((StoreProductData product) => product.id)
          .toSet();

      _wishlistLoading.removeWhere(
        (int productId) => !currentProductIds.contains(productId),
      );
    }
  }

  @override
  void dispose() {
    _suggestionDebounce?.cancel();
    _suggestionRequestVersion++;
    _searchController.dispose();
    _storeScrollController.dispose();
    WishlistService.productIds.removeListener(_onWishlistChanged);

    super.dispose();
  }

  Object? _filterKey;
  List<StoreProductData> _filterResult = [];

  List<StoreProductData> get _visibleProducts {
    final key = (
      _products,
      _query,
      _selectedCategory,
      _sort,
      _minimumPrice,
      _maximumPrice,
      _minimumRating,
    );
    if (_filterKey == key) return _filterResult;

    final String cleanQuery = _query.trim().toLowerCase();

    List<StoreProductData> result = _products.where((StoreProductData product) {
      if (!product.isActive || product.isDraft || product.isDeleted) {
        return false;
      }
      if (_selectedCategory != null &&
          product.category?.trim().toLowerCase() !=
              _selectedCategory!.toLowerCase()) {
        return false;
      }
      if (cleanQuery.isEmpty) {
        return true;
      }

      final String searchable = <String>[
        product.name,
        product.category ?? '',
      ].join(' ').toLowerCase();

      return searchable.contains(cleanQuery);
    }).toList();

    final double minimum = _priceMinimum;
    final double maximum = _priceMaximum;
    result = result
        .where(
          (StoreProductData product) =>
              product.price >= (_minimumPrice ?? minimum) &&
              product.price <= (_maximumPrice ?? maximum),
        )
        .toList();
    if (_minimumRating != null) {
      result = result
          .where(
            (StoreProductData product) =>
                (product.rating ?? 0) >= _minimumRating!,
          )
          .toList();
    }

    switch (_sort) {
      case StoreProductSort.defaultSort:
        break;

      case StoreProductSort.priceLow:
        result.sort((StoreProductData a, StoreProductData b) {
          return a.price.compareTo(b.price);
        });
        break;

      case StoreProductSort.priceHigh:
        result.sort((StoreProductData a, StoreProductData b) {
          return b.price.compareTo(a.price);
        });
        break;

      case StoreProductSort.rating:
        result.sort((StoreProductData a, StoreProductData b) {
          return (b.rating ?? 0).compareTo(a.rating ?? 0);
        });
        break;

      case StoreProductSort.sold:
        result.sort((StoreProductData a, StoreProductData b) {
          return b.soldCount.compareTo(a.soldCount);
        });
        break;
    }

    _filterKey = key;
    return _filterResult = result;
  }

  double get _priceMinimum {
    final List<double> prices = _products
        .where(
          (StoreProductData product) =>
              product.isActive && !product.isDraft && !product.isDeleted,
        )
        .map((StoreProductData product) => product.price)
        .toList(growable: false);
    return prices.isEmpty
        ? 0
        : prices.reduce((double a, double b) => a < b ? a : b);
  }

  double get _priceMaximum {
    final List<double> prices = _products
        .where(
          (StoreProductData product) =>
              product.isActive && !product.isDraft && !product.isDeleted,
        )
        .map((StoreProductData product) => product.price)
        .toList(growable: false);
    return prices.isEmpty
        ? 100000
        : prices.reduce((double a, double b) => a > b ? a : b);
  }

  List<String> get _storeCategories {
    final List<String> categories = _products
        .where(
          (StoreProductData product) =>
              product.isActive && !product.isDraft && !product.isDeleted,
        )
        .map((StoreProductData product) => product.category?.trim() ?? '')
        .where((String category) => category.isNotEmpty)
        .toSet()
        .toList();
    categories.sort(
      (String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()),
    );
    return categories;
  }

  List<StoreProductData> get _pageProducts {
    final List<StoreProductData> all = _visibleProducts;
    final int start = (_pageIndex * _pageSize).clamp(0, all.length).toInt();
    final int end = (start + _pageSize).clamp(0, all.length).toInt();
    return all.sublist(start, end);
  }

  Future<void> _refresh() async {
    final StoreRefreshCallback? callback = widget.onRefresh;

    if (callback == null || _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      await callback();
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _toggleWishlist(StoreProductData product) async {
    if (_wishlistLoading.contains(product.id)) {
      return;
    }

    final StoreAsyncProductCallback? callback = widget.onWishlistProduct;

    if (callback == null) {
      _showMessage('Wishlist will be connected to Laravel later.');

      return;
    }

    setState(() {
      _wishlistLoading.add(product.id);
    });

    try {
      final bool wasWishlisted = WishlistService.isWishlisted(product.id);
      /*
       * Do not optimistically change the heart.
       *
       * Wait for the Laravel wishlist toggle to succeed.
       */
      await callback(product);

      bool newState = WishlistService.isWishlisted(product.id);
      if (newState == wasWishlisted) {
        newState = !wasWishlisted;
        WishlistService.setProductWishlisted(product.id, newState);
      }

      if (!mounted) {
        return;
      }

      final int index = _products.indexWhere(
        (StoreProductData current) => current.id == product.id,
      );

      if (index < 0) {
        return;
      }

      widget.onProductsChanged?.call(
        List<StoreProductData>.unmodifiable(_products),
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

  void _clearSearch() {
    _searchController.clear();

    setState(() {
      _query = '';
      _searchSuggestions = <ProductSearchSuggestion>[];
      _pageIndex = 0;
    });
    _suggestionDebounce?.cancel();
    _suggestionRequestVersion++;
  }

  void _clearProductFilters() {
    _searchController.clear();
    setState(() {
      _query = '';
      _searchSuggestions = <ProductSearchSuggestion>[];
      _selectedCategory = null;
      _minimumPrice = null;
      _maximumPrice = null;
      _minimumRating = null;
      _pageIndex = 0;
    });
    _suggestionDebounce?.cancel();
    _suggestionRequestVersion++;
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

  Future<void> _toggleFollow() async {
    if (_followLoading) return;
    final StoreFollowCallback? onFollowShop = widget.onFollowShop;
    if (onFollowShop == null) {
      _showMessage('Shop following is unavailable right now.', error: true);
      return;
    }

    setState(() => _followLoading = true);
    try {
      final StoreFollowResult result = await onFollowShop(!_isFollowing);
      if (!mounted) return;
      setState(() {
        _isFollowing = result.following;
        if (result.followers != null) {
          _followersLabel = result.followers.toString();
        }
      });
      _showMessage(
        result.following
            ? 'You are now following ${widget.seller.name}.'
            : 'You unfollowed ${widget.seller.name}.',
      );
    } catch (error) {
      _showMessage(
        error.toString().replaceFirst(RegExp(r'^Exception:\s*'), ''),
        error: true,
      );
    } finally {
      if (mounted) setState(() => _followLoading = false);
    }
  }

  Future<void> _claimStoreVoucher(StoreVoucherData voucher) async {
    final int? voucherId = int.tryParse(voucher.id);
    final StoreVoucherClaimCallback? claim = widget.onClaimVoucher;
    if (voucherId == null || claim == null) {
      _showMessage('This voucher cannot be claimed right now.', error: true);
      return;
    }
    if (_claimingVoucherIds.contains(voucherId)) return;

    setState(() => _claimingVoucherIds.add(voucherId));
    try {
      await claim(voucherId);
      if (!mounted) return;
      setState(() => _collectedVoucherIds.add(voucherId));
      _showMessage('Voucher claimed. You can use it at checkout.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) setState(() => _claimingVoucherIds.remove(voucherId));
    }
  }

  String _errorText(Object error) {
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final List<StoreProductData> visibleProducts = _visibleProducts;
    final List<StoreProductData> pageProducts = _pageProducts;

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
                  key: const PageStorageKey<String>('buyer-store-scroll'),
                  controller: _storeScrollController,
                  physics: const AlwaysScrollableScrollPhysics(),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                      sliver: SliverToBoxAdapter(child: _buildSellerHero()),
                    ),

                    if (widget.seller.onVacation)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF4ED),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: const Color(0xFFF2D2BE),
                              ),
                            ),
                            child: const Text(
                              'This seller is on vacation and cannot accept orders right now.',
                              style: TextStyle(
                                color: ShopColors.secondaryText,
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                      sliver: SliverToBoxAdapter(child: _buildSellerDetails()),
                    ),

                    if (widget.onMessageSeller != null)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildMessageSellerButton(),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 16, 14, 0),
                      sliver: SliverToBoxAdapter(child: _buildStoreTabs()),
                    ),

                    if (widget.seller.vouchers.isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                        sliver: SliverToBoxAdapter(
                          child: _buildStoreVouchers(),
                        ),
                      ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 20, 14, 0),
                      sliver: SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _productsSectionKey,
                          child: _buildProductHeader(visibleProducts.length),
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 13, 14, 0),
                      sliver: SliverToBoxAdapter(
                        child: KeyedSubtree(
                          key: _categorySectionKey,
                          child: _buildSearchAndSort(),
                        ),
                      ),
                    ),

                    if (visibleProducts.isEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 18, 14, 110),
                        sliver: SliverToBoxAdapter(
                          child: _buildEmptyProducts(),
                        ),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.fromLTRB(14, 16, 14, 110),
                        sliver: SliverLayoutBuilder(
                          builder: (BuildContext context, constraints) {
                            final double width = constraints.crossAxisExtent;

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
                                    crossAxisCount: columns,
                                    crossAxisSpacing: 10,
                                    mainAxisSpacing: 12,
                                    childAspectRatio: columns == 1
                                        ? 1.55
                                        : 0.59,
                                  ),
                              delegate: SliverChildBuilderDelegate((
                                BuildContext context,
                                int index,
                              ) {
                                final StoreProductData product =
                                    pageProducts[index];

                                return _StoreProductCard(
                                  product: product,
                                  sellerOnVacation: widget.seller.onVacation,
                                  wishlistLoading: _wishlistLoading.contains(
                                    product.id,
                                  ),
                                  onTap: () {
                                    widget.onProductSelected?.call(product);
                                  },
                                  onWishlist: () {
                                    _toggleWishlist(product);
                                  },
                                );
                              }, childCount: pageProducts.length),
                            );
                          },
                        ),
                      ),
                    if (visibleProducts.length > _pageSize)
                      SliverToBoxAdapter(
                        child: _buildPagination(visibleProducts.length),
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
      color: _background,
      padding: const EdgeInsets.fromLTRB(10, 7, 14, 10),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: 'Back',
                onPressed:
                    widget.onBack ?? () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back_rounded),
                color: _text,
              ),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: TextField(
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onChanged: (String value) {
                      setState(() {
                        _query = value;
                        _pageIndex = 0;
                      });
                      _scheduleSearchSuggestions(value);
                    },
                    decoration: InputDecoration(
                      hintText: 'Search in shop',
                      hintStyle: const TextStyle(color: _muted2, fontSize: 13),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: _muted,
                        size: 20,
                      ),
                      suffixIcon: _query.trim().isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear search',
                              onPressed: _clearSearch,
                              icon: const Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: _muted,
                              ),
                            ),
                      filled: true,
                      fillColor: _surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 11,
                      ),
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
                        borderSide: const BorderSide(color: _tan, width: 1.3),
                      ),
                    ),
                  ),
                ),
              ),
              if (_refreshing) ...[
                const SizedBox(width: 9),
                const SizedBox.square(
                  dimension: 19,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _maroon,
                  ),
                ),
              ],
            ],
          ),
          if (_searchSuggestions.isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(46, 5, 0, 0),
              decoration: BoxDecoration(
                color: _surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _border),
                boxShadow: const <BoxShadow>[
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  for (final ProductSearchSuggestion suggestion
                      in _searchSuggestions)
                    ListTile(
                      dense: true,
                      leading: const Icon(
                        Icons.search_rounded,
                        color: _maroon,
                        size: 19,
                      ),
                      title: Text(
                        suggestion.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: _text,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onTap: () => _selectSearchSuggestion(suggestion),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageSellerButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: widget.onMessageSeller,
        icon: const Icon(Icons.chat_bubble_outline_rounded, size: 19),
        label: const Align(
          alignment: Alignment.centerLeft,
          child: Text('Chat with seller'),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _maroon,
          backgroundColor: _surface,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }

  Widget _buildStoreTabs() {
    const List<String> tabs = <String>['Shop', 'Products', 'Categories'];
    return Container(
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          for (int index = 0; index < tabs.length; index++)
            Expanded(
              child: Semantics(
                selected: _selectedStoreTab == index,
                button: true,
                child: InkWell(
                  onTap: () => _selectStoreTab(index),
                  borderRadius: BorderRadius.circular(15),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        Text(
                          tabs[index],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _selectedStoreTab == index
                                ? _maroon
                                : _muted,
                            fontSize: 12.5,
                            fontWeight: _selectedStoreTab == index
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: _selectedStoreTab == index ? 42 : 0,
                          height: 3,
                          decoration: BoxDecoration(
                            color: _tan,
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _selectStoreTab(int index) {
    setState(() {
      _selectedStoreTab = index;
      if (index == 2) _filtersExpanded = true;
    });

    if (index == 0) {
      if (_storeScrollController.hasClients) {
        _storeScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final BuildContext? targetContext =
          (index == 1 ? _productsSectionKey : _categorySectionKey)
              .currentContext;
      if (targetContext != null) {
        Scrollable.ensureVisible(
          targetContext,
          alignment: 0.04,
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }

  Widget _buildSellerHero() {
    final String? coverImageUrl = widget.seller.coverImageUrl?.trim();
    final bool hasCoverImage = coverImageUrl?.isNotEmpty == true;

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[_maroon, _maroon2, _maroonDark],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: _maroon.withValues(alpha: 0.16),
            blurRadius: 28,
            offset: const Offset(0, 13),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (hasCoverImage)
            Positioned.fill(
              child: SizedNetworkImage(
                url: AppConfig.resolveMediaUrl(coverImageUrl),
                iconSize: 0,
              ),
            ),

          if (hasCoverImage)
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[
                      _maroon.withValues(alpha: 0.50),
                      _maroon2.withValues(alpha: 0.60),
                      _maroonDark.withValues(alpha: 0.72),
                    ],
                  ),
                ),
              ),
            ),

          Positioned(
            right: -45,
            top: -55,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),

          Positioned(
            left: -60,
            bottom: -85,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _tan.withValues(alpha: 0.12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(19),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SellerAvatar(seller: widget.seller, size: 70),

                    const SizedBox(width: 13),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'LIKHAE SELLER',
                            style: TextStyle(
                              color: Color(0xFFE8C8B2),
                              fontSize: 10,
                              letterSpacing: 1.4,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            widget.seller.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              height: 1.05,
                              letterSpacing: -0.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),

                          if (widget.seller.verified == true) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(30),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.3),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_rounded,
                                    color: Color(0xFFF0D9C6),
                                    size: 13,
                                  ),
                                  SizedBox(width: 4),
                                  Text(
                                    'Verified seller',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (widget.seller.location?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 6),

                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.location_on_outlined,
                                    color: Color(0xFFE8C8B2),
                                    size: 14,
                                  ),
                                ),

                                const SizedBox(width: 4),

                                Expanded(
                                  child: Text(
                                    widget.seller.location!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Color(0xFFF4DED4),
                                      fontSize: 11.5,
                                      height: 1.35,
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

                if (widget.seller.description?.trim().isNotEmpty == true) ...[
                  const SizedBox(height: 16),

                  Text(
                    widget.seller.description!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFFF4DED4),
                      fontSize: 12,
                      height: 1.55,
                    ),
                  ),
                ],

                const SizedBox(height: 17),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      width: 145,
                      height: 46,
                      child: OutlinedButton.icon(
                        onPressed: _followLoading || widget.onFollowShop == null
                            ? null
                            : _toggleFollow,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white.withValues(
                            alpha: 0.55,
                          ),
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(13),
                          ),
                        ),
                        icon: _followLoading
                            ? const SizedBox.square(
                                dimension: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                _isFollowing
                                    ? Icons.check_rounded
                                    : Icons.add_rounded,
                                size: 18,
                              ),
                        label: Text(
                          _isFollowing ? 'Following' : 'Follow',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
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
    );
  }

  Widget _buildSellerDetails() {
    final int listedProductsCount = _products
        .where(
          (StoreProductData product) =>
              product.isActive && !product.isDraft && !product.isDeleted,
        )
        .length;

    final List<_SellerStat> stats = <_SellerStat>[
      _SellerStat(
        label: 'Rating',
        value: widget.seller.rating?.toStringAsFixed(1) ?? '—',
        icon: Icons.star_rounded,
      ),
      _SellerStat(
        label: 'Followers',
        value: _followersLabel?.trim().isNotEmpty == true
            ? _followersLabel!
            : '—',
        icon: Icons.group_outlined,
      ),
      _SellerStat(
        label: 'Products',
        value: listedProductsCount.toString(),
        icon: Icons.storefront_outlined,
      ),
    ];

    final bool hasJoined = widget.seller.joinedYear?.trim().isNotEmpty == true;

    final bool hasHours =
        widget.seller.businessHours?.trim().isNotEmpty == true;

    if (stats.isEmpty && !hasJoined && !hasHours) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Seller details',
            style: TextStyle(
              color: ShopColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),

          if (stats.isNotEmpty)
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) {
                int columns;

                if (constraints.maxWidth < 340) {
                  if (stats.length == 3) {
                    columns = 3;
                  } else if (stats.length >= 2) {
                    columns = 2;
                  } else {
                    columns = 1;
                  }
                } else {
                  columns = stats.length;
                }

                if (columns > 4) {
                  columns = 4;
                }

                const double spacing = 8;

                final double width =
                    (constraints.maxWidth - ((columns - 1) * spacing)) /
                    columns;

                return Wrap(
                  spacing: spacing,
                  runSpacing: spacing,
                  children: stats.map((_SellerStat stat) {
                    return SizedBox(
                      width: width,
                      child: _SellerStatCard(stat: stat),
                    );
                  }).toList(),
                );
              },
            ),

          if (stats.isNotEmpty && (hasJoined || hasHours))
            const SizedBox(height: 14),

          if (hasJoined)
            _SellerInfoRow(
              icon: Icons.calendar_month_outlined,
              label: 'Joined',
              value: widget.seller.joinedYear!,
            ),

          if (hasJoined && hasHours) const SizedBox(height: 10),

          if (hasHours)
            _SellerInfoRow(
              icon: Icons.access_time_rounded,
              label: 'Business Hours',
              value: widget.seller.businessHours!,
            ),
        ],
      ),
    );
  }

  Widget _buildStoreVouchers() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: _softStrong,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.confirmation_number_outlined,
                color: _maroon,
                size: 18,
              ),
            ),
            const SizedBox(width: 9),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Shop vouchers',
                    style: TextStyle(
                      color: _text,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Claim a discount or use one you have collected',
                    style: TextStyle(color: _muted, fontSize: 10.5),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        SizedBox(
          height: 122,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: widget.seller.vouchers.length,
            separatorBuilder: (BuildContext context, int index) =>
                const SizedBox(width: 10),
            itemBuilder: (BuildContext context, int index) {
              final StoreVoucherData voucher = widget.seller.vouchers[index];
              final int? voucherId = int.tryParse(voucher.id);
              final bool isCollected =
                  voucher.isCollected ||
                  (voucherId != null &&
                      _collectedVoucherIds.contains(voucherId));
              final bool isClaiming =
                  voucherId != null && _claimingVoucherIds.contains(voucherId);
              final String conditions =
                  '${voucher.minimumOrderAmount > 0 ? 'Min. ₱${voucher.minimumOrderAmount.toStringAsFixed(2)}' : 'No minimum spend'}${voucher.expires.isNotEmpty && voucher.expires.toLowerCase() != 'no expiry' ? ' · Until ${voucher.expires}' : ''}';
              return Container(
                width: 286,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: <Color>[ShopColors.surface, ShopColors.accentSoft],
                  ),
                  borderRadius: BorderRadius.circular(17),
                  border: Border.all(color: _border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            voucher.benefitLabel,
                            style: const TextStyle(
                              color: _maroon,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            voucher.name.isEmpty
                                ? 'Code ${voucher.code}'
                                : voucher.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _text,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            conditions,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: _muted, fontSize: 10),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if ((isCollected && widget.onUseVoucher != null) ||
                        (!isCollected && widget.onClaimVoucher != null))
                      SizedBox(
                        height: 38,
                        child: FilledButton(
                          onPressed: isClaiming
                              ? null
                              : () {
                                  if (isCollected) {
                                    widget.onUseVoucher?.call(voucher);
                                  } else {
                                    unawaited(_claimStoreVoucher(voucher));
                                  }
                                },
                          style: FilledButton.styleFrom(
                            backgroundColor: _maroon,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(11),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          child: isClaiming
                              ? const SizedBox(
                                  width: 15,
                                  height: 15,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(isCollected ? 'Use' : 'Claim'),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductHeader(int visibleCount) {
    final bool filtering =
        _query.trim().isNotEmpty ||
        _selectedCategory != null ||
        _minimumPrice != null ||
        _maximumPrice != null ||
        _minimumRating != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PRODUCTS FROM THIS STORE',
                style: TextStyle(
                  color: _maroon,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 5),

              const Text(
                'Browse Products',
                style: TextStyle(
                  color: _text,
                  fontSize: 24,
                  height: 1.05,
                  letterSpacing: -0.6,
                  fontWeight: FontWeight.w800,
                ),
              ),

              const SizedBox(height: 6),

              Text(
                filtering
                    ? '$visibleCount of ${_products.where((StoreProductData p) => p.isActive && !p.isDraft && !p.isDeleted).length} products'
                    : '${_products.where((StoreProductData p) => p.isActive && !p.isDraft && !p.isDeleted).length} products from this seller',
                style: const TextStyle(color: _muted, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSearchAndSort() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_storeCategories.isNotEmpty) _buildCategoryFilters(),

        const SizedBox(height: 9),

        SizedBox(
          width: double.infinity,
          child: DropdownButtonFormField<StoreProductSort>(
            initialValue: _sort,
            isExpanded: true,
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.sort_rounded,
                color: _muted,
                size: 19,
              ),
              filled: true,
              fillColor: _surface,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 11,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: _tan),
              ),
            ),
            items: StoreProductSort.values.map((StoreProductSort sort) {
              return DropdownMenuItem<StoreProductSort>(
                value: sort,
                child: Text(
                  sort.label,
                  style: const TextStyle(
                    color: _text,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              );
            }).toList(),
            onChanged: (StoreProductSort? value) {
              if (value == null) {
                return;
              }

              setState(() {
                _sort = value;
                _pageIndex = 0;
              });
            },
          ),
        ),

        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () =>
                setState(() => _filtersExpanded = !_filtersExpanded),
            icon: Icon(
              _filtersExpanded ? Icons.tune_rounded : Icons.filter_list_rounded,
              size: 17,
            ),
            label: Text(
              _filtersExpanded
                  ? 'Hide filters'
                  : _activeFilterCount == 0
                  ? 'Filters'
                  : 'Filters ($_activeFilterCount)',
            ),
          ),
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _filtersExpanded
              ? Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Expanded(
                            child: Text(
                              'Refine products',
                              style: TextStyle(
                                color: _text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _activeFilterCount == 0
                                ? null
                                : () => setState(() {
                                    _selectedCategory = null;
                                    _minimumPrice = null;
                                    _maximumPrice = null;
                                    _minimumRating = null;
                                    _pageIndex = 0;
                                  }),
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                      PriceRangeFilter(
                        minimum: _priceMinimum,
                        maximum: _priceMaximum,
                        selectedMinimum: _minimumPrice ?? _priceMinimum,
                        selectedMaximum: _maximumPrice ?? _priceMaximum,
                        onChanged: (RangeValues range) => setState(() {
                          _minimumPrice = range.start;
                          _maximumPrice = range.end;
                          _pageIndex = 0;
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue:
                            _minimumRating?.toInt().toString() ?? 'any',
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Minimum rating',
                          prefixIcon: const Icon(Icons.star_outline_rounded),
                          isDense: true,
                          filled: true,
                          fillColor: ShopColors.canvas,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: _border),
                          ),
                        ),
                        items: const <DropdownMenuItem<String>>[
                          DropdownMenuItem(
                            value: 'any',
                            child: Text('Any rating'),
                          ),
                          DropdownMenuItem(
                            value: '3',
                            child: Text('3 stars and up'),
                          ),
                          DropdownMenuItem(
                            value: '4',
                            child: Text('4 stars and up'),
                          ),
                          DropdownMenuItem(value: '5', child: Text('5 stars')),
                        ],
                        onChanged: (String? value) => setState(() {
                          _minimumRating = value == null || value == 'any'
                              ? null
                              : double.tryParse(value);
                          _pageIndex = 0;
                        }),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  int get _activeFilterCount => <bool>[
    _selectedCategory != null,
    _minimumPrice != null || _maximumPrice != null,
    _minimumRating != null,
  ].where((bool active) => active).length;

  Widget _buildCategoryFilters() {
    final List<String> categories = _storeCategories;
    return SizedBox(
      width: double.infinity,
      child: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Categories',
              style: TextStyle(
                color: _text,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _categoryChip('All', null),
                  for (final String category in categories)
                    _categoryChip(category, category),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _categoryChip(String label, String? category) {
    final bool selected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.only(right: 7),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        side: BorderSide(color: selected ? _maroon : _border),
        backgroundColor: _surface,
        selectedColor: ShopColors.accentSoft,
        labelStyle: TextStyle(
          color: selected ? _maroon : _muted,
          fontSize: 11.5,
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
        onSelected: (_) => setState(() {
          _selectedCategory = category;
          _pageIndex = 0;
        }),
      ),
    );
  }

  Widget _buildPagination(int itemCount) {
    final int pageCount = (itemCount / _pageSize).ceil();
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 28),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          OutlinedButton.icon(
            onPressed: _pageIndex == 0
                ? null
                : () => setState(() => _pageIndex--),
            icon: const Icon(Icons.chevron_left_rounded),
            label: const Text('Previous'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Page ${_pageIndex + 1} of $pageCount',
              style: const TextStyle(color: _muted, fontSize: 10),
            ),
          ),
          OutlinedButton.icon(
            onPressed: _pageIndex >= pageCount - 1
                ? null
                : () => setState(() => _pageIndex++),
            icon: const Icon(Icons.chevron_right_rounded),
            label: const Text('Next'),
            iconAlignment: IconAlignment.end,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyProducts() {
    final bool searching = _query.trim().isNotEmpty;
    final bool filtering =
        searching ||
        _selectedCategory != null ||
        _minimumPrice != null ||
        _maximumPrice != null ||
        _minimumRating != null;
    final String? suggestion = searching
        ? closestProductSuggestion(
            _query,
            _products.map((StoreProductData product) => product.name),
          )
        : null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 45),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: const BoxDecoration(
              color: _softStrong,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              filtering ? Icons.search_off_rounded : Icons.inventory_2_outlined,
              color: _maroon,
              size: 28,
            ),
          ),

          const SizedBox(height: 15),

          Text(
            filtering ? 'No matching products' : 'No products available',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _text,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            filtering
                ? 'Try another search or adjust your category and filters.'
                : 'This seller does not have products available in this store right now.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 10, height: 1.45),
          ),

          if (suggestion != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.text = suggestion;
                setState(() {
                  _query = suggestion;
                  _pageIndex = 0;
                });
              },
              child: Text('Did you mean “$suggestion”?'),
            ),
          ],

          if (filtering) ...[
            const SizedBox(height: 15),

            OutlinedButton(
              onPressed: _clearProductFilters,
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _tan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Text(
                'Clear search and filters',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SellerAvatar extends StatelessWidget {
  final StoreSellerData seller;

  final double size;

  const _SellerAvatar({required this.seller, required this.size});

  @override
  Widget build(BuildContext context) {
    final String? url = seller.avatarUrl?.trim();

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ShopColors.accentSoft,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: ShopColors.accentDark.withValues(alpha: 0.16),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: url == null || url.isEmpty
          ? _SellerInitials(initials: seller.initials)
          : SizedNetworkImage(
              url: AppConfig.resolveMediaUrl(url),
              fit: BoxFit.cover,
              placeholder: const Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ShopColors.accent,
                  ),
                ),
              ),
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return _SellerInitials(initials: seller.initials);
                  },
            ),
    );
  }
}

class _SellerInitials extends StatelessWidget {
  final String initials;

  const _SellerInitials({required this.initials});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: ShopColors.accentSoft,
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          color: ShopColors.accent,
          fontSize: 18,
          fontWeight: FontWeight.w800,
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

class _SellerStatCard extends StatelessWidget {
  final _SellerStat stat;

  const _SellerStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 11),
      decoration: BoxDecoration(
        color: ShopColors.soft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(
            stat.icon,
            color: stat.label == 'Rating'
                ? const Color(0xFFC88418)
                : ShopColors.accent,
            size: 18,
          ),

          const SizedBox(height: 5),

          Text(
            stat.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            stat.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: ShopColors.muted, fontSize: 10),
          ),
        ],
      ),
    );
  }
}

class _SellerInfoRow extends StatelessWidget {
  final IconData icon;

  final String label;
  final String value;

  const _SellerInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: ShopColors.accentSoft,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Icon(icon, color: ShopColors.accent, size: 16),
        ),

        const SizedBox(width: 9),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: ShopColors.muted,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 2),

              Text(
                value,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 12.5,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StoreProductCard extends StatelessWidget {
  final StoreProductData product;
  final bool sellerOnVacation;

  final bool wishlistLoading;

  final VoidCallback onTap;
  final VoidCallback onWishlist;

  const _StoreProductCard({
    required this.product,
    required this.sellerOnVacation,
    required this.wishlistLoading,
    required this.onTap,
    required this.onWishlist,
  });

  @override
  Widget build(BuildContext context) {
    final double? discount = product.discountPercentage;

    return Material(
      color: ShopColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: ShopColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Container(
                      color: ShopColors.soft,
                      child: _StoreProductImage(url: product.imageUrl),
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
                            color: ShopColors.accent,
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
                        color: Colors.white.withValues(alpha: 0.94),
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: wishlistLoading ? null : onWishlist,
                          customBorder: const CircleBorder(),
                          child: SizedBox(
                            width: 42,
                            height: 42,
                            child: wishlistLoading
                                ? const Padding(
                                    padding: EdgeInsets.all(9),
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.8,
                                      color: ShopColors.accent,
                                    ),
                                  )
                                : Icon(
                                    WishlistService.isWishlisted(product.id)
                                        ? Icons.favorite_rounded
                                        : Icons.favorite_border_rounded,
                                    size: 18,
                                    color: ShopColors.accent,
                                  ),
                          ),
                        ),
                      ),
                    ),

                    /*
                     * Unknown stock must NOT look like
                     * zero stock.
                     */
                    if (product.isOutOfStock || sellerOnVacation)
                      Positioned.fill(
                        child: Container(
                          color: Colors.black.withValues(alpha: 0.45),
                          alignment: Alignment.center,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.62),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              sellerOnVacation
                                  ? 'SELLER ON VACATION'
                                  : 'OUT OF STOCK',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                letterSpacing: 0.7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (product.category?.trim().isNotEmpty == true) ...[
                      Text(
                        product.category!.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.secondaryText,
                          fontSize: 10,
                          letterSpacing: 0.7,
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
                        color: ShopColors.text,
                        fontSize: 14,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(height: 7),

                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 4,
                      runSpacing: 2,
                      children: [
                        Text(
                          _formatPrice(product.price),
                          style: const TextStyle(
                            color: ShopColors.accent,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        if (product.originalPrice != null &&
                            product.originalPrice! > product.price)
                          Text(
                            _formatPrice(product.originalPrice!),
                            style: const TextStyle(
                              color: ShopColors.faint,
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
                            size: 14,
                          ),

                          const SizedBox(width: 2),

                          Text(
                            product.rating!.toStringAsFixed(1),
                            style: const TextStyle(
                              color: ShopColors.text,
                              fontSize: 10.5,
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
                              color: ShopColors.muted,
                              fontSize: 10.5,
                            ),
                          ),
                        ),

                        if (product.stock != null && product.stock! > 0)
                          Text(
                            '${product.stock} left',
                            style: const TextStyle(
                              color: ShopColors.muted,
                              fontSize: 10,
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

  static String _formatPrice(double value) {
    return '₱${value.toStringAsFixed(2)}';
  }
}

class _StoreProductImage extends StatelessWidget {
  final String? url;
  const _StoreProductImage({required this.url});
  @override
  Widget build(BuildContext context) {
    final value = url?.trim() ?? '';
    if (value.isEmpty)
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: ShopColors.faint,
          size: 34,
        ),
      );
    return SizedNetworkImage(
      url: AppConfig.resolveMediaUrl(value),
      iconSize: 34,
    );
  }
}

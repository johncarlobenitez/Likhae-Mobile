import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../core/api/api_client.dart';
import '../core/config/app_config.dart';
import '../core/utils/api_value_parsers.dart';
import '../features/buyer/cart/cart_screen.dart';
import '../features/buyer/checkout/checkout_screen.dart';
import '../features/buyer/messages/message_models.dart';
import '../features/buyer/messages/messages_screen.dart';
import '../features/buyer/notifications/notifications_screen.dart';
import '../features/buyer/orders/orders_screen.dart';
import '../features/buyer/profile/account_screen.dart';
import '../features/buyer/rewards/rewards_screen.dart';
import '../features/buyer/wishlist/wishlist_screen.dart';
import 'realtime_service.dart';
import 'auth_service.dart';
import '../shared/widgets/buyer_navigation_badges.dart';

class _BuyerProductData {
  final int id;
  final String name;
  final String? slug;
  final String? category;
  final String? seller;
  final int? sellerUserId;
  final String? imageUrl;
  final double price;
  final double? originalPrice;
  final double? rating;
  final int reviewCount;
  final int soldCount;
  final int? stock;
  final bool isActive;
  final bool isDraft;
  final bool isDeleted;
  final bool sellerOnVacation;

  const _BuyerProductData({
    required this.id,
    required this.name,
    required this.price,
    required this.reviewCount,
    required this.soldCount,
    this.slug,
    this.category,
    this.seller,
    this.sellerUserId,
    this.imageUrl,
    this.originalPrice,
    this.rating,
    this.stock,
    this.isActive = true,
    this.isDraft = false,
    this.isDeleted = false,
    this.sellerOnVacation = false,
  });
}

class BuyerMobileService {
  static void _refreshNavigationBadges() =>
      unawaited(BuyerNavigationBadges.instance.refresh(force: true));

  static Future<List<dynamic>> _getRows(
    String endpoint, {
    int? maxPages,
    Map<String, dynamic> queryParameters = const <String, dynamic>{},
  }) async {
    final List<dynamic> allRows = <dynamic>[];
    int page = 1;
    int lastPage = 1;
    do {
      final Response<dynamic> response = await ApiClient.get(
        AppConfig.resolveApiUrl(endpoint),
        queryParameters: <String, dynamic>{
          'page': page,
          'per_page': 50,
          ...queryParameters,
        },
      );
      final Map<String, dynamic> payload = _requirePayload(response);
      final dynamic rows = payload['data'];
      if (rows is! List) {
        throw const FormatException(
          'Invalid list response from the buyer API.',
        );
      }
      allRows.addAll(rows);
      final dynamic meta = payload['meta'];
      if (meta is Map && meta['last_page'] != null) {
        lastPage = int.tryParse(meta['last_page'].toString()) ?? page;
      }
      page++;
    } while (page <= lastPage && (maxPages == null || page <= maxPages));
    return allRows;
  }

  static Map<String, dynamic> _requirePayload(Response<dynamic> response) {
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      final dynamic body = response.data;
      if (body is Map && body['errors'] is Map) {
        final List<String> validationMessages = <String>[];
        for (final dynamic messages in (body['errors'] as Map).values) {
          if (messages is Iterable) {
            validationMessages.addAll(
              messages.map((dynamic message) => message.toString()),
            );
          } else if (messages != null) {
            validationMessages.add(messages.toString());
          }
        }
        if (validationMessages.isNotEmpty) {
          throw Exception(validationMessages.join('\n'));
        }
      }
      final String message = body is Map && body['message'] != null
          ? body['message'].toString()
          : 'Buyer API request failed (HTTP $statusCode).';
      throw Exception(message);
    }
    if (response.data is! Map) {
      throw const FormatException('Invalid response from the buyer API.');
    }
    return Map<String, dynamic>.from(response.data as Map);
  }

  static Future<List<CartItemData>> fetchCart() async {
    return (await _getRows('buyer/cart'))
        .whereType<Map>()
        .map((Map item) => _cartItem(Map<String, dynamic>.from(item)))
        .toList(growable: false);
  }

  static Future<CartItemData> addCartItem({
    required int productId,
    required int productVariantId,
    required int quantity,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/cart'),
      <String, dynamic>{
        'product_id': productId,
        'product_variant_id': productVariantId,
        'quantity': quantity,
      },
    );
    final dynamic item = _requirePayload(response)['data'];
    if (item is! Map) {
      throw const FormatException(
        'The server did not return the saved cart item.',
      );
    }
    _refreshNavigationBadges();
    return _cartItem(Map<String, dynamic>.from(item));
  }

  static Future<void> updateCartQuantity(
    CartItemData item,
    int quantity,
  ) async {
    final Response<dynamic> response = await ApiClient.patch(
      AppConfig.resolveApiUrl(
        'buyer/cart/items/${Uri.encodeComponent(item.id)}',
      ),
      <String, dynamic>{'quantity': quantity},
    );
    _requirePayload(response);
    _refreshNavigationBadges();
  }

  static Future<void> removeCartItem(CartItemData item) async {
    final Response<dynamic> response = await ApiClient.delete(
      AppConfig.resolveApiUrl(
        'buyer/cart/items/${Uri.encodeComponent(item.id)}',
      ),
      <String, dynamic>{},
    );
    _requirePayload(response);
    _refreshNavigationBadges();
  }

  static Future<void> setDefaultBuyerAddress(BuyerAddressData address) async {
    final Response<dynamic> response = await ApiClient.patch(
      AppConfig.resolveApiUrl(
        'buyer/addresses/${Uri.encodeComponent(address.id)}/default',
      ),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<bool> toggleWishlist(int productId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/wishlist/toggle'),
      <String, dynamic>{'product_id': productId},
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException(
        'Invalid wishlist response from the buyer API.',
      );
    }
    return parseApiBool(data['wishlisted'], defaultValue: true);
  }

  static Future<List<WishlistProduct>> fetchWishlist() async {
    final Map<int, WishlistProduct> products = <int, WishlistProduct>{};
    for (final dynamic item in await _getRows('buyer/wishlist')) {
      if (item is! Map) continue;
      final Map<String, dynamic> row = Map<String, dynamic>.from(item);
      final dynamic rawProduct = row['product'];
      final DateTime? wishlistedAt = DateTime.tryParse(
        (row['wishlisted_at'] ?? '').toString(),
      );
      WishlistProduct? product;
      if (rawProduct is Map) {
        final Map<String, dynamic> productRow = Map<String, dynamic>.from(
          rawProduct,
        );
        final _BuyerProductData data = _buyerProductData(productRow);
        final int id = data.id > 0
            ? data.id
            : int.tryParse((row['product_id'] ?? '').toString()) ?? 0;
        if (id > 0) {
          product = WishlistProduct(
            id: id,
            name: data.name,
            slug: data.slug,
            category: data.category,
            sellerName: data.seller,
            sellerUserId: data.sellerUserId,
            imageUrl: data.imageUrl,
            price: data.price,
            originalPrice: data.originalPrice,
            rating: data.rating,
            reviewCount: data.reviewCount,
            soldCount: data.soldCount,
            stock: data.stock,
            isActive: data.isActive,
            isDraft: data.isDraft,
            isDeleted: data.isDeleted,
            sellerOnVacation: data.sellerOnVacation,
            wishlistAddedAt: wishlistedAt,
          );
        }
      } else {
        final int id = int.tryParse((row['product_id'] ?? '').toString()) ?? 0;
        if (id > 0) {
          product = WishlistProduct(
            id: id,
            name: (row['product_name'] ?? 'Unavailable product').toString(),
            price: _asDouble(row['price']),
            stock: 0,
            isActive: false,
            isDeleted: true,
            wishlistAddedAt: wishlistedAt,
          );
        }
      }
      if (product != null) products[product.id] = product;
    }
    return products.values.toList(growable: false);
  }

  static _BuyerProductData _buyerProductData(Map<String, dynamic> row) {
    final dynamic image = row['primary_image'];
    final Map<String, dynamic>? primaryImage = image is Map
        ? Map<String, dynamic>.from(image)
        : null;
    final dynamic categoryRaw = row['category'];
    final Map<String, dynamic>? category = categoryRaw is Map
        ? Map<String, dynamic>.from(categoryRaw)
        : null;
    final dynamic sellerRaw = row['seller'];
    final Map<String, dynamic>? seller = sellerRaw is Map
        ? Map<String, dynamic>.from(sellerRaw)
        : null;
    return _BuyerProductData(
      id: int.tryParse((row['id'] ?? '').toString()) ?? 0,
      name: (row['name'] ?? 'Product').toString(),
      slug: row['slug']?.toString(),
      category: category?['name']?.toString(),
      seller: seller?['business_name']?.toString(),
      sellerUserId: int.tryParse((seller?['user_id'] ?? '').toString()),
      imageUrl: AppConfig.resolveMediaUrl(
        (primaryImage?['url'] ?? primaryImage?['file_path'])?.toString(),
      ),
      price: _asDouble(row['min_price']),
      originalPrice: row['original_price'] == null
          ? null
          : _asDouble(row['original_price']),
      rating: row['rating'] == null ? null : _asDouble(row['rating']),
      reviewCount: int.tryParse((row['reviews'] ?? 0).toString()) ?? 0,
      soldCount: int.tryParse((row['sold'] ?? 0).toString()) ?? 0,
      stock: int.tryParse(row['stock']?.toString() ?? ''),
      isActive:
          parseApiBool(
            row['is_active'] ??
                row['is_available'] ??
                row['active'] ??
                row['is_published'],
            defaultValue: !<String>{
              'inactive',
              'unpublished',
              'draft',
              'deleted',
              'disabled',
            }.contains((row['status'] ?? '').toString().toLowerCase()),
          ) &&
          parseApiBool(seller?['store_visibility'], defaultValue: true) &&
          parseApiBool(row['is_visible'], defaultValue: true),
      isDraft:
          parseApiBool(row['is_draft'], defaultValue: false) ||
          (row['status'] ?? '').toString().toLowerCase() == 'draft',
      isDeleted:
          parseApiBool(
            row['is_deleted'] ?? row['deleted'],
            defaultValue: false,
          ) ||
          row['deleted_at'] != null ||
          (row['status'] ?? '').toString().toLowerCase() == 'deleted',
      sellerOnVacation: parseApiBool(
        seller?['is_on_vacation'] ??
            seller?['is_vacation_mode'] ??
            seller?['vacation_mode'] ??
            row['seller_on_vacation'],
        defaultValue: false,
      ),
    );
  }

  static Future<RewardsData> fetchRewards() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/rewards'),
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException(
        'Invalid rewards response from the buyer API.',
      );
    }
    final Map<String, dynamic> row = Map<String, dynamic>.from(data);
    List<T> mapRows<T>(dynamic raw, T Function(Map<String, dynamic>) map) {
      if (raw is! List) {
        throw const FormatException('Invalid rewards list in API response.');
      }
      return raw
          .whereType<Map>()
          .map((Map item) => map(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    return RewardsData(
      activeVouchers: mapRows<RewardVoucherData>(
        row['active_vouchers'],
        (Map<String, dynamic> item) => RewardVoucherData(
          icon: (item['icon'] ?? '').toString(),
          status: (item['status'] ?? '').toString(),
          value: (item['value'] ?? '').toString(),
          condition: (item['condition'] ?? '').toString(),
          code: (item['code'] ?? '').toString(),
          expires: (item['expires'] ?? '').toString(),
          campaignName: item['campaign_name']?.toString(),
          sellerName: item['seller_name']?.toString(),
          canUse: item.containsKey('can_use') ? item['can_use'] == true : null,
          sellerId: int.tryParse((item['seller_id'] ?? '').toString()),
          voucherId: int.tryParse(
            (item['voucher_id'] ?? item['id'] ?? '').toString(),
          ),
          voucherType: (item['voucher_type'] ?? 'seller').toString(),
          isCollected: item['collected'] == true,
          canClaim: item['claimable'] == true,
          unavailableReason: item['unavailable_reason']?.toString(),
          discountType: item['discount_type']?.toString(),
          discountAmount: _asDouble(item['discount_value']),
          minimumOrderAmount: _asDouble(item['minimum_order_amount']),
          maximumDiscountAmount: item['maximum_discount_amount'] == null
              ? null
              : _asDouble(item['maximum_discount_amount']),
        ),
      ),
      voucherHistory: mapRows<VoucherHistoryData>(
        row['voucher_history'],
        (Map<String, dynamic> item) => VoucherHistoryData(
          voucher: (item['voucher'] ?? '').toString(),
          benefit: (item['benefit'] ?? '').toString(),
          order: (item['order'] ?? '').toString(),
          status: (item['status'] ?? '').toString(),
        ),
      ),
      pointsBalance: int.tryParse((row['points_balance'] ?? 0).toString()) ?? 0,
      pointActivities: mapRows<PointsActivityData>(
        row['point_activities'],
        (Map<String, dynamic> item) => PointsActivityData(
          label: (item['label'] ?? '').toString(),
          date: (item['date'] ?? '').toString(),
          amount: (item['amount'] ?? '').toString(),
          negative: item['negative'] == true,
        ),
      ),
      availableCashback: _asDouble(row['available_cashback']),
      pendingCashback: _asDouble(row['pending_cashback']),
      cashbackActivities: mapRows<CashbackActivityData>(
        row['cashback_activities'],
        (Map<String, dynamic> item) => CashbackActivityData(
          order: (item['order'] ?? '').toString(),
          type: (item['type'] ?? '').toString(),
          amount: (item['amount'] ?? '').toString(),
          date: (item['date'] ?? '').toString(),
        ),
      ),
      pointsPerCompletedOrder:
          int.tryParse((row['points_per_completed_order'] ?? 50).toString()) ??
          50,
      pointsPerReview:
          int.tryParse((row['points_per_review'] ?? 20).toString()) ?? 20,
      minimumPointsRedemption:
          int.tryParse((row['minimum_points_redemption'] ?? 100).toString()) ??
          100,
      pointsPerPeso:
          int.tryParse((row['points_per_peso'] ?? 100).toString()) ?? 100,
      cashbackRate: _asDouble(row['cashback_rate']),
    );
  }

  static Future<BuyerAddressData> createBuyerAddress(
    CreateBuyerAddressRequest request,
  ) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/addresses'),
      <String, dynamic>{
        'label': request.label,
        'recipient_name': request.recipientName,
        'contact_number': request.contactNumber,
        'region_code': request.regionCode ?? _locationCode(request.region),
        'region_name': request.region,
        'province_name': request.province,
        'province_code':
            request.provinceCode ?? _locationCode(request.province),
        'municipality_name': request.municipality,
        'municipality_code':
            request.municipalityCode ?? _locationCode(request.municipality),
        'barangay_name': request.barangay,
        'barangay_code':
            request.barangayCode ?? _locationCode(request.barangay),
        'postal_code': request.postalCode,
        'house_number': request.houseNumber,
        'street_address': request.street,
        'landmark': request.landmark,
        if (request.latitude != null) 'latitude': request.latitude,
        if (request.longitude != null) 'longitude': request.longitude,
        'is_default': request.isDefault,
      },
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException(
        'The server did not return the saved address.',
      );
    }
    final Map<String, dynamic> row = Map<String, dynamic>.from(data);
    return BuyerAddressData(
      id: (row['id'] ?? '').toString(),
      label: (row['label'] ?? 'Address').toString(),
      recipientName: (row['recipient_name'] ?? '').toString(),
      contactNumber: (row['contact_number'] ?? '').toString(),
      houseNumber: row['house_number']?.toString(),
      street: row['street_address']?.toString(),
      barangay: row['barangay_name']?.toString(),
      municipality: row['municipality_name']?.toString(),
      province: row['province_name']?.toString(),
      region: row['region_name']?.toString(),
      regionCode: row['region_code']?.toString(),
      provinceCode: row['province_code']?.toString(),
      municipalityCode: row['municipality_code']?.toString(),
      barangayCode: row['barangay_code']?.toString(),
      postalCode: row['postal_code']?.toString(),
      landmark: row['landmark']?.toString(),
      latitude: _asDouble(row['latitude']),
      longitude: _asDouble(row['longitude']),
      isDefault: row['is_default'] == true,
      formattedAddress: row['formatted_address']?.toString(),
    );
  }

  static String _locationCode(String value) {
    final String cleaned = value.trim().toUpperCase();
    if (cleaned.isEmpty) {
      throw const FormatException(
        'Enter a province, municipality/city, and barangay for the address.',
      );
    }
    return cleaned
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
  }

  static Future<Map<String, dynamic>> placeOrder({
    required List<int> cartItemIds,
    required int addressId,
    required String paymentMethod,
    required String recipientName,
    required String contactNumber,
    Map<int, String> voucherCodes = const <int, String>{},
    String? platformVoucherCode,
    String? shippingVoucherCode,
    Map<int, String> sellerNotes = const <int, String>{},
    List<int> protectionItemIds = const <int>[],
    int? logisticsCenterId,
    int rewardPoints = 0,
    String? checkoutAttemptKey,
    Map<String, dynamic>? priceSnapshot,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/checkout'),
      <String, dynamic>{
        'cart_item_ids': cartItemIds,
        'address_id': addressId,
        'recipient_name': recipientName.trim(),
        'contact_number': contactNumber.trim(),
        'payment_method': paymentMethod.toUpperCase(),
        'checkout_attempt_key': checkoutAttemptKey,
        if (logisticsCenterId != null) 'logistics_center_id': logisticsCenterId,
        if (priceSnapshot != null) 'expected_price_snapshot': priceSnapshot,
        if (rewardPoints > 0) 'reward_points': rewardPoints,
        if (sellerNotes.isNotEmpty)
          'seller_notes': sellerNotes.map(
            (int sellerId, String note) =>
                MapEntry<String, String>(sellerId.toString(), note),
          ),
        if (voucherCodes.isNotEmpty ||
            platformVoucherCode?.trim().isNotEmpty == true ||
            shippingVoucherCode?.trim().isNotEmpty == true)
          'voucher_codes': <String, dynamic>{
            'seller': voucherCodes.map(
              (int sellerId, String code) =>
                  MapEntry<String, String>(sellerId.toString(), code),
            ),
            'platform': platformVoucherCode?.trim() ?? '',
            'shipping': shippingVoucherCode?.trim() ?? '',
          },
        if (protectionItemIds.isNotEmpty)
          'protection_item_ids': protectionItemIds,
      },
    );
    final dynamic order = _requirePayload(response)['data'];
    if (order is! Map) {
      throw const FormatException(
        'The server did not return the placed order.',
      );
    }
    _refreshNavigationBadges();
    return Map<String, dynamic>.from(order);
  }

  static Future<Map<String, dynamic>> previewCheckout({
    required List<int> cartItemIds,
    required int addressId,
    Map<int, String> voucherCodes = const <int, String>{},
    String? platformVoucherCode,
    String? shippingVoucherCode,
    List<int> protectionItemIds = const <int>[],
    int? logisticsCenterId,
    int rewardPoints = 0,
    bool cartPreview = false,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        cartPreview ? 'buyer/cart/preview' : 'buyer/checkout/preview',
      ),
      <String, dynamic>{
        'cart_item_ids': cartItemIds,
        'address_id': addressId,
        if (logisticsCenterId != null) 'logistics_center_id': logisticsCenterId,
        'voucher_codes': <String, dynamic>{
          'seller': voucherCodes.map(
            (int sellerId, String code) =>
                MapEntry<String, String>(sellerId.toString(), code),
          ),
          'platform': platformVoucherCode?.trim() ?? '',
          'shipping': shippingVoucherCode?.trim() ?? '',
        },
        'protection_item_ids': protectionItemIds,
        'reward_points': rewardPoints,
      },
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException(
        'The server did not return a checkout quote.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> fetchCheckoutOptions() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/checkout/options'),
      refresh: true,
    );
    return _requirePayload(response);
  }

  static Future<List<CheckoutAddressData>> fetchCheckoutAddresses() async {
    return (await _getRows('buyer/addresses'))
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          return CheckoutAddressData.fromJson(<String, dynamic>{
            ...row,
            'line1': <dynamic>[row['house_number'], row['street_address']]
                .where(
                  (dynamic part) => part != null && part.toString().isNotEmpty,
                )
                .join(' '),
            'province': row['province_name'],
            'city': row['municipality_name'],
            'barangay': row['barangay_name'],
          });
        })
        .toList(growable: false);
  }

  static Future<List<BuyerOrderData>> fetchOrders() async {
    return (await _getRows('buyer/orders'))
        .whereType<Map>()
        .map(
          (Map item) => BuyerOrderData.fromApi(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
  }

  static Future<BuyerOrderData> fetchOrder(String orderReference) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(orderReference)}',
      ),
    );
    final dynamic responseData = _requirePayload(response)['data'];
    final dynamic orderData = responseData is Map
        ? responseData['order'] ?? responseData
        : null;
    if (orderData is! Map) {
      throw const FormatException('Invalid order response from the buyer API.');
    }
    return BuyerOrderData.fromApi(Map<String, dynamic>.from(orderData));
  }

  static Future<BuyerOrderLocation?> fetchRiderLocation(
    String orderId, {
    String? shipmentId,
  }) async {
    return (await fetchRiderSnapshot(orderId, shipmentId: shipmentId)).location;
  }

  static Future<BuyerRiderSnapshot> fetchRiderSnapshot(
    String orderId, {
    String? shipmentId,
  }) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(orderId)}/live-location',
      ),
      queryParameters: shipmentId == null || shipmentId.trim().isEmpty
          ? null
          : <String, dynamic>{'shipment_id': shipmentId},
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException('Invalid rider location response.');
    }
    final dynamic rawRider = data['rider'] ?? data['rider_info'];
    BuyerRiderInfo? rider;
    if (rawRider is Map) {
      final BuyerRiderInfo parsedRider = BuyerRiderInfo.fromApi(
        Map<String, dynamic>.from(rawRider),
      );
      if (parsedRider.hasVisibleInfo) rider = parsedRider;
    }

    final dynamic location = data['rider_location'];
    if (location == null) {
      return BuyerRiderSnapshot(rider: rider);
    }
    if (location is! Map) {
      throw const FormatException(
        'Invalid rider location in buyer API response.',
      );
    }
    final double? latitude = double.tryParse(
      (location['latitude'] ?? '').toString(),
    );
    final double? longitude = double.tryParse(
      (location['longitude'] ?? '').toString(),
    );
    final BuyerOrderLocation? riderLocation =
        latitude == null || longitude == null
        ? null
        : BuyerOrderLocation(
            latitude: latitude,
            longitude: longitude,
            label: 'Rider location',
          );
    if (riderLocation == null && rider == null) {
      throw const FormatException('Invalid rider data in buyer API response.');
    }
    return BuyerRiderSnapshot(location: riderLocation, rider: rider);
  }

  static Future<void> cancelOrder(
    BuyerOrderData order,
    String reason,
    String note,
  ) async {
    final String normalizedReason = reason.trim();
    const Map<String, String> reasonCodes = <String, String>{
      'Changed my mind': 'CHANGED_MIND',
      'Ordered by mistake': 'ORDERED_BY_MISTAKE',
      'Need to change address': 'OTHER',
      'Found a better option': 'OTHER',
      'Payment issue': 'OTHER',
      'Other': 'OTHER',
    };
    final String? reasonCode = reasonCodes[normalizedReason];
    if (reasonCode == null) {
      throw const FormatException('Choose a valid order cancellation reason.');
    }

    final String normalizedNote = note.trim();
    if (normalizedReason == 'Other' && normalizedNote.isEmpty) {
      throw const FormatException('Add a note when you choose Other.');
    }

    final List<String> details = <String>[
      if (reasonCode == 'OTHER' && normalizedReason != 'Other')
        normalizedReason,
      if (normalizedNote.isNotEmpty) normalizedNote,
    ];
    final String reasonDetails = details.join('\n\n');
    if (reasonDetails.length > 480) {
      throw const FormatException(
        'Cancellation notes must be 480 characters or fewer.',
      );
    }

    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(order.id)}/cancel',
      ),
      <String, dynamic>{
        'reason': reasonCode,
        if (reasonDetails.isNotEmpty) 'reason_details': reasonDetails,
      },
    );
    _requirePayload(response);
  }

  static Future<void> confirmOrderReceived(BuyerOrderData order) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(order.id)}/received',
      ),
      <String, dynamic>{'confirm_receipt': '1'},
    );
    _requirePayload(response);
  }

  static Future<String?> requestOrderReturn(
    BuyerOrderReturnRequest request,
  ) async {
    final FormData form = FormData();
    form.fields
      ..add(MapEntry<String, String>('issue_category', request.issueCategory))
      ..add(MapEntry<String, String>('issue_reason', request.issueReason))
      ..add(MapEntry<String, String>('description', request.description.trim()))
      ..add(MapEntry<String, String>('refund_method', request.refundMethod))
      ..add(MapEntry<String, String>('buyer_email', request.buyerEmail.trim()))
      ..add(const MapEntry<String, String>('confirm_cash', '1'))
      ..add(const MapEntry<String, String>('confirm_request', '1'));
    for (final MapEntry<String, int> entry
        in request.quantitiesByItem.entries) {
      form.fields
        ..add(MapEntry<String, String>('item_ids[]', entry.key))
        ..add(
          MapEntry<String, String>(
            'quantities[${entry.key}]',
            '${entry.value}',
          ),
        );
    }
    for (final XFile file in request.evidence) {
      form.files.add(
        MapEntry<String, MultipartFile>(
          'images[]',
          await MultipartFile.fromFile(file.path, filename: file.name),
        ),
      );
    }
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(request.order.id)}/return-refund',
      ),
      form,
    );
    return _requirePayload(response)['request_id']?.toString();
  }

  static Future<void> submitProductReview(
    BuyerOrderReviewRequest request,
  ) async {
    if (request.photos.length > 5) {
      throw const FormatException('You can attach up to five product photos.');
    }

    final String endpoint =
        'buyer/orders/items/${Uri.encodeComponent(request.product.id)}/review';
    final Map<String, dynamic> fields = <String, dynamic>{
      if (!request.isTextUpdate) 'rating': request.rating,
      if (!request.isTextUpdate) 'rider_rating': request.riderRating,
      if (!request.isTextUpdate) 'rider_comment': request.riderReview,
      'comment': request.review,
    };

    Response<dynamic> response = await _postReview(
      endpoint,
      fields,
      request.isTextUpdate ? const <XFile>[] : request.photos,
    );

    // A completed order may not have a delivery rider. Laravel then rejects
    // rider_rating, but the buyer's product rating should still be saved.
    if (!request.isTextUpdate &&
        (response.statusCode == 409 || response.statusCode == 422) &&
        _responseMessage(response).toLowerCase().contains('delivery rider')) {
      final Map<String, dynamic> productOnlyFields = <String, dynamic>{
        'rating': request.rating,
        'comment': request.review,
      };
      response = await _postReview(endpoint, productOnlyFields, request.photos);
    }

    // Orders loaded after a previous app session may already have a review,
    // even though the screen has no local record of it. Laravel rejects rating
    // and photo changes for those reviews but still accepts a text-only edit.
    if (!request.isTextUpdate &&
        (response.statusCode ?? 0) >= 400 &&
        _responseMessage(
          response,
        ).toLowerCase().contains('ratings and photos are locked')) {
      response = await _postReview(endpoint, <String, dynamic>{
        'comment': request.review,
      }, const <XFile>[]);
    }

    _requirePayload(response);
  }

  static Future<Response<dynamic>> _postReview(
    String endpoint,
    Map<String, dynamic> fields,
    List<XFile> photos,
  ) async {
    if (photos.isEmpty) {
      return ApiClient.post(AppConfig.resolveApiUrl(endpoint), fields);
    }

    final List<MultipartFile> images = <MultipartFile>[];
    for (final XFile photo in photos) {
      images.add(
        await MultipartFile.fromFile(photo.path, filename: photo.name),
      );
    }
    final FormData formData = FormData.fromMap(<String, dynamic>{
      ...fields,
      'images': images,
    });
    return ApiClient.post(AppConfig.resolveApiUrl(endpoint), formData);
  }

  static String _responseMessage(Response<dynamic> response) {
    final dynamic payload = response.data;
    return payload is Map && payload['message'] != null
        ? payload['message'].toString()
        : '';
  }

  static Future<BuyerProfileData> fetchProfile() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/profile'),
    );
    final dynamic user = _requirePayload(response)['user'];
    if (user is! Map) {
      throw const FormatException(
        'Profile data was not returned by the server.',
      );
    }
    return _profileData(Map<String, dynamic>.from(user));
  }

  static Future<BuyerAccountSnapshot> fetchAccountSnapshot() async {
    final List<Object> results = await Future.wait<Object>(<Future<Object>>[
      fetchProfile(),
      fetchBuyerAddresses(),
    ]);
    return BuyerAccountSnapshot(
      profile: results[0] as BuyerProfileData,
      addresses: results[1] as List<BuyerAddressData>,
    );
  }

  static Future<BuyerProfileData> updateProfile(
    UpdateBuyerProfileRequest request,
  ) async {
    final BuyerProfileData current = await fetchProfile();
    if (request.email.trim().toLowerCase() != current.email.toLowerCase()) {
      throw Exception(
        'Email changes are not available in the Laravel mobile API yet.',
      );
    }

    final List<String> nameParts = request.name.trim().split(RegExp(r'\s+'));
    if (nameParts.length < 2 ||
        nameParts.first.isEmpty ||
        nameParts.last.isEmpty) {
      throw const FormatException('Enter a first and last name.');
    }
    final String firstName = nameParts.first;
    final String? middleInitial = nameParts.length > 2
        ? nameParts[1]
        : current.middleInitial;
    if (middleInitial != null && middleInitial.length > 10) {
      throw const FormatException(
        'The Laravel profile API supports a middle initial of up to 10 characters.',
      );
    }
    final String lastName = nameParts.length > 2
        ? nameParts.skip(2).join(' ')
        : nameParts.last;
    final Map<String, dynamic> fields = <String, dynamic>{
      'first_name': firstName,
      'middle_initial': middleInitial,
      'last_name': lastName,
      'contact_number': request.phone,
      'birthday': request.birthday == null
          ? null
          : ('${request.birthday!.year.toString().padLeft(4, '0')}-'
                '${request.birthday!.month.toString().padLeft(2, '0')}-'
                '${request.birthday!.day.toString().padLeft(2, '0')}'),
      'sex': request.gender?.backendValue.toUpperCase(),
      if (request.mobileChangeCode != null)
        'mobile_change_code': request.mobileChangeCode,
      if (request.profilePhoto != null)
        'profile_photo': MultipartFile.fromBytes(
          request.profilePhoto!.bytes,
          filename: request.profilePhoto!.fileName,
        ),
    };
    final String profileUrl = AppConfig.resolveApiUrl('buyer/profile');
    final Response<dynamic> response = request.profilePhoto == null
        ? await ApiClient.patch(profileUrl, fields)
        : await ApiClient.post(
            profileUrl,
            FormData.fromMap(<String, dynamic>{...fields, '_method': 'PATCH'}),
          );
    final Map<String, dynamic> payload = _requirePayload(response);
    if (payload['requires_verification'] == true) {
      throw BuyerProfileVerificationRequiredException(
        target: (payload['target'] ?? '').toString(),
        message: (payload['message'] ?? '').toString(),
      );
    }
    final dynamic user = payload['user'];
    if (user is! Map) {
      throw const FormatException(
        'Updated profile data was not returned by the server.',
      );
    }
    return _profileData(Map<String, dynamic>.from(user));
  }

  static Future<void> resendMobileChangeCode() async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/profile/mobile-change/resend'),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<List<BuyerAddressData>> fetchBuyerAddresses() async {
    return (await _getRows('buyer/addresses'))
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          return BuyerAddressData(
            id: (row['id'] ?? '').toString(),
            label: (row['label'] ?? 'Address').toString(),
            recipientName: (row['recipient_name'] ?? '').toString(),
            contactNumber: (row['contact_number'] ?? '').toString(),
            houseNumber: row['house_number']?.toString(),
            street: row['street_address']?.toString(),
            barangay: row['barangay_name']?.toString(),
            municipality: row['municipality_name']?.toString(),
            province: row['province_name']?.toString(),
            region: row['region_name']?.toString(),
            regionCode: row['region_code']?.toString(),
            provinceCode: row['province_code']?.toString(),
            municipalityCode: row['municipality_code']?.toString(),
            barangayCode: row['barangay_code']?.toString(),
            postalCode: row['postal_code']?.toString(),
            landmark: row['landmark']?.toString(),
            latitude: _asDouble(row['latitude']),
            longitude: _asDouble(row['longitude']),
            isDefault: row['is_default'] == true,
            formattedAddress: row['formatted_address']?.toString(),
          );
        })
        .toList(growable: false);
  }

  static Future<void> deleteBuyerAddress(BuyerAddressData address) async {
    final Response<dynamic> response = await ApiClient.delete(
      AppConfig.resolveApiUrl(
        'buyer/addresses/${Uri.encodeComponent(address.id)}',
      ),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<BuyerProfileData> deleteProfilePhoto() async {
    final Response<dynamic> response = await ApiClient.delete(
      AppConfig.resolveApiUrl('buyer/profile/photo'),
      <String, dynamic>{},
    );
    final dynamic user = _requirePayload(response)['user'];
    if (user is! Map) {
      throw const FormatException(
        'The server did not return the updated profile.',
      );
    }
    return _profileData(Map<String, dynamic>.from(user));
  }

  static BuyerProfileData _profileData(Map<String, dynamic> user) {
    final String name =
        (user['name'] ??
                <String?>[
                      user['first_name']?.toString(),
                      user['last_name']?.toString(),
                    ]
                    .whereType<String>()
                    .where((String part) => part.isNotEmpty)
                    .join(' '))
            .toString();
    return BuyerProfileData(
      name: name,
      email: (user['email'] ?? '').toString(),
      phone: (user['contact_number'] ?? '').toString(),
      middleInitial: user['middle_initial']?.toString(),
      birthday: DateTime.tryParse((user['birthday'] ?? '').toString()),
      gender: BuyerGenderInfo.fromValue(user['sex']?.toString()),
      profilePhotoUrl: user['profile_photo_url']?.toString(),
    );
  }

  static Future<void> changePassword(ChangeBuyerPasswordRequest request) async {
    final Response<dynamic> response = await ApiClient.put(
      AppConfig.resolveApiUrl('buyer/password'),
      <String, dynamic>{
        'current_password': request.currentPassword,
        'password': request.newPassword,
        'password_confirmation': request.newPasswordConfirmation,
      },
    );
    _requirePayload(response);
  }

  static Future<List<BuyerNotificationData>> fetchNotifications({
    bool latestOnly = false,
  }) async {
    return (await _getRows(
          'buyer/notifications',
          maxPages: latestOnly ? 1 : null,
        ))
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          final dynamic rawData = row['data'];
          final Map<String, dynamic> payload = rawData is Map
              ? Map<String, dynamic>.from(rawData)
              : const <String, dynamic>{};
          final String? soundType = (row['type'] ?? payload['type'])
              ?.toString();
          final DateTime? createdAt = DateTime.tryParse(
            (row['created_at'] ?? '').toString(),
          );
          return BuyerNotificationData(
            id: row['id'].toString(),
            type: BuyerNotificationData.resolveType(soundType),
            soundType: soundType,
            title:
                (row['title'] ?? payload['title'] ?? payload['subject'] ?? '')
                    .toString(),
            message:
                (row['message'] ?? payload['message'] ?? payload['body'] ?? '')
                    .toString(),
            time: createdAt == null ? '' : _relativeTime(createdAt),
            unread: row['read_at'] == null,
            createdAt: createdAt,
            actionUrl:
                (row['action_url'] ??
                        payload['action_url'] ??
                        payload['actionUrl'] ??
                        payload['url'])
                    ?.toString(),
            relatedOrderId: BuyerNotificationData.resolveOrderReference(row),
          );
        })
        .toList(growable: false);
  }

  static Future<void> markAllNotificationsRead() async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/notifications/read-all'),
      <String, dynamic>{},
    );
    _requirePayload(response);
    _refreshNavigationBadges();
  }

  static Stream<BuyerNotificationData> watchNotifications() async* {
    final user = await AuthService.getCurrentUser();
    final RealtimeSubscription subscription =
        await LikhaeRealtimeService.subscribe('App.Models.User.${user.id}');
    try {
      await for (final RealtimeEvent event in subscription.events) {
        final bool isCreatedNotification =
            event.name == 'notification.created' ||
            event.name.endsWith('BroadcastNotificationCreated');
        if (!isCreatedNotification) continue;

        final dynamic rawPayload = event.data['data'];
        final Map<String, dynamic> notificationData = rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : event.data;
        final String? soundType =
            (notificationData['type'] ?? event.data['type'])?.toString();
        final DateTime? createdAt = DateTime.tryParse(
          (event.data['created_at'] ?? notificationData['created_at'] ?? '')
              .toString(),
        );
        _refreshNavigationBadges();
        yield BuyerNotificationData(
          id: (event.data['id'] ?? notificationData['id'] ?? '').toString(),
          type: BuyerNotificationData.resolveType(soundType),
          soundType: soundType,
          title:
              (notificationData['title'] ??
                      notificationData['subject'] ??
                      event.data['title'] ??
                      '')
                  .toString(),
          message:
              (notificationData['message'] ??
                      notificationData['body'] ??
                      notificationData['content'] ??
                      event.data['message'] ??
                      '')
                  .toString(),
          time: createdAt == null ? 'Just now' : _displayTime(createdAt),
          unread: true,
          createdAt: createdAt,
          actionUrl:
              (notificationData['action_url'] ??
                      notificationData['actionUrl'] ??
                      notificationData['url'] ??
                      event.data['action_url'])
                  ?.toString(),
          relatedOrderId:
              BuyerNotificationData.resolveOrderReference(notificationData) ??
              BuyerNotificationData.resolveOrderReference(event.data),
        );
      }
    } finally {
      await subscription.cancel();
    }
  }

  static Future<List<BuyerConversationData>> fetchConversations() async {
    return (await _getRows('buyer/messages'))
        .whereType<Map>()
        .map((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          final dynamic rawOnline =
              row['seller_is_online'] ?? row['is_online'] ?? row['online'];
          final String? rawStatus =
              (row['seller_status'] ?? row['status_label'])?.toString();
          final dynamic rawAvatar =
              row['seller_avatar_url'] ?? row['avatar_url'] ?? row['avatar'];
          final String? avatarUrl = rawAvatar?.toString().trim();
          final dynamic rawOrderContext = row['order_context'];
          final Map<String, dynamic> orderContextData = rawOrderContext is Map
              ? Map<String, dynamic>.from(rawOrderContext)
              : const <String, dynamic>{};
          final dynamic rawOrderProducts =
              orderContextData['products'] ?? orderContextData['items'];
          final List<MessageOrderProduct> orderProducts =
              rawOrderProducts is List
              ? rawOrderProducts
                    .whereType<Map>()
                    .map((Map rawProduct) {
                      final Map<String, dynamic> product =
                          Map<String, dynamic>.from(rawProduct);
                      final String rawImage = (product['image_url'] ?? '')
                          .toString()
                          .trim();
                      return MessageOrderProduct(
                        name: (product['name'] ?? 'Product').toString(),
                        imageUrl: rawImage.isEmpty
                            ? null
                            : AppConfig.resolveMediaUrl(rawImage),
                        variant: product['variant']?.toString(),
                        quantity:
                            int.tryParse(
                              (product['quantity'] ?? 1).toString(),
                            ) ??
                            1,
                      );
                    })
                    .toList(growable: false)
              : const <MessageOrderProduct>[];
          final MessageOrderContext? orderContext = orderContextData.isEmpty
              ? null
              : MessageOrderContext(
                  orderReference:
                      (orderContextData['order_reference'] ??
                              orderContextData['seller_order_number'] ??
                              '')
                          .toString(),
                  status:
                      (orderContextData['status_label'] ??
                              orderContextData['status'] ??
                              '')
                          .toString(),
                  orderId: (orderContextData['order_id'] ?? '').toString(),
                  sellerOrderId: (orderContextData['seller_order_id'] ?? '')
                      .toString(),
                  products: orderProducts,
                );
          return BuyerConversationData(
            sellerId: (row['seller_id'] ?? '').toString(),
            conversationId: (row['conversation_id'] ?? row['id'] ?? '')
                .toString(),
            name: (row['seller_name'] ?? 'Seller').toString(),
            slug: (row['slug'] ?? '').toString(),
            statusLabel: rawStatus,
            avatarUrl: avatarUrl == null || avatarUrl.isEmpty
                ? null
                : AppConfig.resolveMediaUrl(avatarUrl),
            lastMessage: (row['last_message'] ?? '').toString(),
            time: _displayTime(row['time']),
            unread: int.tryParse((row['unread'] ?? 0).toString()) ?? 0,
            orderContext: orderContext,
            isOnline:
                _optionalApiBool(rawOnline) ?? _presenceFromLabel(rawStatus),
          );
        })
        .where((BuyerConversationData item) => item.sellerId.isNotEmpty)
        .toList(growable: false);
  }

  static Future<List<BuyerMessageData>> fetchMessages(
    BuyerConversationData conversation, {
    String? afterId,
  }) async {
    final String id = conversation.conversationId;
    if (id.isEmpty) {
      throw const FormatException('Conversation identifier is missing.');
    }
    final List<dynamic> rawMessages = await _getRows(
      'buyer/messages/${Uri.encodeComponent(id)}',
      maxPages: afterId == null ? null : 1,
      queryParameters: <String, dynamic>{
        if (afterId != null) 'after_id': afterId,
      },
    );
    if (afterId == null) _refreshNavigationBadges();
    return rawMessages
        .whereType<Map>()
        .map<BuyerMessageData>((Map item) {
          final Map<String, dynamic> row = Map<String, dynamic>.from(item);
          return BuyerMessageData(
            id: (row['id'] ?? '').toString(),
            conversationId: (row['conversation_id'] ?? '').toString(),
            body: (row['body'] ?? '').toString(),
            time: _displayTime(row['sent_at']),
            sentAt: DateTime.tryParse(
              (row['sent_at'] ?? '').toString(),
            )?.toLocal(),
            fromBuyer: row['from_buyer'] == true,
            attachmentUrl: _messageAttachmentUrl(row),
            attachmentName: row['attachment_name']?.toString(),
            seenByRecipient: _messageSeenState(row),
          );
        })
        .toList(growable: false);
  }

  static Stream<BuyerMessageData> watchMessages(
    BuyerConversationData conversation,
  ) async* {
    final Set<String> knownIds = <String>{};
    RealtimeSubscription? subscription;
    try {
      subscription = await LikhaeRealtimeService.subscribe(
        'conversations.${conversation.conversationId}',
      );
      await for (final RealtimeEvent event in subscription.events) {
        if (event.name != 'message.sent') continue;
        final String id = (event.data['id'] ?? '').toString();
        if (id.isEmpty || !knownIds.add(id)) continue;
        yield BuyerMessageData(
          id: id,
          body: (event.data['body'] ?? '').toString(),
          time: _displayTime(event.data['sent_at']),
          sentAt: DateTime.tryParse(
            (event.data['sent_at'] ?? '').toString(),
          )?.toLocal(),
          fromBuyer: false,
          attachmentUrl: event.data['attachment_url']?.toString(),
          attachmentName: event.data['attachment_name']?.toString(),
          seenByRecipient: _messageSeenState(event.data),
        );
      }
    } catch (_) {
      // Seed the fallback once if Reverb is unavailable. The screen has
      // already loaded its initial history, so realtime connections do not
      // need a second full-history request here.
      final List<BuyerMessageData> baseline = await fetchMessages(conversation);
      knownIds.addAll(baseline.map((BuyerMessageData message) => message.id));
      while (true) {
        await Future<void>.delayed(const Duration(seconds: 10));
        final String? latestId = knownIds.isEmpty ? null : knownIds.lastOrNull;
        final List<BuyerMessageData> latest = await fetchMessages(
          conversation,
          afterId: latestId,
        );
        for (final BuyerMessageData message in latest) {
          if (knownIds.add(message.id)) yield message;
        }
      }
    } finally {
      await subscription?.cancel();
    }
  }

  static Future<BuyerMessageData> sendMessage(
    BuyerConversationData conversation,
    String body,
  ) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(_messageSendEndpoint(conversation)),
      <String, dynamic>{
        ..._messageSendFields(conversation),
        'body': body,
      },
    );
    final dynamic rawMessage = _requirePayload(response)['data'];
    if (rawMessage is! Map) {
      throw const FormatException(
        'The server did not return the sent message.',
      );
    }
    _refreshNavigationBadges();
    final Map<String, dynamic> message = Map<String, dynamic>.from(rawMessage);
    return _buyerMessageFromApi(message);
  }

  static Future<void> touchMessagePresence() async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/messages/presence'),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<BuyerConversationPresenceData> refreshConversationPresence(
    BuyerConversationData conversation,
  ) async {
    if (conversation.conversationId.isEmpty) {
      throw const FormatException('Conversation identifier is missing.');
    }
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(
        'buyer/messages/${Uri.encodeComponent(conversation.conversationId)}/receipt',
      ),
    );
    final Map<String, dynamic> payload = _requirePayload(response);
    final dynamic data = payload['data'];
    final Map<String, dynamic> row = data is Map
        ? Map<String, dynamic>.from(data)
        : payload;
    final dynamic rawReadAt = row['recipient_read_at'] ?? row['last_read_at'];
    return BuyerConversationPresenceData(
      isOnline:
          _optionalApiBool(
            row['recipient_online'] ?? row['is_online'] ?? row['online'],
          ) ??
          false,
      recipientReadAt: rawReadAt == null
          ? null
          : DateTime.tryParse(rawReadAt.toString())?.toLocal(),
    );
  }

  static Future<BuyerMessageData> sendAttachment(
    BuyerConversationData conversation,
    String body,
    String attachmentPath,
  ) async {
    final FormData formData = FormData.fromMap(<String, dynamic>{
      ..._messageSendFields(conversation),
      'body': body,
      'attachment': await MultipartFile.fromFile(attachmentPath),
    });
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(_messageSendEndpoint(conversation)),
      formData,
    );
    final dynamic rawMessage = _requirePayload(response)['data'];
    if (rawMessage is! Map) {
      throw const FormatException(
        'The server did not return the saved message.',
      );
    }
    _refreshNavigationBadges();
    return _buyerMessageFromApi(Map<String, dynamic>.from(rawMessage));
  }

  static String _messageSendEndpoint(BuyerConversationData conversation) {
    final int? orderId = int.tryParse(
      conversation.orderContext?.orderId.trim() ?? '',
    );
    final int? sellerOrderId = int.tryParse(
      conversation.orderContext?.sellerOrderId.trim() ?? '',
    );
    if (orderId != null && sellerOrderId != null) {
      return 'buyer/orders/${Uri.encodeComponent(orderId.toString())}/messages';
    }
    return 'buyer/messages';
  }

  static Map<String, dynamic> _messageSendFields(
    BuyerConversationData conversation,
  ) {
    final int? orderId = int.tryParse(
      conversation.orderContext?.orderId.trim() ?? '',
    );
    final int? sellerOrderId = int.tryParse(
      conversation.orderContext?.sellerOrderId.trim() ?? '',
    );
    if (orderId != null && sellerOrderId != null) {
      return <String, dynamic>{'seller_order_id': sellerOrderId};
    }
    return <String, dynamic>{
      'recipient_id': int.tryParse(conversation.sellerId),
      if (orderId != null) 'order_id': orderId,
      if (sellerOrderId != null) 'seller_order_id': sellerOrderId,
    };
  }

  static BuyerMessageData _buyerMessageFromApi(Map<String, dynamic> message) {
    return BuyerMessageData(
      id: (message['id'] ?? '').toString(),
      conversationId: (message['conversation_id'] ?? '').toString(),
      body: (message['body'] ?? '').toString(),
      time: _displayTime(message['sent_at']),
      sentAt: DateTime.tryParse(
        (message['sent_at'] ?? '').toString(),
      )?.toLocal(),
      fromBuyer: message['from_buyer'] == true,
      attachmentUrl: _messageAttachmentUrl(message),
      attachmentName: message['attachment_name']?.toString(),
      seenByRecipient: _messageSeenState(message),
    );
  }

  static bool? _optionalApiBool(dynamic value) {
    if (value == null) return null;
    final String normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    return parseApiBool(value, defaultValue: false);
  }

  static bool? _presenceFromLabel(String? value) {
    final String label = value?.trim().toLowerCase() ?? '';
    if (label == 'online' || label.endsWith(' · online')) return true;
    if (label == 'offline' || label.endsWith(' · offline')) return false;
    return null;
  }

  static bool? _messageSeenState(Map<String, dynamic> message) {
    for (final String key in <String>['seen_by_recipient', 'is_seen', 'seen']) {
      if (message.containsKey(key) && message[key] != null) {
        return parseApiBool(message[key], defaultValue: false);
      }
    }

    for (final String key in <String>[
      'recipient_read_at',
      'seen_at',
      'read_at',
    ]) {
      if (message.containsKey(key)) {
        final dynamic value = message[key];
        return value != null && value.toString().trim().isNotEmpty;
      }
    }

    return null;
  }

  static String? _messageAttachmentUrl(Map<String, dynamic> message) {
    dynamic raw =
        message['attachment_url'] ??
        message['attachment'] ??
        message['attachment_path'] ??
        message['image_url'] ??
        message['photo_url'];

    if (raw is Map) {
      raw = raw['url'] ?? raw['image_url'] ?? raw['path'] ?? raw['file_path'];
    }

    if (raw == null) {
      return null;
    }

    final String value = raw.toString().trim();
    return value.isEmpty ? null : AppConfig.resolveMediaUrl(value);
  }

  static Future<BuyerAddressData> updateBuyerAddress({
    required String addressId,
    required CreateBuyerAddressRequest request,
  }) async {
    final Response<dynamic> response = await ApiClient.put(
      AppConfig.resolveApiUrl(
        'buyer/addresses/${Uri.encodeComponent(addressId)}',
      ),
      <String, dynamic>{
        'label': request.label,
        'recipient_name': request.recipientName,
        'contact_number': request.contactNumber,
        'region_code': request.regionCode ?? _locationCode(request.region),
        'region_name': request.region,
        'province_name': request.province,
        'province_code':
            request.provinceCode ?? _locationCode(request.province),
        'municipality_name': request.municipality,
        'municipality_code':
            request.municipalityCode ?? _locationCode(request.municipality),
        'barangay_name': request.barangay,
        'barangay_code':
            request.barangayCode ?? _locationCode(request.barangay),
        'postal_code': request.postalCode,
        'house_number': request.houseNumber,
        'street_address': request.street,
        'landmark': request.landmark,
        if (request.latitude != null) 'latitude': request.latitude,
        if (request.longitude != null) 'longitude': request.longitude,
        'is_default': request.isDefault,
      },
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException(
        'The server did not return the updated address.',
      );
    }
    final Map<String, dynamic> row = Map<String, dynamic>.from(data);
    return BuyerAddressData(
      id: (row['id'] ?? '').toString(),
      label: (row['label'] ?? 'Address').toString(),
      recipientName: (row['recipient_name'] ?? '').toString(),
      contactNumber: (row['contact_number'] ?? '').toString(),
      houseNumber: row['house_number']?.toString(),
      street: row['street_address']?.toString(),
      barangay: row['barangay_name']?.toString(),
      municipality: row['municipality_name']?.toString(),
      province: row['province_name']?.toString(),
      region: row['region_name']?.toString(),
      regionCode: row['region_code']?.toString(),
      provinceCode: row['province_code']?.toString(),
      municipalityCode: row['municipality_code']?.toString(),
      barangayCode: row['barangay_code']?.toString(),
      postalCode: row['postal_code']?.toString(),
      landmark: row['landmark']?.toString(),
      latitude: _asDouble(row['latitude']),
      longitude: _asDouble(row['longitude']),
      isDefault: row['is_default'] == true,
      formattedAddress: row['formatted_address']?.toString(),
    );
  }

  static Future<void> requestEmailChange(String email) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/profile/email-change'),
      <String, dynamic>{'email': email.trim()},
    );
    _requirePayload(response);
  }

  static Future<void> resendEmailChangeCode() async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/profile/email-change/resend'),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<BuyerProfileData> verifyEmailChange(String code) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/profile/email-change/verify'),
      <String, dynamic>{'code': code.trim()},
    );
    final dynamic user = _requirePayload(response)['user'];
    if (user is! Map) {
      throw const FormatException(
        'The server did not return the verified profile.',
      );
    }
    return _profileData(Map<String, dynamic>.from(user));
  }

  static Future<Map<String, dynamic>> fetchBuyerSettings() async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/settings'),
      refresh: true,
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException('Buyer settings were not returned.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> saveBuyerSettings(
    Map<String, dynamic> settings,
  ) async {
    final Response<dynamic> response = await ApiClient.put(
      AppConfig.resolveApiUrl('buyer/settings'),
      settings,
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map) {
      throw const FormatException('The server did not confirm the settings.');
    }
    return Map<String, dynamic>.from(data);
  }

  static Future<void> deleteBuyerAccount({
    required String password,
    required String confirmation,
  }) async {
    final Response<dynamic> response = await ApiClient.delete(
      AppConfig.resolveApiUrl('buyer/account'),
      <String, dynamic>{
        'current_password': password,
        'delete_confirmation': confirmation,
      },
    );
    _requirePayload(response);
  }

  static Future<List<Map<String, dynamic>>> fetchReviewHistory() async =>
      (await _getRows('buyer/account/reviews'))
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

  static Future<void> markNotificationRead(String notificationId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/notifications/${Uri.encodeComponent(notificationId)}/read',
      ),
      <String, dynamic>{},
    );
    _requirePayload(response);
    _refreshNavigationBadges();
  }

  static Future<String?> openNotification(String notificationId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/notifications/${Uri.encodeComponent(notificationId)}/open',
      ),
      <String, dynamic>{},
    );
    final dynamic data = _requirePayload(response)['data'];
    return data is Map ? data['action_url']?.toString() : null;
  }

  static Future<void> dismissAnnouncement(String notificationId) async {
    final Response<dynamic> response = await ApiClient.delete(
      AppConfig.resolveApiUrl(
        'buyer/notifications/${Uri.encodeComponent(notificationId)}',
      ),
      <String, dynamic>{},
    );
    _requirePayload(response);
    _refreshNavigationBadges();
  }

  static Future<void> setFlashReminder(int productId, bool enabled) async {
    final String path = AppConfig.resolveApiUrl(
      'buyer/products/$productId/flash-reminder',
    );
    final Response<dynamic> response = enabled
        ? await ApiClient.post(path, <String, dynamic>{})
        : await ApiClient.delete(path, <String, dynamic>{});
    _requirePayload(response);
  }

  static Future<Map<String, dynamic>> fetchFlashReminder(int productId) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/products/$productId/flash-reminder'),
    );
    final dynamic data = _requirePayload(response)['data'];
    return data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
  }

  static Future<void> claimVoucher(int voucherId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl('buyer/vouchers/$voucherId/claim'),
      <String, dynamic>{},
    );
    _requirePayload(response);
  }

  static Future<Map<String, dynamic>> fetchPlatformEvent(int voucherId) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/events/$voucherId'),
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map)
      throw const FormatException('Event details were not returned.');
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> buyAgain(String orderId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(orderId)}/buy-again',
      ),
      <String, dynamic>{},
    );
    final dynamic data = _requirePayload(response)['data'];
    return data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
  }

  static Future<void> confirmDeliveryPin({
    required String orderId,
    required double latitude,
    required double longitude,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/orders/${Uri.encodeComponent(orderId)}/delivery-pin',
      ),
      <String, dynamic>{'latitude': latitude, 'longitude': longitude},
    );
    _requirePayload(response);
  }

  static Future<Map<String, dynamic>> fetchPublicTracking(
    String trackingNumber,
  ) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(
        'tracking/${Uri.encodeComponent(trackingNumber)}',
      ),
      refresh: true,
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map)
      throw const FormatException('Tracking details were not returned.');
    return Map<String, dynamic>.from(data);
  }

  static Future<List<Map<String, dynamic>>> fetchReturnRequests() async =>
      (await _getRows('buyer/returns'))
          .whereType<Map>()
          .map((Map row) => Map<String, dynamic>.from(row))
          .toList(growable: false);

  static Future<Map<String, dynamic>> fetchReturnRequest(String id) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl('buyer/returns/${Uri.encodeComponent(id)}'),
    );
    final dynamic data = _requirePayload(response)['data'];
    if (data is! Map)
      throw const FormatException('Return/refund case was not returned.');
    return Map<String, dynamic>.from(data);
  }

  static Future<Uint8List> fetchReturnEvidence(String evidenceId) =>
      _fetchPrivateBuyerFile('buyer/returns/evidence/$evidenceId');

  static Future<Uint8List> fetchReturnPayoutProof(String payoutId) =>
      _fetchPrivateBuyerFile('buyer/returns/payout-proofs/$payoutId');

  static Future<Uint8List> fetchDeliveryAttemptProof(String attemptId) =>
      _fetchPrivateBuyerFile('buyer/delivery-attempts/$attemptId/proof');

  static Future<Uint8List> _fetchPrivateBuyerFile(String endpoint) async {
    final Response<dynamic> response = await ApiClient.get(
      AppConfig.resolveApiUrl(endpoint),
      options: Options(
        responseType: ResponseType.bytes,
        headers: const <String, String>{'Accept': '*/*'},
      ),
    );
    final int statusCode = response.statusCode ?? 500;
    if (statusCode < 200 || statusCode >= 300) {
      throw Exception('Unable to open this private file (HTTP $statusCode).');
    }
    final dynamic bytes = response.data;
    if (bytes is Uint8List) return bytes;
    if (bytes is List<int>) return Uint8List.fromList(bytes);
    throw const FormatException('The private file could not be read.');
  }

  static Future<void> confirmReturnRefund(String sellerCaseId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/returns/seller-cases/${Uri.encodeComponent(sellerCaseId)}/confirm',
      ),
      <String, dynamic>{'confirm_receipt': true},
    );
    _requirePayload(response);
  }

  static Future<void> confirmReturnCashRefund(String obligationId) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/returns/cash-refunds/${Uri.encodeComponent(obligationId)}/confirm',
      ),
      <String, dynamic>{'confirm_receipt': true},
    );
    _requirePayload(response);
  }

  static Future<void> escalateReturnRefund({
    required String sellerCaseId,
    required String reason,
    required String explanation,
  }) async {
    final Response<dynamic> response = await ApiClient.post(
      AppConfig.resolveApiUrl(
        'buyer/returns/seller-cases/${Uri.encodeComponent(sellerCaseId)}/escalate',
      ),
      <String, dynamic>{
        'reason': reason,
        'explanation': explanation,
        'confirm_escalation': true,
      },
    );
    _requirePayload(response);
  }

  static CartItemData _cartItem(Map<String, dynamic> row) {
    return CartItemData(
      id: (row['id'] ?? '').toString(),
      productId: int.tryParse((row['product_id'] ?? '').toString()),
      productVariationId: int.tryParse(
        (row['product_variant_id'] ?? '').toString(),
      ),
      slug: row['slug']?.toString(),
      name: (row['name'] ?? 'Product').toString(),
      category: (row['category'] ?? '').toString(),
      variant: (row['variant'] ?? 'Standard').toString(),
      seller: (row['seller'] ?? 'Seller').toString(),
      sellerId: int.tryParse((row['seller_id'] ?? '').toString()),
      price: _asDouble(row['price']),
      oldPrice: row['old_price'] == null ? null : _asDouble(row['old_price']),
      quantity: int.tryParse((row['quantity'] ?? 1).toString()) ?? 1,
      stock: int.tryParse((row['stock'] ?? 0).toString()) ?? 0,
      isActive: parseApiBool(
        row['is_active'],
        defaultValue: (row['product_status'] ?? 'ACTIVE') == 'ACTIVE',
      ),
      sellerOnVacation: parseApiBool(
        row['seller_on_vacation'],
        defaultValue: false,
      ),
      serverAvailable: parseApiBool(row['available'], defaultValue: true),
      imageUrl: row['image_url'] == null
          ? null
          : AppConfig.resolveMediaUrl(row['image_url'].toString()),
    );
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _relativeTime(DateTime value) {
    final Duration age = DateTime.now().difference(value);
    if (age.inMinutes < 1) return 'Just now';
    if (age.inHours < 1) return '${age.inMinutes} minutes ago';
    if (age.inDays < 1) return '${age.inHours} hours ago';
    if (age.inDays < 7) return '${age.inDays} days ago';
    return '${value.month}/${value.day}/${value.year}';
  }

  static String _displayTime(dynamic value) {
    final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
    return parsed == null ? (value?.toString() ?? '') : _relativeTime(parsed);
  }
}

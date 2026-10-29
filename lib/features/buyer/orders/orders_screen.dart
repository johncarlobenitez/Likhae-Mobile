import '../../../shared/widgets/sized_network_image.dart';
import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:likhae/core/config/app_config.dart';
import 'package:likhae/features/buyer/products/products_screen.dart';

enum BuyerOrdersMode { overview, success, details, review, returnRequest }

enum BuyerOrderTab {
  all,
  toPay,
  toShip,
  toReceive,
  completed,
  cancelled,
  returns,
}

String? _formatOrderVariant(dynamic raw) {
  String displayValue(dynamic value) {
    if (value is Map) {
      return (value['value'] ?? value['name'] ?? value['label'] ?? '')
          .toString()
          .trim();
    }
    if (value is List) {
      return value
          .map(displayValue)
          .where((String item) => item.isNotEmpty)
          .join(', ');
    }
    return value?.toString().trim() ?? '';
  }

  if (raw is Map) {
    final List<String> parts = <String>[];
    for (final MapEntry<dynamic, dynamic> entry in raw.entries) {
      final String value = displayValue(entry.value);
      if (value.isEmpty) continue;
      final String label = entry.key.toString().trim();
      parts.add(label.isEmpty ? value : '$label: $value');
    }
    if (parts.isNotEmpty) return parts.join(' / ');
  }
  final String value = displayValue(raw);
  return value.isEmpty ? null : value;
}

extension BuyerOrderTabInfo on BuyerOrderTab {
  String get statusKey {
    switch (this) {
      case BuyerOrderTab.all:
        return 'all';

      case BuyerOrderTab.toPay:
        return 'to-pay';

      case BuyerOrderTab.toShip:
        return 'to-ship';

      case BuyerOrderTab.toReceive:
        return 'to-receive';

      case BuyerOrderTab.completed:
        return 'completed';

      case BuyerOrderTab.cancelled:
        return 'cancelled';

      case BuyerOrderTab.returns:
        return 'returns';
    }
  }

  String get label {
    switch (this) {
      case BuyerOrderTab.all:
        return 'All';

      case BuyerOrderTab.toPay:
        return 'To Pay';

      case BuyerOrderTab.toShip:
        return 'To Ship';

      case BuyerOrderTab.toReceive:
        return 'To Receive';

      case BuyerOrderTab.completed:
        return 'Completed';

      case BuyerOrderTab.cancelled:
        return 'Cancelled';

      case BuyerOrderTab.returns:
        return 'Returns / Refunds';
    }
  }
}

class BuyerOrderProductData {
  final String id;

  final int? productId;
  final int? productVariationId;

  final String name;

  final String? variant;
  final String? imageUrl;
  final List<String> imageUrls;

  final double price;

  final int quantity;

  const BuyerOrderProductData({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.productId,
    this.productVariationId,
    this.variant,
    this.imageUrl,
    this.imageUrls = const <String>[],
  });

  int get safeQuantity {
    return quantity < 1 ? 1 : quantity;
  }

  double get lineTotal {
    return price * safeQuantity;
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

class BuyerSellerOrderData {
  final String id;
  final String orderNumber;
  final String status;
  final String sellerName;
  final int? sellerId;
  final String? sellerSlug;
  final String? sellerAvatarUrl;
  final List<BuyerOrderProductData> products;
  final List<BuyerOrderParcelData> parcels;

  const BuyerSellerOrderData({
    required this.id,
    required this.orderNumber,
    required this.status,
    required this.sellerName,
    required this.products,
    this.parcels = const <BuyerOrderParcelData>[],
    this.sellerId,
    this.sellerSlug,
    this.sellerAvatarUrl,
  });

  factory BuyerSellerOrderData.fromApi(Map<String, dynamic> json) {
    final dynamic rawSeller = json['seller'];
    final Map<String, dynamic> seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : const <String, dynamic>{};
    final dynamic rawProducts = json['products'] ?? json['items'];
    final List<BuyerOrderProductData> products = rawProducts is List
        ? rawProducts
              .whereType<Map>()
              .map((Map item) {
                final Map<String, dynamic> product = Map<String, dynamic>.from(
                  item,
                );
                final String rawImage = (product['image_url'] ?? '')
                    .toString()
                    .trim();
                final String imageUrl = rawImage.isEmpty
                    ? ''
                    : AppConfig.resolveMediaUrl(rawImage);
                return BuyerOrderProductData(
                  id: (product['id'] ?? product['product_id'] ?? '').toString(),
                  productId: int.tryParse(
                    (product['product_id'] ?? '').toString(),
                  ),
                  name: (product['name'] ?? 'Product').toString(),
                  variant: _formatOrderVariant(product['variant']),
                  imageUrl: imageUrl.isEmpty ? null : imageUrl,
                  imageUrls: imageUrl.isEmpty
                      ? const <String>[]
                      : <String>[imageUrl],
                  price:
                      double.tryParse(
                        (product['unit_price'] ?? product['price'] ?? 0)
                            .toString(),
                      ) ??
                      0,
                  quantity:
                      int.tryParse((product['quantity'] ?? 1).toString()) ?? 1,
                );
              })
              .toList(growable: false)
        : const <BuyerOrderProductData>[];
    final dynamic rawParcels =
        json['shipments'] ?? json['parcels'] ?? json['shipment'];
    final Iterable<dynamic> parcelRows = rawParcels is List
        ? rawParcels
        : rawParcels is Map
        ? <dynamic>[rawParcels]
        : const <dynamic>[];
    final List<BuyerOrderParcelData> parcels = parcelRows
        .whereType<Map>()
        .map(
          (Map item) =>
              BuyerOrderParcelData.fromApi(Map<String, dynamic>.from(item)),
        )
        .toList(growable: false);
    final String rawAvatar = (seller['avatar_url'] ?? '').toString().trim();

    return BuyerSellerOrderData(
      id: (json['id'] ?? json['seller_order_id'] ?? '').toString(),
      orderNumber: (json['seller_order_number'] ?? json['order_number'] ?? '')
          .toString(),
      status: (json['status_label'] ?? json['status'] ?? '').toString(),
      sellerName: (seller['name'] ?? seller['business_name'] ?? 'Seller')
          .toString(),
      sellerId: int.tryParse(
        (json['seller_user_id'] ??
                json['seller_id'] ??
                seller['seller_user_id'] ??
                seller['user_id'] ??
                seller['id'] ??
                '')
            .toString(),
      ),
      sellerSlug: (seller['slug'] ?? '').toString(),
      sellerAvatarUrl: rawAvatar.isEmpty
          ? null
          : AppConfig.resolveMediaUrl(rawAvatar),
      products: products,
      parcels: parcels,
    );
  }
}

class BuyerOrderTimelineEvent {
  final String label;

  final String time;

  final DateTime? occurredAt;

  final bool done;

  /// Optional shipment note, such as a sorting hub or delivery location.
  final String details;

  const BuyerOrderTimelineEvent({
    required this.label,
    required this.time,
    required this.done,
    this.details = '',
    this.occurredAt,
  });
}

String _formatBuyerReturnDate(DateTime date) {
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final DateTime local = date.toLocal();
  return '${months[local.month - 1]} ${local.day}, ${local.year}';
}

List<String> parseBuyerDeliveryProofUrls(
  Iterable<Map<String, dynamic>> sources,
) {
  const List<String> proofKeys = <String>[
    'proof_url',
    'proof_file_url',
    'proof_image_url',
    'proof_photo_url',
    'delivery_proof_url',
    'delivery_proof_path',
    'delivery_proof_file',
    'delivery_proof_file_url',
    'delivery_photo_url',
    'delivery_image_url',
    'proof_of_delivery_url',
    'proof_of_delivery_path',
    'proof_of_delivery_photo',
    'delivery_proof_image_url',
    'delivery_proof_photo_url',
    'proof_urls',
    'proof_images',
    'proof_photos',
    'proof_files',
    'proof',
    'pod_url',
    'pod_photo_url',
    'pod_image_url',
    'pod_photo',
    'pod_image',
    'pod_file',
    'proof_path',
    'proof_file',
    'proof_image',
    'proof_photo',
    'delivery_proof',
    'delivery_proof_image',
    'delivery_proof_images',
    'delivery_proof_photo',
    'delivery_proof_photos',
    'delivery_proofs',
    'proof_of_delivery',
    'photo_path',
    'photo_url',
    'attachments',
    'delivery_attempt',
    'latest_delivery_attempt',
    'latest_attempt',
    'delivery_attempts',
    'delivery',
    'rider_delivery',
    'rider_assignment',
    'assignment',
    'attempt',
    'attempts',
    'events',
    'tracking_events',
    'tracking_timeline',
    'shipment_events',
    'status_history',
    'timeline',
    'data',
  ];
  const List<String> mediaKeys = <String>[
    'url',
    'image_url',
    'image',
    'photo_url',
    'photo',
    'file_url',
    'file',
    'download_url',
    'original_url',
    'file_path',
    'path',
    'src',
  ];

  final List<String> urls = <String>[];

  void addMedia(dynamic value) {
    if (value is List) {
      for (final dynamic item in value) {
        addMedia(item);
      }
      return;
    }
    if (value is Map) {
      for (final String key in mediaKeys) {
        final dynamic nested = value[key];
        if (nested != null) {
          addMedia(nested);
          return;
        }
      }
      for (final String key in proofKeys) {
        final dynamic nested = value[key];
        if (nested != null) addMedia(nested);
      }
      return;
    }
    final String path = value?.toString().trim() ?? '';
    if (path.isEmpty) return;
    final String url = AppConfig.resolveMediaUrl(path);
    if (url.isNotEmpty && !urls.contains(url)) urls.add(url);
  }

  for (final Map<String, dynamic> source in sources) {
    for (final String key in proofKeys) {
      if (source[key] != null) addMedia(source[key]);
    }
  }

  return urls;
}

class BuyerOrderLocation {
  final double latitude;

  final double longitude;

  final String label;

  final String? id;

  final List<String> transferLegIds;

  final int? sequenceNo;

  final String? centerRole;

  final String? progressStatus;

  const BuyerOrderLocation({
    required this.latitude,
    required this.longitude,
    required this.label,
    this.id,
    this.transferLegIds = const <String>[],
    this.sequenceNo,
    this.centerRole,
    this.progressStatus,
  });

  BuyerOrderLocation copyWith({
    String? id,
    List<String>? transferLegIds,
    int? sequenceNo,
    String? centerRole,
    String? progressStatus,
  }) => BuyerOrderLocation(
    latitude: latitude,
    longitude: longitude,
    label: label,
    id: id ?? this.id,
    transferLegIds: transferLegIds ?? this.transferLegIds,
    sequenceNo: sequenceNo ?? this.sequenceNo,
    centerRole: centerRole ?? this.centerRole,
    progressStatus: progressStatus ?? this.progressStatus,
  );
}

class BuyerRiderInfo {
  final String? name;
  final String? photoUrl;
  final String? vehicleType;
  final String? plateNumber;

  const BuyerRiderInfo({
    this.name,
    this.photoUrl,
    this.vehicleType,
    this.plateNumber,
  });

  bool get hasVisibleInfo =>
      (name?.isNotEmpty ?? false) ||
      (photoUrl?.isNotEmpty ?? false) ||
      (vehicleType?.isNotEmpty ?? false) ||
      (plateNumber?.isNotEmpty ?? false);

  factory BuyerRiderInfo.fromApi(Map<String, dynamic> json) {
    final dynamic rawProfile = json['rider_profile'] ?? json['profile'];
    final Map<String, dynamic> profile = rawProfile is Map
        ? Map<String, dynamic>.from(rawProfile)
        : const <String, dynamic>{};
    final dynamic rawUser = json['user'] ?? profile['user'];
    final Map<String, dynamic> user = rawUser is Map
        ? Map<String, dynamic>.from(rawUser)
        : const <String, dynamic>{};

    String? firstText(Iterable<dynamic> values) {
      for (final dynamic value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final String? photoPath = firstText(<dynamic>[
      json['profile_photo_url'],
      json['photo_url'],
      json['avatar_url'],
      profile['profile_photo_url'],
      profile['photo_url'],
      user['profile_photo_url'],
    ]);

    return BuyerRiderInfo(
      name: firstText(<dynamic>[json['name'], json['full_name'], user['name']]),
      photoUrl: photoPath == null ? null : AppConfig.resolveMediaUrl(photoPath),
      vehicleType: firstText(<dynamic>[
        json['vehicle_type'],
        profile['vehicle_type'],
      ]),
      plateNumber: firstText(<dynamic>[
        json['plate_number'],
        profile['plate_number'],
      ]),
    );
  }
}

class BuyerRiderSnapshot {
  final BuyerOrderLocation? location;
  final BuyerRiderInfo? rider;

  const BuyerRiderSnapshot({this.location, this.rider});
}

class BuyerOrderParcelData {
  final String id;
  final String? trackingNumber;
  final String status;
  final String statusLabel;
  final String? sellerOrderNumber;
  final String? sellerName;
  final String? destination;
  final BuyerOrderLocation? riderLocation;
  final BuyerRiderInfo? rider;
  final List<BuyerOrderTimelineEvent> timeline;
  final List<String> deliveryProofAttemptIds;

  const BuyerOrderParcelData({
    required this.id,
    required this.status,
    required this.statusLabel,
    this.trackingNumber,
    this.sellerOrderNumber,
    this.sellerName,
    this.destination,
    this.riderLocation,
    this.rider,
    this.timeline = const <BuyerOrderTimelineEvent>[],
    this.deliveryProofAttemptIds = const <String>[],
  });

  BuyerOrderParcelData copyWith({
    String? status,
    String? statusLabel,
    BuyerOrderLocation? riderLocation,
    bool clearRiderLocation = false,
    BuyerRiderInfo? rider,
    bool clearRider = false,
    List<BuyerOrderTimelineEvent>? timeline,
  }) {
    return BuyerOrderParcelData(
      id: id,
      trackingNumber: trackingNumber,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      sellerOrderNumber: sellerOrderNumber,
      sellerName: sellerName,
      destination: destination,
      riderLocation: clearRiderLocation
          ? null
          : riderLocation ?? this.riderLocation,
      rider: clearRider ? null : rider ?? this.rider,
      timeline: timeline ?? this.timeline,
      deliveryProofAttemptIds: deliveryProofAttemptIds,
    );
  }

  factory BuyerOrderParcelData.fromApi(Map<String, dynamic> json) {
    final dynamic rawLocation = json['rider_location'];
    BuyerOrderLocation? riderLocation;
    if (rawLocation is Map) {
      final Map<String, dynamic> location = Map<String, dynamic>.from(
        rawLocation,
      );
      final double? latitude = double.tryParse(
        (location['latitude'] ?? '').toString(),
      );
      final double? longitude = double.tryParse(
        (location['longitude'] ?? '').toString(),
      );
      if (latitude != null && longitude != null) {
        riderLocation = BuyerOrderLocation(
          latitude: latitude,
          longitude: longitude,
          label: 'Rider location',
        );
      }
    }
    final dynamic rawRider =
        json['rider'] ?? json['rider_info'] ?? json['assigned_rider'];
    BuyerRiderInfo? rider;
    if (rawRider is Map) {
      final BuyerRiderInfo parsedRider = BuyerRiderInfo.fromApi(
        Map<String, dynamic>.from(rawRider),
      );
      if (parsedRider.hasVisibleInfo) rider = parsedRider;
    }
    final dynamic rawEvents = json['events'];
    final List<BuyerOrderTimelineEvent> timeline = rawEvents is List
        ? rawEvents
              .whereType<Map>()
              .map((Map raw) {
                final Map<String, dynamic> event = Map<String, dynamic>.from(
                  raw,
                );
                final DateTime? occurredAt = DateTime.tryParse(
                  (event['occurred_at'] ?? '').toString(),
                );
                return BuyerOrderTimelineEvent(
                  label:
                      (event['label'] ?? event['status'] ?? 'Shipment update')
                          .toString(),
                  time: occurredAt == null ? '' : _formatParcelTime(occurredAt),
                  done: true,
                  details: (event['notes'] ?? '').toString(),
                  occurredAt: occurredAt,
                );
              })
              .toList(growable: false)
        : const <BuyerOrderTimelineEvent>[];
    final dynamic rawAttempts = json['delivery_attempts'];
    final List<String> proofIds = rawAttempts is List
        ? rawAttempts
              .whereType<Map>()
              .where((Map attempt) => attempt['proof_available'] == true)
              .map((Map attempt) => (attempt['id'] ?? '').toString())
              .where((String id) => id.isNotEmpty)
              .toList(growable: false)
        : const <String>[];
    return BuyerOrderParcelData(
      id: (json['id'] ?? '').toString(),
      trackingNumber: json['tracking_number']?.toString(),
      status: (json['current_status'] ?? json['status'] ?? '').toString(),
      statusLabel:
          (json['status_label'] ?? json['current_status'] ?? 'Shipment update')
              .toString(),
      sellerOrderNumber: json['seller_order_number']?.toString(),
      sellerName: json['seller_name']?.toString(),
      destination: json['destination']?.toString(),
      riderLocation: riderLocation,
      rider: rider,
      timeline: timeline,
      deliveryProofAttemptIds: proofIds,
    );
  }
}

String _formatParcelTime(DateTime value) {
  final DateTime local = value.toLocal();
  const List<String> months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
  final String minute = local.minute.toString().padLeft(2, '0');
  final String period = local.hour >= 12 ? 'PM' : 'AM';
  return '${months[local.month - 1]} ${local.day}, ${local.year} · $hour:$minute $period';
}

BuyerOrderLocation? parseBuyerOrderLogisticsStop(Map<String, dynamic> row) {
  final dynamic rawFacility =
      row['logistics_center'] ??
      row['logisticsCenter'] ??
      row['center'] ??
      row['facility'] ??
      row['hub'];
  final Map<String, dynamic> facility = rawFacility is Map
      ? Map<String, dynamic>.from(rawFacility)
      : const <String, dynamic>{};
  final dynamic rawLocation =
      row['location'] ??
      facility['location'] ??
      facility['address'] ??
      row['address'] ??
      rawFacility;
  final Map<String, dynamic> location = rawLocation is Map
      ? Map<String, dynamic>.from(rawLocation)
      : row;
  final String name = <dynamic>[
    row['label'],
    row['name'],
    row['facility_name'],
    row['hub_name'],
    row['location_name'],
    row['current_center_name'],
    row['origin_center_name'],
    row['destination_center_name'],
    facility['business_name'],
    facility['name'],
    facility['label'],
    location['label'],
    location['name'],
    location['facility_name'],
    location['hub_name'],
    location['location_name'],
    rawFacility is String ? rawFacility : null,
    rawLocation is String ? rawLocation : null,
    row['notes'],
    row['details'],
    row['description'],
    row['message'],
  ].where((dynamic value) => value != null).join(' ').trim();
  final double? latitude = double.tryParse(
    (location['latitude'] ?? location['lat'] ?? location['y'] ?? '').toString(),
  );
  final double? longitude = double.tryParse(
    (location['longitude'] ??
            location['lng'] ??
            location['lon'] ??
            location['x'] ??
            '')
        .toString(),
  );
  if (latitude != null && longitude != null) {
    String? firstValue(Iterable<dynamic> values) {
      for (final dynamic value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final String? transferLegId = firstValue(<dynamic>[
      row['transfer_leg_id'],
      row['transferLegId'],
      row['leg_id'],
    ]);
    return BuyerOrderLocation(
      latitude: latitude,
      longitude: longitude,
      label: name.isEmpty ? 'Logistics hub' : name,
      id: firstValue(<dynamic>[row['id'], facility['id'], row['center_id']]),
      transferLegIds: transferLegId == null
          ? const <String>[]
          : <String>[transferLegId],
      sequenceNo: int.tryParse(
        (row['sequence_no'] ?? row['sequence'] ?? '').toString(),
      ),
      centerRole: firstValue(<dynamic>[row['center_role'], row['role']]),
      progressStatus: firstValue(<dynamic>[
        row['status'],
        row['progress_status'],
      ]),
    );
  }
  return null;
}

class BuyerOrderData {
  final String id;

  /// Human-readable order reference shown to buyers (for example, LK-...).
  final String? orderNumber;

  /// Seller-side reference included in order workflow notifications.
  final String? sellerOrderNumber;

  /// Buyer-facing grouping key:
  ///
  /// to-pay
  /// to-ship
  /// to-receive
  /// completed
  /// cancelled
  /// returns
  ///
  /// This is intentionally separate from [backendStatus].
  final String status;

  /// Actual Laravel order/workflow status when available.
  ///
  /// Examples:
  /// pending
  /// placed
  /// confirmed
  /// preparing
  /// shipping
  /// shipped
  /// delivered
  /// completed
  /// cancelled
  /// returns
  final String? backendStatus;

  final String statusLabel;

  final String payment;

  final String? paymentStatus;

  final List<BuyerOrderProductData> products;

  /// Seller-specific parts of a Laravel parent order.
  final List<BuyerSellerOrderData> sellerOrders;

  /// Independent shipment parcels attached to this order.
  final List<BuyerOrderParcelData> parcels;

  final double total;

  final String buyerName;
  final String? buyerContact;

  final String? sellerName;
  final int? sellerId;
  final String? sellerSlug;
  final String? sellerAvatarUrl;

  final String shippingAddress;

  final String? tracking;

  final String? shipmentId;

  final BuyerOrderLocation? orderLocation;

  final BuyerOrderLocation? sellerLocation;

  final BuyerOrderLocation? riderLocation;

  /// Logistics facilities visited before the parcel reaches the buyer.
  final List<BuyerOrderLocation> shipmentRouteStops;

  final List<BuyerOrderTimelineEvent> timeline;

  final List<String> deliveryProofImageUrls;

  final DateTime? createdAt;

  /// True only for UI preview orders generated from ProductsScreen.
  /// Preview orders are never submitted to Laravel and expose no actions.
  final bool isPreview;

  /// Optional explicit capability flags from Laravel.
  /// The server's delivery-PIN flag takes precedence; when it is absent,
  /// mobile applies the same status and destination checks as a fallback.
  final bool? allowCancel;
  final bool? allowMarkReceived;
  final bool? allowReview;
  final bool? allowReturnRequest;
  final DateTime? returnDeadline;
  final bool hasActiveReturnRequest;
  final bool canConfirmDeliveryPin;

  const BuyerOrderData({
    required this.id,
    required this.status,
    required this.statusLabel,
    required this.payment,
    required this.products,
    this.sellerOrders = const <BuyerSellerOrderData>[],
    this.parcels = const <BuyerOrderParcelData>[],
    required this.total,
    required this.buyerName,
    required this.shippingAddress,
    this.sellerName,
    this.sellerId,
    this.sellerSlug,
    this.sellerAvatarUrl,
    this.orderNumber,
    this.sellerOrderNumber,
    this.backendStatus,
    this.paymentStatus,
    this.buyerContact,
    this.tracking,
    this.shipmentId,
    this.orderLocation,
    this.sellerLocation,
    this.riderLocation,
    this.shipmentRouteStops = const <BuyerOrderLocation>[],
    this.timeline = const <BuyerOrderTimelineEvent>[],
    this.deliveryProofImageUrls = const <String>[],
    this.createdAt,
    this.isPreview = false,
    this.allowCancel,
    this.allowMarkReceived,
    this.allowReview,
    this.allowReturnRequest,
    this.returnDeadline,
    this.hasActiveReturnRequest = false,
    this.canConfirmDeliveryPin = false,
  });

  factory BuyerOrderData.fromApi(Map<String, dynamic> json) {
    BuyerOrderLocation? parseLocation(dynamic raw, String label) {
      dynamic source = raw;
      if (source is Map<String, dynamic>) {
        source = source['location'] ?? source;
      } else if (source is Map) {
        source = source['location'] ?? Map<String, dynamic>.from(source);
      }

      if (source is! Map) {
        return null;
      }

      final Map<String, dynamic> location = Map<String, dynamic>.from(source);
      final double? latitude = double.tryParse(
        (location['latitude'] ?? location['lat'] ?? location['y'] ?? '')
            .toString(),
      );
      final double? longitude = double.tryParse(
        (location['longitude'] ??
                location['lng'] ??
                location['lon'] ??
                location['x'] ??
                '')
            .toString(),
      );

      if (latitude == null || longitude == null) {
        return null;
      }

      return BuyerOrderLocation(
        latitude: latitude,
        longitude: longitude,
        label: label,
      );
    }

    final dynamic rawBuyer = json['buyer'] ?? json['user'];
    final Map<String, dynamic> buyer = rawBuyer is Map
        ? Map<String, dynamic>.from(rawBuyer)
        : const <String, dynamic>{};
    final dynamic rawItems =
        json['items'] ?? json['order_items'] ?? json['products'];
    final dynamic rawSeller = json['seller'] ?? json['store'] ?? json['shop'];
    final Map<String, dynamic> seller = rawSeller is Map
        ? Map<String, dynamic>.from(rawSeller)
        : const <String, dynamic>{};
    final dynamic rawSellerOrder = json['seller_order'] ?? json['sellerOrder'];
    final Map<String, dynamic> sellerOrder = rawSellerOrder is Map
        ? Map<String, dynamic>.from(rawSellerOrder)
        : const <String, dynamic>{};
    final dynamic rawSellerOrders =
        json['seller_orders'] ?? json['sellerOrders'];
    final List<BuyerSellerOrderData> sellerOrders = rawSellerOrders is List
        ? rawSellerOrders
              .whereType<Map>()
              .map(
                (Map item) => BuyerSellerOrderData.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <BuyerSellerOrderData>[];
    final dynamic rawParcels = json['parcels'] ?? json['shipments'];
    final List<BuyerOrderParcelData> parcels = rawParcels is List
        ? rawParcels
              .whereType<Map>()
              .map(
                (Map item) => BuyerOrderParcelData.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <BuyerOrderParcelData>[];
    final BuyerSellerOrderData? firstSellerOrder = sellerOrders.isEmpty
        ? null
        : sellerOrders.first;
    final dynamic rawShipment =
        json['shipment'] ?? json['parcel'] ?? json['latest_shipment'];
    final dynamic shipmentValue = rawShipment is List && rawShipment.isNotEmpty
        ? rawShipment.first
        : rawShipment;
    final Map<String, dynamic> shipment = shipmentValue is Map
        ? Map<String, dynamic>.from(shipmentValue)
        : const <String, dynamic>{};
    final dynamic rawFirstItem = rawItems is List && rawItems.isNotEmpty
        ? rawItems.first
        : null;
    final Map<String, dynamic> firstItem = rawFirstItem is Map
        ? Map<String, dynamic>.from(rawFirstItem)
        : const <String, dynamic>{};
    final dynamic rawFirstProduct = firstItem['product'];
    final Map<String, dynamic> firstProduct = rawFirstProduct is Map
        ? Map<String, dynamic>.from(rawFirstProduct)
        : firstItem;
    final dynamic rawFirstSeller =
        firstItem['seller'] ??
        firstItem['store'] ??
        firstProduct['seller'] ??
        firstProduct['store'];
    final Map<String, dynamic> firstSeller = rawFirstSeller is Map
        ? Map<String, dynamic>.from(rawFirstSeller)
        : const <String, dynamic>{};
    String? firstNonEmptyText(Iterable<dynamic> values) {
      for (final dynamic value in values) {
        final String text = value?.toString().trim() ?? '';
        if (text.isNotEmpty) return text;
      }
      return null;
    }

    final String? resolvedSellerName = firstNonEmptyText(<dynamic>[
      json['seller_name'],
      json['store_name'],
      json['shop_name'],
      seller['business_name'],
      seller['store_name'],
      seller['name'],
      firstItem['seller_name'],
      firstItem['store_name'],
      firstProduct['seller_name'],
      firstProduct['store_name'],
      firstSeller['business_name'],
      firstSeller['store_name'],
      firstSeller['name'],
      firstSellerOrder?.sellerName,
    ]);
    final String? resolvedSellerOrderNumber = firstNonEmptyText(<dynamic>[
      json['seller_order_number'],
      json['sellerOrderNumber'],
      json['seller_order_id'],
      json['seller_order'] is String ? json['seller_order'] : null,
      sellerOrder['seller_order_number'],
      sellerOrder['order_number'],
      sellerOrder['number'],
      sellerOrder['id'],
      firstItem['seller_order_number'],
      firstProduct['seller_order_number'],
      firstSellerOrder?.orderNumber,
    ]);
    final int? resolvedSellerId = int.tryParse(
      <dynamic>[
            json['seller_user_id'],
            json['seller_id'],
            json['store_id'],
            seller['user_id'],
            seller['seller_user_id'],
            seller['id'],
            seller['seller_id'],
            firstItem['seller_user_id'],
            firstItem['seller_id'],
            firstProduct['seller_user_id'],
            firstProduct['seller_id'],
            firstSeller['user_id'],
            firstSeller['seller_user_id'],
            firstSeller['id'],
            firstSeller['seller_id'],
            firstSellerOrder?.sellerId,
          ]
          .firstWhere((dynamic value) => value != null, orElse: () => '')
          .toString(),
    );
    final String? resolvedSellerSlug = firstNonEmptyText(<dynamic>[
      json['seller_slug'],
      json['store_slug'],
      seller['slug'],
      seller['store_slug'],
      firstItem['seller_slug'],
      firstProduct['seller_slug'],
      firstSeller['slug'],
      firstSeller['store_slug'],
      firstSellerOrder?.sellerSlug,
    ]);
    final String? resolvedSellerAvatar = firstNonEmptyText(<dynamic>[
      json['seller_avatar'],
      json['seller_avatar_url'],
      seller['logo_url'],
      seller['avatar_url'],
      firstItem['seller_avatar'],
      firstItem['seller_avatar_url'],
      firstProduct['seller_avatar'],
      firstProduct['seller_avatar_url'],
      firstSeller['logo_url'],
      firstSeller['avatar_url'],
      firstSellerOrder?.sellerAvatarUrl,
    ]);
    final List<BuyerOrderProductData> products = rawItems is List
        ? rawItems
              .whereType<Map>()
              .map((Map item) {
                final Map<String, dynamic> product = Map<String, dynamic>.from(
                  item,
                );
                final dynamic nestedProduct = product['product'];
                final Map<String, dynamic> details = nestedProduct is Map
                    ? Map<String, dynamic>.from(nestedProduct)
                    : product;
                final String? primaryImage =
                    (product['image_url'] ??
                            details['image_url'] ??
                            details['image'])
                        ?.toString();
                final List<String> galleryImages = _parseOrderImageUrls(
                  product['images'] ??
                      details['images'] ??
                      product['gallery'] ??
                      details['gallery'] ??
                      product['photos'] ??
                      details['photos'],
                );
                final List<String> resolvedImages = <String>[];
                for (final String value in <String>[
                  ?primaryImage,
                  ...galleryImages,
                ]) {
                  final String resolved = AppConfig.resolveMediaUrl(value);
                  if (resolved.isNotEmpty &&
                      !resolvedImages.contains(resolved)) {
                    resolvedImages.add(resolved);
                  }
                }

                return BuyerOrderProductData(
                  id: (product['id'] ?? details['id'] ?? '').toString(),
                  productId: int.tryParse(
                    (product['product_id'] ??
                            details['product_id'] ??
                            details['id'] ??
                            '')
                        .toString(),
                  ),
                  name: (product['name'] ?? details['name'] ?? 'Product')
                      .toString(),
                  variant: _formatOrderVariant(
                    product['variant'] ??
                        product['variation'] ??
                        product['variant_name'] ??
                        product['variation_name'] ??
                        product['attributes'] ??
                        details['variant'] ??
                        details['attributes'],
                  ),
                  imageUrl: resolvedImages.isEmpty
                      ? null
                      : resolvedImages.first,
                  imageUrls: resolvedImages,
                  price:
                      double.tryParse(
                        (product['price'] ?? product['unit_price'] ?? 0)
                            .toString(),
                      ) ??
                      0,
                  quantity:
                      int.tryParse((product['quantity'] ?? 1).toString()) ?? 1,
                );
              })
              .toList(growable: false)
        : const <BuyerOrderProductData>[];

    final dynamic rawAddress = json['shipping_address'] ?? json['address'];
    final String address = rawAddress is Map
        ? <dynamic>[
                rawAddress['house_number'],
                rawAddress['street'],
                rawAddress['barangay'],
                rawAddress['municipality'],
                rawAddress['province'],
                rawAddress['postal_code'],
              ]
              .where(
                (dynamic value) =>
                    value != null && value.toString().trim().isNotEmpty,
              )
              .join(', ')
        : (rawAddress ?? '').toString();
    final BuyerOrderLocation? orderLocation = parseLocation(
      rawAddress,
      'Delivery destination',
    );
    final dynamic rawSellerLocation =
        json['seller_location'] ??
        json['seller_address'] ??
        shipment['seller_location'];
    final Map<String, dynamic> sellerLocationData = rawSellerLocation is Map
        ? Map<String, dynamic>.from(rawSellerLocation)
        : const <String, dynamic>{};
    final BuyerOrderLocation? sellerLocation = parseLocation(
      rawSellerLocation,
      (sellerLocationData['label'] ??
              sellerLocationData['name'] ??
              'Seller pickup location')
          .toString(),
    );
    final dynamic rawTimeline =
        json['timeline'] ??
        json['tracking_timeline'] ??
        json['shipment_events'] ??
        shipment['timeline'] ??
        shipment['tracking_timeline'] ??
        shipment['events'];
    final List<Map<String, dynamic>> timelineRows = rawTimeline is List
        ? rawTimeline
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final List<String> deliveryProofImageUrls = parseBuyerDeliveryProofUrls(
      <Map<String, dynamic>>[json, shipment, ...timelineRows],
    );
    final List<BuyerOrderTimelineEvent> timeline = timelineRows.isNotEmpty
        ? timelineRows
              .map((Map<String, dynamic> event) {
                final String rawLabel =
                    (event['label'] ??
                            event['status_label'] ??
                            event['status'] ??
                            event['current_status'] ??
                            'Shipment update')
                        .toString()
                        .trim();
                final String label = rawLabel
                    .replaceAll(RegExp(r'[_-]+'), ' ')
                    .replaceAll(RegExp(r'\s+'), ' ')
                    .split(' ')
                    .where((String word) => word.isNotEmpty)
                    .map(
                      (String word) =>
                          '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
                    )
                    .join(' ');
                final dynamic rawDetails =
                    event['notes'] ??
                    event['details'] ??
                    event['description'] ??
                    event['message'] ??
                    event['location_name'] ??
                    event['facility_name'] ??
                    event['location'];
                final String noteDetails = rawDetails is Map
                    ? (rawDetails['label'] ??
                              rawDetails['name'] ??
                              rawDetails['facility_name'] ??
                              rawDetails['location_name'] ??
                              '')
                          .toString()
                          .trim()
                    : rawDetails?.toString().trim() ?? '';
                final BuyerOrderLocation? eventLocation =
                    parseBuyerOrderLogisticsStop(event);
                final dynamic rawEventLocation =
                    event['location'] ??
                    event['logistics_center'] ??
                    event['center'];
                final Map<String, dynamic> eventLocationData =
                    rawEventLocation is Map
                    ? Map<String, dynamic>.from(rawEventLocation)
                    : const <String, dynamic>{};
                final String eventLocationName =
                    (event['location_name'] ??
                            event['facility_name'] ??
                            event['current_center_name'] ??
                            eventLocationData['business_name'] ??
                            eventLocationData['name'] ??
                            eventLocationData['label'] ??
                            '')
                        .toString()
                        .trim();
                final String details = <String>[
                  noteDetails,
                  if ((eventLocation?.label ?? eventLocationName).isNotEmpty &&
                      !noteDetails.toLowerCase().contains(
                        (eventLocation?.label ?? eventLocationName)
                            .toLowerCase(),
                      ))
                    eventLocation?.label ?? eventLocationName,
                ].where((String value) => value.isNotEmpty).join(' | ');
                return BuyerOrderTimelineEvent(
                  label: label.isEmpty ? 'Shipment update' : label,
                  time: _formatOrderTimelineTime(
                    event['occurred_at'] ??
                        event['created_at'] ??
                        event['time'],
                  ),
                  done: event['done'] is bool ? event['done'] as bool : true,
                  details: details,
                  occurredAt: DateTime.tryParse(
                    (event['occurred_at'] ??
                            event['created_at'] ??
                            event['time'] ??
                            '')
                        .toString(),
                  ),
                );
              })
              .toList(growable: false)
        : const <BuyerOrderTimelineEvent>[];
    final dynamic rawRouteStops =
        json['shipment_route_stops'] ??
        json['route_stops'] ??
        json['logistics_stops'] ??
        json['shipment_route'] ??
        shipment['shipment_route_stops'] ??
        shipment['route_stops'] ??
        shipment['logistics_stops'] ??
        shipment['stops'];
    final List<Map<String, dynamic>> routeStopRows = rawRouteStops is List
        ? rawRouteStops
              .whereType<Map>()
              .map((Map item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const <Map<String, dynamic>>[];
    final List<BuyerOrderLocation> shipmentRouteStops = <BuyerOrderLocation>[];
    void addRouteStop(BuyerOrderLocation? stop) {
      if (stop == null) return;
      final int existingIndex = shipmentRouteStops.indexWhere(
        (BuyerOrderLocation existing) =>
            existing.latitude == stop.latitude &&
            existing.longitude == stop.longitude,
      );
      if (existingIndex >= 0) {
        final BuyerOrderLocation existing = shipmentRouteStops[existingIndex];
        final List<String> transferLegIds = <String>{
          ...existing.transferLegIds,
          ...stop.transferLegIds,
        }.toList(growable: false);
        if (transferLegIds.length != existing.transferLegIds.length ||
            existing.id == null && stop.id != null ||
            existing.sequenceNo == null && stop.sequenceNo != null ||
            existing.centerRole == null && stop.centerRole != null ||
            existing.progressStatus == null && stop.progressStatus != null) {
          shipmentRouteStops[existingIndex] = existing.copyWith(
            id: existing.id ?? stop.id,
            transferLegIds: transferLegIds,
            sequenceNo: existing.sequenceNo ?? stop.sequenceNo,
            centerRole: existing.centerRole ?? stop.centerRole,
            progressStatus: existing.progressStatus ?? stop.progressStatus,
          );
        }
        return;
      }
      shipmentRouteStops.add(stop);
    }

    for (final Map<String, dynamic> stop in routeStopRows) {
      addRouteStop(parseBuyerOrderLogisticsStop(stop));
    }

    final dynamic rawTransferLegs =
        json['transfer_legs'] ?? shipment['transfer_legs'];
    if (rawTransferLegs is List) {
      final List<Map<String, dynamic>> transferLegs = rawTransferLegs
          .whereType<Map>()
          .map((Map item) => Map<String, dynamic>.from(item))
          .toList(growable: false);
      for (final Map<String, dynamic> leg in transferLegs) {
        addRouteStop(
          parseBuyerOrderLogisticsStop(<String, dynamic>{
            'logistics_center':
                leg['origin_center'] ??
                leg['origin_logistics_center'] ??
                leg['origin'],
            'name': leg['origin_center_name'],
            'transfer_leg_id':
                leg['id'] ?? leg['transfer_leg_id'] ?? leg['leg_id'],
            'sequence_no': leg['sequence_no'] ?? leg['sequence'],
            'center_role': 'origin',
            'status': leg['status'],
          }),
        );
        addRouteStop(
          parseBuyerOrderLogisticsStop(<String, dynamic>{
            'logistics_center':
                leg['destination_center'] ??
                leg['destination_logistics_center'] ??
                leg['destination'],
            'name': leg['destination_center_name'],
            'transfer_leg_id':
                leg['id'] ?? leg['transfer_leg_id'] ?? leg['leg_id'],
            'sequence_no': leg['sequence_no'] ?? leg['sequence'],
            'center_role': 'destination',
            'status': leg['status'],
          }),
        );
      }
    }

    if (shipmentRouteStops.isEmpty) {
      for (final Map<String, dynamic> event in timelineRows) {
        addRouteStop(parseBuyerOrderLogisticsStop(event));
      }
    }
    final BuyerOrderLocation? currentLogisticsCenter =
        parseBuyerOrderLogisticsStop(<String, dynamic>{
          'logistics_center':
              json['current_logistics_center'] ??
              json['logistics_center'] ??
              shipment['current_logistics_center'] ??
              shipment['logistics_center'],
          'current_center_name':
              json['current_center_name'] ?? shipment['current_center_name'],
        });
    if (currentLogisticsCenter != null &&
        !shipmentRouteStops.any(
          (BuyerOrderLocation stop) =>
              stop.latitude == currentLogisticsCenter.latitude &&
              stop.longitude == currentLogisticsCenter.longitude,
        )) {
      shipmentRouteStops.add(currentLogisticsCenter);
    }
    final String backendStatus =
        (json['status'] ?? json['order_status'] ?? 'pending').toString();
    String normalizeStatus(dynamic value) => value
        .toString()
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    const Set<String> terminalStatuses = <String>{
      'delivered',
      'completed',
      'cancelled',
      'canceled',
      'returned',
      'refunded',
    };
    final dynamic serverPinEligibility = json['can_confirm_delivery_pin'];
    final List<String> shipmentStatuses = <String>[
      ...parcels.map((BuyerOrderParcelData parcel) => parcel.status),
      if (shipment['current_status'] != null)
        shipment['current_status'].toString(),
      if (shipment['status'] != null) shipment['status'].toString(),
    ].map(normalizeStatus).where((String value) => value.isNotEmpty).toList();
    final bool canConfirmDeliveryPin = serverPinEligibility is bool
        ? serverPinEligibility
        : address.trim().isNotEmpty &&
              parseLocation(rawAddress, 'Delivery destination') == null &&
              !terminalStatuses.contains(normalizeStatus(backendStatus)) &&
              !shipmentStatuses.any(terminalStatuses.contains);

    return BuyerOrderData(
      id: (json['id'] ?? json['order_number'] ?? '').toString(),
      orderNumber: json['order_number']?.toString(),
      sellerOrderNumber: resolvedSellerOrderNumber,
      status: (json['buyer_status'] ?? backendStatus).toString(),
      backendStatus: backendStatus,
      statusLabel:
          (json['buyer_status_label'] ?? json['status_label'] ?? backendStatus)
              .toString(),
      payment: (json['payment_method'] ?? json['payment'] ?? 'Not specified')
          .toString(),
      paymentStatus: json['payment_status']?.toString(),
      products: products,
      sellerOrders: sellerOrders,
      parcels: parcels,
      total:
          double.tryParse(
            (json['total'] ?? json['grand_total'] ?? json['order_total'] ?? 0)
                .toString(),
          ) ??
          0,
      buyerName: (json['buyer_name'] ?? buyer['name'] ?? '').toString(),
      buyerContact: (json['buyer_contact'] ?? buyer['contact_number'])
          ?.toString(),
      sellerName: resolvedSellerName,
      sellerId: resolvedSellerId,
      sellerSlug: resolvedSellerSlug,
      sellerAvatarUrl: resolvedSellerAvatar == null
          ? null
          : AppConfig.resolveMediaUrl(resolvedSellerAvatar),
      shippingAddress: address,
      tracking:
          (json['tracking_number'] ??
                  json['tracking'] ??
                  shipment['tracking_number'] ??
                  shipment['tracking_code'] ??
                  shipment['tracking'])
              ?.toString(),
      shipmentId:
          (json['shipment_id'] ??
                  shipment['shipment_id'] ??
                  shipment['id'] ??
                  '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (json['shipment_id'] ?? shipment['shipment_id'] ?? shipment['id'])
                .toString(),
      orderLocation:
          parseLocation(
            json['order_location'] ??
                json['shipment_location'] ??
                json['current_order_location'],
            'Order location',
          ) ??
          orderLocation,
      sellerLocation: sellerLocation,
      riderLocation: parseLocation(
        json['rider_location'] ??
            json['driver_location'] ??
            json['current_rider_location'] ??
            json['rider'] ??
            json['driver'],
        'Rider location',
      ),
      shipmentRouteStops: shipmentRouteStops,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()),
      timeline: timeline,
      deliveryProofImageUrls: deliveryProofImageUrls,
      allowCancel: json['allow_cancel'] as bool?,
      allowMarkReceived: json['allow_mark_received'] as bool?,
      allowReview: json['allow_review'] as bool?,
      allowReturnRequest: json['allow_return_request'] as bool?,
      returnDeadline: DateTime.tryParse(
        (json['return_deadline'] ?? '').toString(),
      ),
      hasActiveReturnRequest: json['has_active_return_request'] == true,
      canConfirmDeliveryPin: canConfirmDeliveryPin,
    );
  }

  String get normalizedStatus {
    return (backendStatus ?? status)
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  String get tabStatus {
    final String buyerStatus = status.trim().toLowerCase();

    const Set<String> supported = <String>{
      'to-pay',
      'to-ship',
      'to-receive',
      'completed',
      'cancelled',
      'returns',
    };

    if (supported.contains(buyerStatus)) {
      return buyerStatus;
    }

    switch (normalizedStatus) {
      case 'pending':
      case 'placed':
        return 'to-pay';

      case 'confirmed':
      case 'preparing':
      case 'ready_for_pickup':
        return 'to-ship';

      case 'shipping':
      case 'shipped':
      case 'in_transit':
      case 'out_for_delivery':
      case 'delivered':
        return 'to-receive';

      case 'completed':
        return 'completed';

      case 'cancelled':
      case 'canceled':
        return 'cancelled';

      case 'returns':
      case 'return_requested':
      case 'refund_requested':
      case 'returned':
      case 'refunded':
        return 'returns';

      default:
        return buyerStatus;
    }
  }

  bool get canCancel {
    if (allowCancel != null) {
      return allowCancel!;
    }

    const Set<String> cancellable = <String>{
      'pending',
      'to_process',
      'placed',
      'confirmed',
      'preparing',
    };

    if (backendStatus != null) {
      return cancellable.contains(normalizedStatus);
    }

    /// Compatibility with the first Flutter page before the
    /// backend status is exposed to mobile.
    return status == 'to-pay';
  }

  bool get canMarkReceived {
    if (allowMarkReceived != null) {
      return allowMarkReceived!;
    }

    if (normalizedStatus != 'processing' || hasActiveReturnRequest) {
      return false;
    }

    // Match Laravel's all-seller-orders/all-shipments eligibility check.
    // Without grouped seller orders, mobile cannot confirm that each seller
    // order has a parcel, so it fails closed and relies on Laravel's flag.
    if (sellerOrders.isEmpty) {
      return false;
    }

    return sellerOrders.every((BuyerSellerOrderData sellerOrder) {
      return sellerOrder.parcels.isNotEmpty &&
          sellerOrder.parcels.every(
            (BuyerOrderParcelData parcel) =>
                parcel.status.trim().toLowerCase().replaceAll(
                  RegExp(r'[-\s]+'),
                  '_',
                ) ==
                'delivered',
          );
    });
  }

  bool get canReview {
    if (allowReview != null) {
      return allowReview!;
    }

    return normalizedStatus == 'completed' || status == 'completed';
  }

  bool get canRequestReturn {
    if (allowReturnRequest != null) {
      return allowReturnRequest!;
    }

    const Set<String> eligible = <String>{'shipping', 'shipped', 'completed'};

    return eligible.contains(normalizedStatus);
  }

  DateTime? get returnDeadlineForDisplay {
    if (returnDeadline != null) {
      return returnDeadline;
    }

    final List<BuyerOrderTimelineEvent> events = <BuyerOrderTimelineEvent>[
      ...timeline,
      ...parcels.expand((BuyerOrderParcelData parcel) => parcel.timeline),
    ];
    DateTime? latestDeliveredAt;
    for (final BuyerOrderTimelineEvent event in events) {
      final String eventStatus = event.label.trim().toLowerCase().replaceAll(
        RegExp(r'[\s_-]+'),
        '',
      );
      final DateTime? occurredAt = event.occurredAt;
      if (eventStatus == 'delivered' &&
          occurredAt != null &&
          (latestDeliveredAt == null ||
              occurredAt.isAfter(latestDeliveredAt))) {
        latestDeliveredAt = occurredAt;
      }
    }

    return latestDeliveredAt?.add(const Duration(days: 5));
  }

  String get returnRequestSubtitle {
    if (hasActiveReturnRequest) {
      return 'A return or refund request is already in progress.';
    }

    final DateTime? deadline = returnDeadlineForDisplay;
    if (canRequestReturn) {
      return deadline == null
          ? 'You can request a return or refund.'
          : 'Submit by ' + _formatBuyerReturnDate(deadline) + '.';
    }

    if (normalizedStatus == 'cancelled' || normalizedStatus == 'canceled') {
      return 'Cancelled orders are not eligible for return or refund.';
    }

    final bool allParcelsDelivered =
        parcels.isNotEmpty &&
        parcels.every((BuyerOrderParcelData parcel) {
          final String parcelStatus = parcel.status
              .trim()
              .toLowerCase()
              .replaceAll(RegExp(r'[- ]+'), '_');
          return parcelStatus == 'delivered' || parcelStatus == 'completed';
        });
    if (parcels.isNotEmpty && !allParcelsDelivered) {
      return 'Available after all parcels are delivered.';
    }

    if (deadline != null && DateTime.now().isAfter(deadline)) {
      return 'Return window ended ' + _formatBuyerReturnDate(deadline) + '.';
    }

    if (parcels.isEmpty) {
      return 'Available after delivery.';
    }

    return 'Return or refund is not available for this order right now.';
  }

  BuyerOrderData copyWith({
    String? tracking,
    bool clearTracking = false,
    String? shipmentId,
    String? status,
    String? backendStatus,
    String? statusLabel,
    String? paymentStatus,
    List<BuyerOrderTimelineEvent>? timeline,
    List<BuyerOrderParcelData>? parcels,
    BuyerOrderLocation? orderLocation,
    BuyerOrderLocation? sellerLocation,
    BuyerOrderLocation? riderLocation,
    List<BuyerOrderLocation>? shipmentRouteStops,
    bool clearRiderLocation = false,
    bool clearSellerLocation = false,
    bool clearOrderLocation = false,
    bool? allowCancel,
    bool? allowMarkReceived,
    bool? allowReview,
    bool? allowReturnRequest,
    DateTime? returnDeadline,
    bool? hasActiveReturnRequest,
    bool? canConfirmDeliveryPin,
    bool? isPreview,
    List<String>? deliveryProofImageUrls,
  }) {
    return BuyerOrderData(
      id: id,
      orderNumber: orderNumber,
      sellerOrderNumber: sellerOrderNumber,
      status: status ?? this.status,
      backendStatus: backendStatus ?? this.backendStatus,
      statusLabel: statusLabel ?? this.statusLabel,
      payment: payment,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      products: products,
      sellerOrders: sellerOrders,
      parcels: parcels ?? this.parcels,
      total: total,
      buyerName: buyerName,
      buyerContact: buyerContact,
      shippingAddress: shippingAddress,
      tracking: clearTracking ? null : tracking ?? this.tracking,
      shipmentId: shipmentId ?? this.shipmentId,
      orderLocation: clearOrderLocation
          ? null
          : orderLocation ?? this.orderLocation,
      sellerLocation: clearSellerLocation
          ? null
          : sellerLocation ?? this.sellerLocation,
      riderLocation: clearRiderLocation
          ? null
          : riderLocation ?? this.riderLocation,
      shipmentRouteStops: shipmentRouteStops ?? this.shipmentRouteStops,
      timeline: timeline ?? this.timeline,
      deliveryProofImageUrls:
          deliveryProofImageUrls ?? this.deliveryProofImageUrls,
      createdAt: createdAt,
      isPreview: isPreview ?? this.isPreview,
      allowCancel: allowCancel ?? this.allowCancel,
      allowMarkReceived: allowMarkReceived ?? this.allowMarkReceived,
      allowReview: allowReview ?? this.allowReview,
      allowReturnRequest: allowReturnRequest ?? this.allowReturnRequest,
      returnDeadline: returnDeadline ?? this.returnDeadline,
      hasActiveReturnRequest:
          hasActiveReturnRequest ?? this.hasActiveReturnRequest,
      canConfirmDeliveryPin:
          canConfirmDeliveryPin ?? this.canConfirmDeliveryPin,
    );
  }

  static List<String> _parseOrderImageUrls(dynamic value) {
    if (value is! List) {
      return const <String>[];
    }

    final List<String> urls = <String>[];
    for (final dynamic item in value) {
      String raw = '';
      if (item is Map) {
        final Map<String, dynamic> image = Map<String, dynamic>.from(item);
        raw =
            (image['url'] ??
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

  static String _formatOrderTimelineTime(dynamic value) {
    final DateTime? parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) {
      return value?.toString() ?? '';
    }
    final DateTime local = parsed.toLocal();
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final int hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}\n$hour:$minute $period';
  }
}

class BuyerOrderReviewRequest {
  final BuyerOrderData order;

  final BuyerOrderProductData product;

  final int rating;

  final int riderRating;

  final String riderReview;

  final String review;

  final List<XFile> photos;

  /// The Laravel endpoint locks numeric ratings and photos after the first
  /// submission, but still allows the review text to be edited.
  final bool isTextUpdate;

  const BuyerOrderReviewRequest({
    required this.order,
    required this.product,
    required this.rating,
    required this.riderRating,
    required this.riderReview,
    required this.review,
    required this.photos,
    this.isTextUpdate = false,
  });
}

class _SubmittedProductReview {
  final int rating;
  final int riderRating;
  final String riderReview;
  final String review;
  final List<XFile> photos;

  const _SubmittedProductReview({
    required this.rating,
    required this.riderRating,
    required this.riderReview,
    required this.review,
    required this.photos,
  });
}

class BuyerOrderReturnRequest {
  final BuyerOrderData order;
  final String issueCategory;
  final String issueReason;
  final String description;
  final String refundMethod;
  final Map<String, int> quantitiesByItem;
  final String buyerEmail;
  final List<XFile> evidence;

  const BuyerOrderReturnRequest({
    required this.order,
    required this.issueCategory,
    required this.issueReason,
    required this.description,
    this.refundMethod = 'original_payment_method',
    required this.quantitiesByItem,
    required this.buyerEmail,
    required this.evidence,
  });
}

typedef CancelOrderCallback =
    Future<void> Function(BuyerOrderData order, String reason, String note);

typedef ReceiveOrderCallback = Future<void> Function(BuyerOrderData order);
typedef ConfirmOrderDeliveryPinCallback =
    Future<void> Function(
      BuyerOrderData order,
      double latitude,
      double longitude,
    );
typedef BuyAgainCallback =
    Future<Map<String, dynamic>> Function(BuyerOrderData order);

/// Legacy callback kept so existing page wiring does not
/// immediately break.
typedef SubmitReviewCallback =
    Future<void> Function(BuyerOrderData order, int rating, String review);

/// Preferred product-specific review callback.
typedef SubmitProductReviewCallback =
    Future<void> Function(BuyerOrderReviewRequest request);

/// Legacy callback.
typedef SubmitReturnCallback =
    Future<void> Function(
      BuyerOrderData order,
      String requestType,
      String reason,
      String details,
    );

/// Preferred request-object callback.
typedef SubmitOrderReturnCallback =
    Future<String?> Function(BuyerOrderReturnRequest request);

typedef BuyerOrderCallback = void Function(BuyerOrderData order);

typedef OrdersRefreshCallback = Future<List<BuyerOrderData>> Function();
typedef PickReturnEvidenceCallback = Future<List<XFile>> Function();

class OrdersScreen extends StatefulWidget {
  final List<BuyerOrderData> orders;

  /// Optional catalog products from ProductsScreen.
  ///
  /// If [orders] is empty and this list is supplied, these products can
  /// populate the preview cards. If it is empty too, the screen falls back
  /// to built-in sample orders so the final Orders UI can still be inspected
  /// before the Laravel mobile orders API/database wiring is finished.
  final List<BuyerProduct> previewProducts;

  /// Set to false once you want a truly empty state instead of sample orders.
  final bool showProductPreviewWhenEmpty;

  final BuyerOrdersMode initialMode;

  final String? selectedOrderId;

  final BuyerOrderTab initialTab;

  final String? buyerNotice;

  final VoidCallback? onBack;
  final VoidCallback? onShopProducts;
  final VoidCallback? onViewReturns;
  final VoidCallback? onTrackByNumber;

  final BuyerOrderCallback? onTrackOrder;
  final BuyerOrderCallback? onOpenOrderDetails;
  final BuyerOrderCallback? onContactSeller;
  final BuyerOrderCallback? onViewStore;
  final BuyerOrderCallback? onOpenHelpCenter;

  final CancelOrderCallback? onCancelOrder;
  final ReceiveOrderCallback? onReceiveOrder;
  final ConfirmOrderDeliveryPinCallback? onConfirmDeliveryPin;
  final BuyAgainCallback? onBuyAgain;

  /// Legacy order-level review callback.
  final SubmitReviewCallback? onSubmitReview;

  /// Preferred callback because reviews belong to a specific
  /// product inside the order.
  final SubmitProductReviewCallback? onSubmitProductReview;

  /// Legacy return callback.
  final SubmitReturnCallback? onSubmitReturn;

  /// Preferred return request callback.
  final SubmitOrderReturnCallback? onSubmitReturnRequest;

  final PickReturnEvidenceCallback? pickReturnEvidence;

  final OrdersRefreshCallback? onRefresh;

  const OrdersScreen({
    super.key,
    this.orders = const <BuyerOrderData>[],
    this.previewProducts = const <BuyerProduct>[],
    this.showProductPreviewWhenEmpty = true,
    this.initialMode = BuyerOrdersMode.overview,
    this.selectedOrderId,
    this.initialTab = BuyerOrderTab.all,
    this.buyerNotice,
    this.onBack,
    this.onShopProducts,
    this.onViewReturns,
    this.onTrackByNumber,
    this.onTrackOrder,
    this.onOpenOrderDetails,
    this.onContactSeller,
    this.onViewStore,
    this.onOpenHelpCenter,
    this.onCancelOrder,
    this.onReceiveOrder,
    this.onConfirmDeliveryPin,
    this.onBuyAgain,
    this.onSubmitReview,
    this.onSubmitProductReview,
    this.onSubmitReturn,
    this.onSubmitReturnRequest,
    this.pickReturnEvidence,
    this.onRefresh,
  });

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _soft = ShopColors.soft;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _muted = ShopColors.muted;

  static const Color _muted2 = ShopColors.faint;

  static const Color _tan = ShopColors.tan;

  static const Color _danger = Color(0xFFB42318);

  static const Color _star = Color(0xFFC88418);

  late List<BuyerOrderData> _orders;

  late BuyerOrdersMode _mode;
  late BuyerOrderTab _activeTab;

  String? _selectedOrderId;

  String? _selectedReviewProductId;

  bool _receivingOrder = false;
  final Set<String> _confirmingDeliveryPinOrderIds = <String>{};
  bool _submittingReview = false;
  String? _reviewNotice;
  bool _reviewNoticeIsError = false;
  bool _submittingReturn = false;
  String? _returnSubmissionError;

  final GlobalKey<FormState> _reviewFormKey = GlobalKey<FormState>();

  final GlobalKey<FormState> _returnFormKey = GlobalKey<FormState>();

  final TextEditingController _reviewController = TextEditingController();

  final TextEditingController _riderReviewController = TextEditingController();

  final TextEditingController _returnDetailsController =
      TextEditingController();
  final TextEditingController _returnEmailController = TextEditingController();

  int _rating = 5;
  int _riderRating = 5;
  List<XFile> _reviewPhotos = <XFile>[];

  String? _returnIssueCategory;
  String? _returnReason;
  String _returnRefundMethod = 'original_payment_method';
  final Map<String, int> _returnQuantities = <String, int>{};
  List<XFile> _returnEvidence = <XFile>[];
  bool _confirmReturnCashTerms = false;
  bool _confirmReturnRequest = false;

  final Set<String> _reviewedProductIds = <String>{};
  final Map<String, _SubmittedProductReview> _submittedReviews =
      <String, _SubmittedProductReview>{};

  static const Map<String, String> _returnIssueLabels = <String, String>{
    'DAMAGED': 'Received damaged item(s)',
    'DEFECTIVE': 'Product is defective / does not work',
    'INCORRECT': 'Received incorrect item(s)',
    'MISSING': 'Did not receive some/all of the item(s)',
    'OTHER': 'Others',
  };

  static const Map<String, List<String>> _returnIssueReasons =
      <String, List<String>>{
        'DAMAGED': <String>[
          'Scratched item',
          'Bent item',
          'Shattered item',
          'Cracked item',
          'Dented item',
          'Torn or ripped item',
          'Other physical damage',
        ],
        'DEFECTIVE': <String>[
          'Product does not turn on',
          'Product is not functioning properly',
          'Product stopped working',
          'Some functions/features do not work',
          'Product is defective upon arrival',
          'Other product defect',
        ],
        'INCORRECT': <String>[
          'Wrong product',
          'Wrong variation',
          'Wrong color',
          'Wrong size',
          'Wrong model',
          'Wrong quantity/item sent',
        ],
        'MISSING': <String>[
          'Parcel was not delivered',
          'Missing part of the order',
          'Missing item(s) from the parcel',
          'Empty parcel received',
        ],
        'OTHER': <String>[
          'I want to return the item in its original/sealed condition.',
        ],
      };

  final List<String> _cancelReasons = const <String>[
    'Changed my mind',
    'Need to change address',
    'Found a better option',
    'Payment issue',
    'Ordered by mistake',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

    _orders = _resolveInitialOrders();

    _mode = widget.initialMode;

    _activeTab = widget.initialTab;

    _selectedOrderId = widget.selectedOrderId;

    _syncSelectedReviewProduct();
  }

  @override
  void didUpdateWidget(covariant OrdersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.orders != widget.orders ||
        oldWidget.previewProducts != widget.previewProducts ||
        oldWidget.showProductPreviewWhenEmpty !=
            widget.showProductPreviewWhenEmpty) {
      _orders = _resolveInitialOrders();

      _syncSelectedReviewProduct();
    }

    if (oldWidget.selectedOrderId != widget.selectedOrderId) {
      _selectedOrderId = widget.selectedOrderId;

      _syncSelectedReviewProduct();
    }

    if (oldWidget.initialMode != widget.initialMode) {
      _mode = widget.initialMode;
    }

    if (oldWidget.initialTab != widget.initialTab) {
      _activeTab = widget.initialTab;
    }
  }

  bool get _usingProductPreview {
    return widget.orders.isEmpty && widget.showProductPreviewWhenEmpty;
  }

  List<BuyerOrderData> _resolveInitialOrders() {
    if (widget.orders.isNotEmpty) {
      return List<BuyerOrderData>.from(widget.orders);
    }

    if (!widget.showProductPreviewWhenEmpty) {
      return <BuyerOrderData>[];
    }

    if (widget.previewProducts.isNotEmpty) {
      return _buildProductPreviewOrders(widget.previewProducts);
    }

    return _buildBuiltInPreviewOrders();
  }

  List<BuyerOrderData> _buildProductPreviewOrders(List<BuyerProduct> products) {
    final List<BuyerProduct> preview = products.take(5).toList(growable: false);

    return List<BuyerOrderData>.generate(preview.length, (int index) {
      final BuyerProduct product = preview[index];

      final bool completed = index == 4;

      final DateTime placedAt = DateTime(
        2026,
        9,
        24 - index,
        index == 3 ? 7 : 13,
        index == 3 ? 14 : 31,
      );

      return BuyerOrderData(
        id: '${5 - index}',
        status: completed ? 'completed' : 'to-ship',
        backendStatus: completed ? 'completed' : 'preparing',
        statusLabel: completed ? 'Completed' : 'To Ship',
        payment: 'Cash on Delivery',
        products: <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'preview-product-${product.id}',
            productId: product.id,
            name: product.name,
            price: product.price,
            quantity: 1,
            imageUrl: product.imageUrl,
            variant: 'Default',
          ),
        ],
        total: product.price + 75,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        sellerName: product.sellerName,
        sellerId: product.sellerUserId,
        sellerSlug: product.sellerSlug,
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: _sampleDateTime(placedAt),
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: completed ? 'Delivered' : 'Pending',
            time: completed
                ? _sampleDateTime(placedAt.add(const Duration(days: 2)))
                : _sampleDateTime(placedAt),
            done: true,
          ),
        ],
        createdAt: placedAt,
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      );
    }, growable: false);
  }

  List<BuyerOrderData> _buildBuiltInPreviewOrders() {
    return <BuyerOrderData>[
      BuyerOrderData(
        id: '5',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-5-item-1',
            productId: 101,
            name: 'Gold-Plated Pearl Pendant Necklace',
            variant: 'Finish / Gold',
            imageUrl:
                'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=900&q=85&auto=format&fit=crop',
            price: 890,
            quantity: 1,
          ),
        ],
        total: 965,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 24, 2026 · 1:31 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 24, 2026 · 1:31 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 24, 13, 31),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '3',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-3-item-1',
            productId: 102,
            name: 'Creative Journaling Workbook',
            variant: 'Cover / Softcover',
            imageUrl:
                'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=900&q=85&auto=format&fit=crop',
            price: 420,
            quantity: 1,
          ),
        ],
        total: 495,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 23, 15, 15),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '4',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-4-item-1',
            productId: 103,
            name: 'Gold-Plated Pearl Pendant Necklace',
            variant: 'Finish / Gold',
            imageUrl:
                'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=900&q=85&auto=format&fit=crop',
            price: 890,
            quantity: 1,
          ),
        ],
        total: 965,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 23, 2026 · 3:15 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 23, 15, 15),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '2',
        status: 'to-ship',
        backendStatus: 'preparing',
        statusLabel: 'To Ship',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-2-item-1',
            productId: 104,
            name: 'Feeds',
            variant: 'Default',
            imageUrl:
                'https://images.unsplash.com/photo-1601758228041-f3b2795255f1?w=900&q=85&auto=format&fit=crop',
            price: 123,
            quantity: 1,
          ),
        ],
        total: 198,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 22, 2026 · 7:14 AM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Pending',
            time: 'Sep 22, 2026 · 7:14 AM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 22, 7, 14),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
      BuyerOrderData(
        id: '1',
        status: 'completed',
        backendStatus: 'completed',
        statusLabel: 'Completed',
        payment: 'Cash on Delivery',
        products: const <BuyerOrderProductData>[
          BuyerOrderProductData(
            id: 'sample-order-1-item-1',
            productId: 105,
            name: 'Ergonomic Mesh Office Chair',
            variant: 'Color / Beige',
            imageUrl:
                'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=900&q=85&auto=format&fit=crop',
            price: 3290,
            quantity: 1,
          ),
        ],
        total: 3365,
        buyerName: 'LIKHAE Buyer',
        buyerContact: '0917 123 4567',
        shippingAddress: '1 aaasasa, Masico, Pila, Laguna, 4010',
        timeline: const <BuyerOrderTimelineEvent>[
          BuyerOrderTimelineEvent(
            label: 'Order Placed',
            time: 'Sep 20, 2026 · 10:05 AM',
            done: true,
          ),
          BuyerOrderTimelineEvent(
            label: 'Delivered',
            time: 'Sep 22, 2026 · 2:40 PM',
            done: true,
          ),
        ],
        createdAt: DateTime(2026, 9, 20, 10, 5),
        isPreview: true,
        allowCancel: false,
        allowMarkReceived: false,
        allowReview: false,
        allowReturnRequest: false,
      ),
    ];
  }

  static String _sampleDateTime(DateTime value) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final int hour12 = value.hour == 0
        ? 12
        : value.hour > 12
        ? value.hour - 12
        : value.hour;

    final String minute = value.minute.toString().padLeft(2, '0');

    final String period = value.hour >= 12 ? 'PM' : 'AM';

    return '${months[value.month - 1]} ${value.day}, ${value.year} · $hour12:$minute $period';
  }

  @override
  void dispose() {
    _reviewController.dispose();
    _riderReviewController.dispose();
    _returnDetailsController.dispose();
    _returnEmailController.dispose();

    super.dispose();
  }

  BuyerOrderData? get _selectedOrder {
    final String? id = _selectedOrderId;

    if (id == null) {
      return null;
    }

    final String reference = id.trim().toLowerCase();
    if (reference.isEmpty) {
      return null;
    }

    // The detail route stores the parent order ID. Check it first so a
    // matching tracking or shipment reference on another order cannot win.
    for (final BuyerOrderData order in _orders) {
      if (order.id.trim().toLowerCase() == reference) return order;
    }

    for (final BuyerOrderData order in _orders) {
      final Set<String> orderReferences =
          <String>{
                order.orderNumber ?? '',
                order.sellerOrderNumber ?? '',
                order.tracking ?? '',
                order.shipmentId ?? '',
              }
              .map((String value) => value.trim().toLowerCase())
              .where((String value) => value.isNotEmpty)
              .toSet();
      if (orderReferences.contains(reference)) {
        return order;
      }
    }

    return null;
  }

  BuyerOrderProductData? get _selectedReviewProduct {
    final BuyerOrderData? order = _selectedOrder;

    final String? productId = _selectedReviewProductId;

    if (order == null || productId == null) {
      return null;
    }

    for (final BuyerOrderProductData product in order.products) {
      if (product.id == productId) {
        return product;
      }
    }

    return null;
  }

  List<BuyerOrderData> get _visibleOrders {
    if (_activeTab == BuyerOrderTab.all) {
      return _orders;
    }

    return _orders
        .where(
          (BuyerOrderData order) => order.tabStatus == _activeTab.statusKey,
        )
        .toList();
  }

  int _tabCount(BuyerOrderTab tab) {
    if (tab == BuyerOrderTab.all) {
      return _orders.length;
    }

    return _orders
        .where((BuyerOrderData order) => order.tabStatus == tab.statusKey)
        .length;
  }

  void _syncSelectedReviewProduct() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null || order.products.isEmpty) {
      _selectedReviewProductId = null;
      return;
    }

    final bool stillExists = order.products.any(
      (BuyerOrderProductData product) => product.id == _selectedReviewProductId,
    );

    if (!stillExists) {
      _selectedReviewProductId = order.products.first.id;
    }
  }

  void _openIndex() {
    FocusScope.of(context).unfocus();

    setState(() {
      _mode = BuyerOrdersMode.overview;

      _selectedOrderId = null;

      _selectedReviewProductId = null;
    });
  }

  void _openDetails(BuyerOrderData order) {
    FocusScope.of(context).unfocus();

    setState(() {
      _selectedOrderId = order.id;

      _mode = BuyerOrdersMode.details;
    });
  }

  void _openReview(BuyerOrderData order) {
    if (!order.canReview) {
      _showMessage('This order is not ready for review yet.', error: true);

      return;
    }

    if (order.products.isEmpty) {
      _showMessage('No product is available to review.', error: true);

      return;
    }

    setState(() {
      _selectedOrderId = order.id;

      _selectedReviewProductId = order.products.first.id;

      _mode = BuyerOrdersMode.review;
      _reviewNotice = null;

      _loadProductReview(order.products.first.id);
    });
  }

  void _loadProductReview(String productId) {
    final _SubmittedProductReview? review = _submittedReviews[productId];
    _rating = review?.rating ?? 5;
    _riderRating = review?.riderRating ?? 5;
    _riderReviewController.text = review?.riderReview ?? '';
    _reviewController.text = review?.review ?? '';
    _reviewPhotos = review == null
        ? <XFile>[]
        : List<XFile>.from(review.photos);
  }

  void _selectReviewProduct(String productId) {
    setState(() {
      _selectedReviewProductId = productId;
      _reviewNotice = null;
      _loadProductReview(productId);
    });
  }

  Future<void> _addReviewPhotos() async {
    try {
      final List<XFile> selected = await ImagePicker().pickMultiImage(
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted || selected.isEmpty) {
        return;
      }

      const int maxPhotos = 5;
      const int maxPhotoBytes = 5 * 1024 * 1024;
      final List<XFile> accepted = <XFile>[];
      bool rejectedPhoto = false;

      for (final XFile photo in selected) {
        if (_reviewPhotos.length + accepted.length >= maxPhotos) {
          break;
        }

        final String extension = photo.name.split('.').last.toLowerCase();
        if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          rejectedPhoto = true;
          continue;
        }
        if (await photo.length() > maxPhotoBytes) {
          rejectedPhoto = true;
          continue;
        }
        if (!_reviewPhotos.any((XFile current) => current.path == photo.path) &&
            !accepted.any((XFile current) => current.path == photo.path)) {
          accepted.add(photo);
        }
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _reviewPhotos = <XFile>[..._reviewPhotos, ...accepted];
      });

      if (rejectedPhoto) {
        _showMessage(
          'Product photos must be valid JPG, PNG, or WebP images under 5 MB.',
          error: true,
        );
      } else if (selected.length > accepted.length) {
        _showMessage('You can attach up to five product photos.');
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Unable to select product photos: $error', error: true);
      }
    }
  }

  void _openReturn(BuyerOrderData order) {
    if (!order.canRequestReturn) {
      _showMessage(order.returnRequestSubtitle, error: true);

      return;
    }

    _returnDetailsController.clear();
    _returnEmailController.clear();

    setState(() {
      _returnSubmissionError = null;
      _selectedOrderId = order.id;

      _returnIssueCategory = null;
      _returnReason = null;
      _returnRefundMethod = 'original_payment_method';
      _returnQuantities.clear();
      _returnEvidence = <XFile>[];
      _confirmReturnCashTerms = false;
      _confirmReturnRequest = false;

      _mode = BuyerOrdersMode.returnRequest;
    });
  }

  Future<void> _addReturnEvidence() async {
    try {
      final List<XFile> selected = widget.pickReturnEvidence == null
          ? await ImagePicker().pickMultiImage(
              imageQuality: 85,
              maxWidth: 1600,
              maxHeight: 1600,
            )
          : await widget.pickReturnEvidence!();
      if (!mounted || selected.isEmpty) return;
      final List<XFile> accepted = List<XFile>.from(_returnEvidence);
      final int previousCount = accepted.length;
      bool rejectedEvidence = false;
      for (final XFile file in selected) {
        if (accepted.length >= 5) break;
        final String extension = file.name.split('.').last.toLowerCase();
        if (!const <String>{'jpg', 'jpeg', 'png', 'webp'}.contains(extension)) {
          rejectedEvidence = true;
          continue;
        }
        if (await file.length() > 5 * 1024 * 1024) {
          rejectedEvidence = true;
          continue;
        }
        if (!accepted.any((XFile current) => current.path == file.path)) {
          accepted.add(file);
        }
      }
      if (!mounted) return;
      setState(() => _returnEvidence = accepted);
      if (rejectedEvidence) {
        _showMessage(
          'Return photos must be valid JPG, PNG, or WebP images under 5 MB.',
          error: true,
        );
      } else if (previousCount + selected.length > accepted.length) {
        _showMessage('You can attach up to five return photos.');
      }
    } catch (error) {
      if (mounted)
        _showMessage('Unable to select evidence: $error', error: true);
    }
  }

  Future<void> _refresh() async {
    final OrdersRefreshCallback? callback = widget.onRefresh;

    if (callback == null) {
      return;
    }

    try {
      final List<BuyerOrderData> orders = await callback();
      if (!mounted) {
        return;
      }
      setState(() {
        _orders = orders;
        _syncSelectedReviewProduct();
      });
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _buyAgain(BuyerOrderData order) async {
    final BuyAgainCallback? callback = widget.onBuyAgain;
    if (callback == null) return;
    try {
      final Map<String, dynamic> result = await callback(order);
      final int added = int.tryParse((result['added'] ?? 0).toString()) ?? 0;
      final int unavailable =
          int.tryParse((result['unavailable'] ?? 0).toString()) ?? 0;
      _showMessage(
        added == 0
            ? 'None of the items in this order are currently available.'
            : '$added item${added == 1 ? '' : 's'} added to your cart${unavailable > 0 ? '; $unavailable unavailable' : ''}.',
      );
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _confirmDeliveryPin(BuyerOrderData order) async {
    final ConfirmOrderDeliveryPinCallback? callback =
        widget.onConfirmDeliveryPin;
    if (callback == null) return;
    if (!order.canConfirmDeliveryPin) {
      _showMessage(
        'This order is no longer eligible for delivery-pin confirmation. Refresh your orders.',
        error: true,
      );
      return;
    }
    if (!_confirmingDeliveryPinOrderIds.add(order.id)) return;
    setState(() {});
    try {
      final bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showMessage(
          'Turn on location services to confirm the delivery pin.',
          error: true,
        );
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage(
          'Allow location access to confirm the delivery pin.',
          error: true,
        );
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await callback(order, position.latitude, position.longitude);
      if (!mounted) return;
      final int index = _orders.indexWhere(
        (BuyerOrderData current) => current.id == order.id,
      );
      if (index >= 0) {
        setState(() {
          _orders[index] = _orders[index].copyWith(
            canConfirmDeliveryPin: false,
            orderLocation: BuyerOrderLocation(
              latitude: position.latitude,
              longitude: position.longitude,
              label: 'Delivery destination',
            ),
          );
        });
      }
      _showMessage('Delivery pin confirmed for this order.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() => _confirmingDeliveryPinOrderIds.remove(order.id));
      }
    }
  }

  Future<void> _markReceived(BuyerOrderData order) async {
    if (_receivingOrder) {
      return;
    }

    if (!order.canMarkReceived) {
      _showMessage(
        'You can confirm receipt only after the order is marked delivered.',
        error: true,
      );

      return;
    }

    final ReceiveOrderCallback? callback = widget.onReceiveOrder;

    if (callback == null) {
      _showMessage('Order receipt will be connected to Laravel later.');

      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: _surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Confirm receipt?',
            style: TextStyle(color: _text, fontWeight: FontWeight.w800),
          ),
          content: const Text(
            'Confirm only after the parcel has actually been delivered to you.',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('Not Yet'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              style: ElevatedButton.styleFrom(
                elevation: 0,
                backgroundColor: _maroon,
                foregroundColor: Colors.white,
              ),
              child: const Text('Order Received'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _receivingOrder = true;
    });

    try {
      await callback(order);

      if (!mounted) {
        return;
      }

      final int index = _orders.indexWhere(
        (BuyerOrderData current) => current.id == order.id,
      );

      if (index >= 0) {
        setState(() {
          _orders[index] = order.copyWith(
            status: 'completed',
            backendStatus: 'completed',
            statusLabel: 'Completed',
            allowMarkReceived: false,
            allowReview: true,
          );
        });
      }

      _showMessage('Order marked as received.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _receivingOrder = false;
        });
      }
    }
  }

  Future<void> _showCancelDialog(BuyerOrderData order) async {
    if (!order.canCancel) {
      _showMessage('This order can no longer be cancelled.', error: true);

      return;
    }

    final TextEditingController noteController = TextEditingController();

    String? selectedReason;

    bool submitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> submitCancellation() async {
              if (submitting || !sheetContext.mounted) {
                return;
              }

              final String? reason = selectedReason;

              if (reason == null || reason.trim().isEmpty) {
                return;
              }

              if (reason == 'Other' && noteController.text.trim().isEmpty) {
                _showMessage('Add a note when you choose Other.', error: true);
                return;
              }

              final CancelOrderCallback? callback = widget.onCancelOrder;

              if (callback == null) {
                Navigator.of(sheetContext).pop();

                _showMessage(
                  'Order cancellation will be connected to Laravel later.',
                );

                return;
              }

              setSheetState(() {
                submitting = true;
              });

              try {
                await callback(order, reason, noteController.text.trim());

                if (!mounted) {
                  return;
                }

                final int index = _orders.indexWhere(
                  (BuyerOrderData current) => current.id == order.id,
                );

                if (index >= 0) {
                  setState(() {
                    _orders[index] = order.copyWith(
                      status: 'cancelled',
                      backendStatus: 'cancelled',
                      statusLabel: 'Cancelled',
                      allowCancel: false,
                      allowMarkReceived: false,
                      allowReview: false,
                      allowReturnRequest: false,
                    );
                  });
                }

                if (sheetContext.mounted) {
                  Navigator.of(sheetContext).pop();
                }

                _showMessage('Order cancelled.');
              } catch (error) {
                _showMessage(_errorText(error), error: true);

                if (sheetContext.mounted) {
                  setSheetState(() {
                    submitting = false;
                  });
                }
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(18, 10, 18, 22),
                  decoration: const BoxDecoration(
                    color: _surface,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(26),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: _border,
                              borderRadius: BorderRadius.circular(100),
                            ),
                          ),
                        ),

                        const SizedBox(height: 18),

                        const Text(
                          'CANCELLATION',
                          style: TextStyle(
                            color: _maroon,
                            fontSize: 11,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 7),

                        const Text(
                          'If Laravel no longer allows cancellation when this request reaches the server, the order will remain active.',
                          style: TextStyle(
                            color: _muted,
                            fontSize: 12.5,
                            height: 1.5,
                          ),
                        ),

                        const SizedBox(height: 18),

                        const _InputLabel(text: 'Reason'),

                        const SizedBox(height: 7),

                        DropdownButtonFormField<String>(
                          initialValue: selectedReason,
                          isExpanded: true,
                          decoration: _sheetInputDecoration(
                            hintText: 'Choose a reason',
                          ),
                          items: _cancelReasons.map((String reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            );
                          }).toList(),
                          onChanged: submitting
                              ? null
                              : (String? value) {
                                  setSheetState(() {
                                    selectedReason = value;
                                  });
                                },
                        ),

                        const SizedBox(height: 15),

                        const _InputLabel(
                          text: 'Additional note',
                          requiredField: false,
                        ),

                        const SizedBox(height: 7),

                        TextField(
                          controller: noteController,
                          enabled: !submitting,
                          minLines: 3,
                          maxLines: 5,
                          maxLength: 450,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: _sheetInputDecoration(
                            hintText: 'Optional note',
                          ),
                        ),

                        const SizedBox(height: 18),

                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: submitting
                                    ? null
                                    : () {
                                        Navigator.of(sheetContext).pop();
                                      },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _maroon,
                                  side: const BorderSide(color: _tan),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: const Text('Keep Order'),
                              ),
                            ),

                            const SizedBox(width: 9),

                            Expanded(
                              child: ElevatedButton(
                                onPressed: submitting || selectedReason == null
                                    ? null
                                    : submitCancellation,
                                style: ElevatedButton.styleFrom(
                                  elevation: 0,
                                  backgroundColor: _danger,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(13),
                                  ),
                                ),
                                child: submitting
                                    ? const SizedBox(
                                        width: 19,
                                        height: 19,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Cancel Order'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    noteController.dispose();
  }

  Future<void> _submitReview() async {
    final BuyerOrderData? order = _selectedOrder;

    final BuyerOrderProductData? product = _selectedReviewProduct;

    if (order == null || product == null) {
      return;
    }

    if (!order.canReview) {
      _showMessage('This order is not ready for review.', error: true);

      return;
    }

    if (!(_reviewFormKey.currentState?.validate() ?? false)) {
      return;
    }

    if (widget.onSubmitProductReview == null) {
      final String message = widget.onSubmitReview == null
          ? 'Reviews cannot be saved yet because order review submission is not connected.'
          : 'This review handler does not support rider ratings and product photos yet.';
      setState(() {
        _reviewNotice = message;
        _reviewNoticeIsError = true;
      });
      return;
    }

    setState(() {
      _submittingReview = true;
      _reviewNotice = null;
    });

    try {
      final String riderReview = _riderReviewController.text.trim();
      final String review = _reviewController.text.trim();

      await widget.onSubmitProductReview!(
        BuyerOrderReviewRequest(
          order: order,
          product: product,
          rating: _rating,
          riderRating: _riderRating,
          riderReview: riderReview,
          review: review,
          photos: List<XFile>.unmodifiable(_reviewPhotos),
          isTextUpdate: _reviewedProductIds.contains(product.id),
        ),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _reviewedProductIds.add(product.id);
        _submittedReviews[product.id] = _SubmittedProductReview(
          rating: _rating,
          riderRating: _riderRating,
          riderReview: riderReview,
          review: review,
          photos: List<XFile>.unmodifiable(_reviewPhotos),
        );
        _reviewNotice = 'Review saved. You can still edit the review text.';
        _reviewNoticeIsError = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _reviewNotice = _errorText(error);
          _reviewNoticeIsError = true;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _submittingReview = false;
        });
      }
    }
  }

  Future<void> _submitReturn() async {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return;
    }

    if (!order.canRequestReturn) {
      _showMessage(order.returnRequestSubtitle, error: true);

      return;
    }

    if (!(_returnFormKey.currentState?.validate() ?? false)) return;

    if (_returnIssueCategory == null || _returnReason == null) return;
    if (_returnQuantities.isEmpty) {
      _showMessage(
        'Select at least one item to return or refund.',
        error: true,
      );
      return;
    }
    if (_returnEvidence.isEmpty) {
      _showMessage('Add at least one photo showing the issue.', error: true);
      return;
    }
    if (!_confirmReturnCashTerms || !_confirmReturnRequest) {
      _showMessage(
        'Confirm both return and refund acknowledgements.',
        error: true,
      );
      return;
    }

    if (widget.onSubmitReturnRequest == null && widget.onSubmitReturn == null) {
      _showMessage(
        'Return / refund submission will be connected to Laravel later.',
      );

      return;
    }

    setState(() {
      _submittingReturn = true;
      _returnSubmissionError = null;
    });

    try {
      final String details = _returnDetailsController.text.trim();
      String? requestId;

      if (widget.onSubmitReturnRequest != null) {
        requestId = await widget.onSubmitReturnRequest!(
          BuyerOrderReturnRequest(
            order: order,
            issueCategory: _returnIssueCategory!,
            issueReason: _returnReason!,
            description: details,
            refundMethod: _returnRefundMethod,
            quantitiesByItem: Map<String, int>.unmodifiable(_returnQuantities),
            buyerEmail: _returnEmailController.text.trim(),
            evidence: List<XFile>.unmodifiable(_returnEvidence),
          ),
        );
      } else {
        await widget.onSubmitReturn!(
          order,
          _returnIssueLabels[_returnIssueCategory!] ?? _returnIssueCategory!,
          _returnReason!,
          details,
        );
      }

      if (!mounted) {
        return;
      }

      final int index = _orders.indexWhere(
        (BuyerOrderData current) => current.id == order.id,
      );

      if (index >= 0) {
        setState(() {
          _orders[index] = order.copyWith(
            status: 'returns',
            statusLabel: 'Return / Refund Requested',
            allowCancel: false,
            allowMarkReceived: false,
            allowReview: false,
            allowReturnRequest: false,
            hasActiveReturnRequest: true,
          );
        });
      }

      _showMessage(
        requestId == null || requestId.isEmpty
            ? 'Return / refund request submitted.'
            : 'Return / refund request $requestId submitted.',
      );

      final BuyerOrderData updatedOrder = index >= 0
          ? _orders[index]
          : order.copyWith(
              status: 'returns',
              statusLabel: 'Return / Refund Requested',
              allowCancel: false,
              allowMarkReceived: false,
              allowReview: false,
              allowReturnRequest: false,
              hasActiveReturnRequest: true,
            );

      _openDetails(updatedOrder);
    } catch (error) {
      final String message = _errorText(error);
      if (mounted) {
        setState(() {
          _returnSubmissionError = message;
        });
      }
      _showMessage(message, error: true);
    } finally {
      if (mounted) {
        setState(() {
          _submittingReturn = false;
        });
      }
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
    final BuyerOrderData? detailOrder = _mode == BuyerOrdersMode.details
        ? _selectedOrder
        : null;

    return Scaffold(
      backgroundColor: _background,
      bottomNavigationBar: detailOrder == null
          ? null
          : _buildDetailsBottomBar(detailOrder),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refresh,
                child: _buildCurrentMode(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentMode() {
    switch (_mode) {
      case BuyerOrdersMode.success:
        return _buildSuccessMode();

      case BuyerOrdersMode.details:
        return _buildDetailsMode();

      case BuyerOrdersMode.review:
        return _buildReviewMode();

      case BuyerOrdersMode.returnRequest:
        return _buildReturnMode();

      case BuyerOrdersMode.overview:
        return _buildOrdersIndex();
    }
  }

  Widget _buildTopBar() {
    void handleBack() {
      if (_mode != BuyerOrdersMode.overview &&
          _mode != BuyerOrdersMode.success) {
        if (_mode == BuyerOrdersMode.details &&
            widget.initialMode == BuyerOrdersMode.details &&
            widget.selectedOrderId?.trim().isNotEmpty == true) {
          if (widget.onBack != null) {
            widget.onBack!();
          } else {
            Navigator.of(context).maybePop();
          }
          return;
        }
        _openIndex();
        return;
      }
      if (widget.onBack != null) {
        widget.onBack!();
        return;
      }
      Navigator.of(context).maybePop();
    }

    if (_mode == BuyerOrdersMode.overview) {
      return const SizedBox.shrink();
    }

    return ShopPageHeader(
      title: _modeTitle,
      subtitle: _modeSubtitle,
      onBack: handleBack,
    );
  }

  String get _modeTitle {
    switch (_mode) {
      case BuyerOrdersMode.overview:
        return 'My Orders';

      case BuyerOrdersMode.success:
        return 'Order Placed';

      case BuyerOrdersMode.details:
        return 'Order Details';

      case BuyerOrdersMode.review:
        return 'Rate & Review';

      case BuyerOrdersMode.returnRequest:
        return 'Return / Refund';
    }
  }

  String get _modeSubtitle {
    switch (_mode) {
      case BuyerOrdersMode.overview:
        return 'Track, receive, review, or request a return';

      case BuyerOrdersMode.success:
        return 'Your order was submitted successfully';

      case BuyerOrdersMode.details:
        return '';

      case BuyerOrdersMode.review:
        return 'Rate the product and delivery rider';

      case BuyerOrdersMode.returnRequest:
        return 'Submit a return or refund request';
    }
  }

  Widget _buildOrdersIndex() {
    final List<BuyerOrderData> visibleOrders = _visibleOrders;

    return CustomScrollView(
      key: const PageStorageKey<String>('buyer-orders-scroll'),
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                if (widget.buyerNotice != null) ...[
                  _NoticeCard(message: widget.buyerNotice!),

                  const SizedBox(height: 14),
                ],

                if (_usingProductPreview) ...[
                  const _NoticeCard(
                    message:
                        'Sample order preview only — tap View Details to inspect the complete order screen. These cards are not saved to Laravel and real database orders automatically replace them once provided.',
                  ),

                  const SizedBox(height: 14),
                ],

                _buildOrdersHeading(),

                const SizedBox(height: 12),

                _buildTabs(),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        if (visibleOrders.isEmpty)
          SliverFillRemaining(hasScrollBody: false, child: _buildEmptyOrders())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((
                BuildContext context,
                int index,
              ) {
                final BuyerOrderData order = visibleOrders[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 11),
                  child: _OrderCard(
                    order: order,
                    onOpen: () {
                      final BuyerOrderCallback? openOrderDetails =
                          widget.onOpenOrderDetails;
                      if (openOrderDetails != null) {
                        openOrderDetails(order);
                      } else {
                        _openDetails(order);
                      }
                    },
                    onTrack: widget.onTrackOrder == null
                        ? null
                        : () {
                            widget.onTrackOrder!(order);
                          },
                    onCancel: order.canCancel
                        ? () {
                            _showCancelDialog(order);
                          }
                        : null,
                    onReceive: order.canMarkReceived
                        ? () {
                            _markReceived(order);
                          }
                        : null,
                    onReview: order.canReview
                        ? () {
                            _openReview(order);
                          }
                        : null,
                    onReturn: order.canRequestReturn
                        ? () {
                            _openReturn(order);
                          }
                        : null,
                    onBuyAgain: widget.onBuyAgain == null
                        ? null
                        : () => _buyAgain(order),
                    onConfirmDeliveryPin:
                        order.canConfirmDeliveryPin &&
                            widget.onConfirmDeliveryPin != null
                        ? () => _confirmDeliveryPin(order)
                        : null,
                    confirmingDeliveryPin: _confirmingDeliveryPinOrderIds
                        .contains(order.id),
                    onContactSeller:
                        widget.onContactSeller == null ||
                            (order.sellerOrders.isEmpty
                                ? order.sellerId == null || order.sellerId! < 1
                                : !order.sellerOrders.any(
                                        (BuyerSellerOrderData sellerOrder) =>
                                            (sellerOrder.sellerId ?? 0) > 0,
                                      ) &&
                                      !(order.sellerOrders.length == 1 &&
                                          (order.sellerId ?? 0) > 0))
                        ? null
                        : () => widget.onContactSeller!(order),
                    onViewStore:
                        widget.onViewStore == null ||
                            order.sellerName?.trim().isEmpty != false
                        ? null
                        : () => widget.onViewStore!(order),
                    receiving: _receivingOrder,
                  ),
                );
              }, childCount: visibleOrders.length),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 112)),
      ],
    );
  }

  Widget _buildOrdersHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ShopColors.accentSoft,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Text(
              'ORDER CENTER',
              style: TextStyle(
                color: _maroonDark,
                fontSize: 9,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'My Orders',
          style: TextStyle(
            color: Color(0xFF432A25),
            fontFamily: 'serif',
            fontSize: 36,
            height: 1.05,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 3),
        const Text(
          'Track fulfillment and confirm receipt after delivery.',
          style: TextStyle(
            color: Color(0xFF8A7163),
            fontSize: 11.5,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return SizedBox(
      height: 45,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: BuyerOrderTab.values.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 6),
        itemBuilder: (BuildContext context, int index) {
          final BuyerOrderTab tab = BuyerOrderTab.values[index];

          final bool selected = tab == _activeTab;

          return Material(
            color: selected ? _maroon : _surface,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeTab = tab;
                });
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  border: Border.all(color: selected ? _maroon : _border),
                  borderRadius: BorderRadius.circular(11),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      tab.label,
                      style: TextStyle(
                        color: selected ? Colors.white : _text,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      '${_tabCount(tab)}',
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.75)
                            : _muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyOrders() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: const BoxDecoration(
                color: ShopColors.accentSoft,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: const Icon(
                Icons.receipt_long_outlined,
                color: _maroon,
                size: 31,
              ),
            ),

            const SizedBox(height: 18),

            const Text(
              'No orders in this section',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _text,
                fontSize: 19,
                fontWeight: FontWeight.w800,
              ),
            ),

            const SizedBox(height: 7),

            const Text(
              'Orders matching this status will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _muted, fontSize: 12.5),
            ),

            const SizedBox(height: 19),

            OutlinedButton.icon(
              onPressed: widget.onShopProducts,
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                side: const BorderSide(color: _tan),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.storefront_outlined, size: 17),
              label: const Text('Shop Products'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessMode() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(18),
      children: [
        const SizedBox(height: 45),

        Center(
          child: Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: ShopColors.accentSoft,
              borderRadius: BorderRadius.circular(21),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.check_rounded, size: 38, color: _maroon),
          ),
        ),

        const SizedBox(height: 20),

        const Text(
          'ORDER PLACED',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _maroon,
            fontSize: 11,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'Thank you for your order',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 25,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Your order was submitted successfully. Open My Orders to follow its current payment, preparation, shipment, and delivery status.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 13, height: 1.55),
        ),

        const SizedBox(height: 24),

        SizedBox(
          height: 49,
          child: ElevatedButton(
            onPressed: _openIndex,
            style: ElevatedButton.styleFrom(
              elevation: 0,
              backgroundColor: _maroon,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text(
              'View My Orders',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ),

        const SizedBox(height: 9),

        SizedBox(
          height: 49,
          child: OutlinedButton(
            onPressed: widget.onShopProducts,
            style: OutlinedButton.styleFrom(
              foregroundColor: _maroon,
              side: const BorderSide(color: _tan),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(13),
              ),
            ),
            child: const Text('Continue Shopping'),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailsMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      children: [
        if (order.isPreview) ...[
          const _NoticeCard(
            message:
                'Sample order details only. This is a UI preview and is not stored in Laravel.',
          ),

          const SizedBox(height: 12),
        ],
        _buildOrderSummaryCard(order),
        const SizedBox(height: 12),
        _buildBuyerShippingCard(order),
        const SizedBox(height: 12),
        _buildBuyerProductsCard(order),
        const SizedBox(height: 12),
        _buildBuyerSupportCard(order),
        const SizedBox(height: 12),
        _buildBuyerOrderInfoCard(order),
      ],
    );
  }

  Widget _buildOrderSummaryCard(BuyerOrderData order) {
    final String trackingReference = order.tracking?.trim().isNotEmpty == true
        ? order.tracking!.trim()
        : order.shipmentId?.trim().isNotEmpty == true
        ? order.shipmentId!.trim()
        : '';

    return _BuyerDetailCard(
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: ShopColors.accentSoft,
              borderRadius: BorderRadius.circular(13),
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.receipt_long_outlined,
              color: ShopColors.accent,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ORDER SUMMARY',
                  style: TextStyle(
                    color: ShopColors.muted,
                    fontSize: 10,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  trackingReference.isNotEmpty
                      ? 'Tracking ID $trackingReference'
                      : 'Tracking ID pending',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: ShopColors.text,
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (order.createdAt != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _formatDetailDate(order.createdAt!),
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerShippingCard(BuyerOrderData order) {
    final BuyerOrderTimelineEvent? latestEvent = _latestTimelineEvent(order);
    final bool delivered = <String>{
      'delivered',
      'completed',
    }.contains(order.normalizedStatus);
    final Color statusColor = delivered ? const Color(0xFF168548) : _maroon;
    final Color statusBackground = delivered
        ? const Color(0xFFEAF6EE)
        : ShopColors.accentSoft;

    return _BuyerDetailCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: widget.onTrackOrder == null
                ? null
                : () => widget.onTrackOrder!(order),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 13, 13),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: ShopColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.local_shipping_outlined,
                      color: ShopColors.accent,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Shipping information',
                          style: TextStyle(
                            color: ShopColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          order.tracking?.trim().isNotEmpty == true
                              ? 'Tracking No. ${order.tracking}'
                              : 'Tracking number will appear after shipment.',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.onTrackOrder != null)
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: ShopColors.faint,
                      size: 23,
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 0, 15, 13),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusBackground,
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    delivered
                        ? Icons.check_circle_outline_rounded
                        : Icons.local_shipping_outlined,
                    color: statusColor,
                    size: 21,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          latestEvent?.label ?? order.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          latestEvent?.time.trim().isNotEmpty == true
                              ? latestEvent!.time
                              : 'Shipment update pending',
                          style: const TextStyle(
                            color: ShopColors.muted,
                            fontSize: 11.5,
                          ),
                        ),
                        if (latestEvent?.details.trim().isNotEmpty == true) ...[
                          const SizedBox(height: 4),
                          Text(
                            latestEvent!.details,
                            style: const TextStyle(
                              color: ShopColors.muted,
                              fontSize: 11.5,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 15, endIndent: 15, color: _border),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DELIVER TO',
                  style: TextStyle(
                    color: ShopColors.muted,
                    fontSize: 10,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 9),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: ShopColors.soft,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.location_on_outlined,
                        color: ShopColors.secondaryText,
                        size: 19,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            order.buyerName.trim().isEmpty
                                ? 'Buyer'
                                : order.buyerName,
                            style: const TextStyle(
                              color: ShopColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (order.buyerContact?.trim().isNotEmpty ==
                              true) ...[
                            const SizedBox(height: 2),
                            Text(
                              order.buyerContact!,
                              style: const TextStyle(
                                color: ShopColors.muted,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                          const SizedBox(height: 5),
                          Text(
                            order.shippingAddress.trim().isEmpty
                                ? 'No delivery address recorded.'
                                : order.shippingAddress,
                            style: const TextStyle(
                              color: ShopColors.secondaryText,
                              fontSize: 11.5,
                              height: 1.45,
                            ),
                          ),
                        ],
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

  BuyerOrderTimelineEvent? _latestTimelineEvent(BuyerOrderData order) {
    BuyerOrderTimelineEvent? latest;
    for (final BuyerOrderTimelineEvent event in order.timeline) {
      if (event.done) {
        latest = event;
      }
    }
    return latest;
  }

  Widget _buildBuyerProductsCard(BuyerOrderData order) {
    final int totalQuantity = order.products.fold<int>(
      0,
      (int total, BuyerOrderProductData product) =>
          total + product.safeQuantity,
    );

    return _BuyerDetailCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          InkWell(
            onTap: widget.onShopProducts,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(15, 14, 13, 12),
              child: Row(
                children: [
                  Container(
                    width: 37,
                    height: 37,
                    decoration: BoxDecoration(
                      color: ShopColors.accentSoft,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.storefront_outlined,
                      color: ShopColors.accent,
                      size: 19,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'SOLD BY',
                          style: TextStyle(
                            color: ShopColors.muted,
                            fontSize: 9.5,
                            letterSpacing: 1,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          order.sellerName?.trim().isNotEmpty == true
                              ? order.sellerName!.trim()
                              : 'Likhae Marketplace',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ShopColors.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: ShopColors.faint,
                    size: 23,
                  ),
                ],
              ),
            ),
          ),
          if (order.products.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 14, 16, 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No products recorded for this order.',
                  style: TextStyle(color: _muted, fontSize: 12.5),
                ),
              ),
            )
          else
            Column(
              children: List<Widget>.generate(
                order.products.length,
                (int index) => _OrderProductRow(
                  product: order.products[index],
                  showDivider: index != order.products.length - 1,
                ),
                growable: false,
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(15, 13, 15, 14),
            decoration: const BoxDecoration(
              color: Color(0xFFFAF7F4),
              border: Border(top: BorderSide(color: _border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Order total',
                        style: TextStyle(
                          color: ShopColors.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$totalQuantity ${totalQuantity == 1 ? 'item' : 'items'}',
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  _formatPrice(order.total),
                  style: const TextStyle(
                    color: ShopColors.accentDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerSupportCard(BuyerOrderData order) {
    return _BuyerDetailCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 15, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.support_agent_rounded,
                  color: ShopColors.accent,
                  size: 19,
                ),
                SizedBox(width: 8),
                Text(
                  'Need help?',
                  style: TextStyle(
                    color: ShopColors.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          _BuyerDetailActionRow(
            icon: Icons.settings_backup_restore_rounded,
            title: 'Request a return or refund',
            subtitle: order.returnRequestSubtitle,
            onTap: order.canRequestReturn ? () => _openReturn(order) : null,
          ),
          const Divider(height: 1, indent: 58, endIndent: 14, color: _border),
          _BuyerDetailActionRow(
            icon: Icons.forum_outlined,
            title: 'Contact seller',
            subtitle: 'Ask the seller about this order.',
            onTap: () {
              if (widget.onContactSeller != null) {
                widget.onContactSeller!(order);
                return;
              }
              _showMessage('Seller messaging is currently unavailable.');
            },
          ),
          const Divider(height: 1, indent: 58, endIndent: 14, color: _border),
          _BuyerDetailActionRow(
            icon: Icons.help_outline_rounded,
            title: 'Help center',
            subtitle: 'Get help with your purchase.',
            onTap: () {
              if (widget.onOpenHelpCenter != null) {
                widget.onOpenHelpCenter!(order);
                return;
              }
              _showMessage('The help center is currently unavailable.');
            },
          ),
        ],
      ),
    );
  }

  Widget _buildBuyerOrderInfoCard(BuyerOrderData order) {
    final String trackingId = order.tracking?.trim() ?? '';

    return _BuyerDetailCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment details',
            style: TextStyle(
              color: ShopColors.text,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(11, 10, 7, 10),
            decoration: BoxDecoration(
              color: ShopColors.soft,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.tag_rounded,
                  color: ShopColors.secondaryText,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'TRACKING ID',
                        style: TextStyle(
                          color: ShopColors.muted,
                          fontSize: 9,
                          letterSpacing: .9,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        trackingId.isEmpty ? 'Not assigned yet' : trackingId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: trackingId.isEmpty
                      ? null
                      : () => _copyTrackingId(trackingId),
                  style: TextButton.styleFrom(
                    foregroundColor: ShopColors.accentDark,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(48, 38),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(Icons.copy_rounded, size: 14),
                  label: const Text(
                    'Copy',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 15),
          _DetailRow(label: 'Paid by', value: order.payment),
          if (order.paymentStatus?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 12),
            _DetailRow(label: 'Payment status', value: order.paymentStatus!),
          ],
        ],
      ),
    );
  }

  Future<void> _copyTrackingId(String trackingId) async {
    await Clipboard.setData(ClipboardData(text: trackingId));
    if (mounted) {
      _showMessage('Tracking ID copied.');
    }
  }

  String _formatDetailDate(DateTime date) {
    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final DateTime local = date.toLocal();
    final int hour = local.hour == 0
        ? 12
        : local.hour > 12
        ? local.hour - 12
        : local.hour;
    final String minute = local.minute.toString().padLeft(2, '0');
    final String period = local.hour >= 12 ? 'PM' : 'AM';
    return '${months[local.month - 1]} ${local.day}, ${local.year} '
        '$hour:$minute $period';
  }

  Widget? _buildDetailsBottomBar(BuyerOrderData order) {
    final List<Widget> actions = <Widget>[
      if (order.canCancel)
        _BuyerDetailBottomButton(
          label: 'Cancel Order',
          onPressed: () => _showCancelDialog(order),
        ),
      if (order.canRequestReturn)
        _BuyerDetailBottomButton(
          label: 'Return/Refund',
          onPressed: () => _openReturn(order),
        ),
      if (widget.onConfirmDeliveryPin != null &&
          (order.canConfirmDeliveryPin ||
              _confirmingDeliveryPinOrderIds.contains(order.id)))
        _BuyerDetailBottomButton(
          label: _confirmingDeliveryPinOrderIds.contains(order.id)
              ? 'Confirming...'
              : 'Confirm delivery pin',
          filled: true,
          onPressed: _confirmingDeliveryPinOrderIds.contains(order.id)
              ? null
              : () => _confirmDeliveryPin(order),
        ),
      if (order.canMarkReceived)
        _BuyerDetailBottomButton(
          label: _receivingOrder ? 'Updating...' : 'Order Received',
          filled: true,
          onPressed: _receivingOrder ? null : () => _markReceived(order),
        ),
      if (order.canReview)
        _BuyerDetailBottomButton(
          label: 'Rate & Review',
          filled: true,
          onPressed: () => _openReview(order),
        ),
    ];

    if (actions.isEmpty) {
      return null;
    }

    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: _border)),
        ),
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            final double buttonWidth = (constraints.maxWidth - 9) / 2;
            return Wrap(
              spacing: 9,
              runSpacing: 8,
              children: actions
                  .map(
                    (Widget action) =>
                        SizedBox(width: buttonWidth, child: action),
                  )
                  .toList(growable: false),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRatingPicker({
    required String label,
    required int rating,
    required bool enabled,
    required ValueChanged<int> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InputLabel(text: label),
        const SizedBox(height: 7),
        Wrap(
          spacing: 5,
          children: List<Widget>.generate(5, (int index) {
            final int value = index + 1;
            final bool selected = rating >= value;
            return Semantics(
              button: true,
              label: '$value star${value == 1 ? '' : 's'}',
              child: InkWell(
                onTap: enabled ? () => onChanged(value) : null,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 39,
                  height: 39,
                  decoration: BoxDecoration(
                    color: selected ? const Color(0xFFFFC107) : _soft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: selected ? const Color(0xFFE0A800) : _border,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    selected ? Icons.star_rounded : Icons.star_border_rounded,
                    color: selected ? _star : _muted2,
                    size: 23,
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 5),
        Text(
          '$rating out of 5',
          style: const TextStyle(color: _muted, fontSize: 11.5),
        ),
      ],
    );
  }

  Widget _buildReviewPhotoPicker({required bool locked}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _InputLabel(text: 'Add product photos', requiredField: false),
        const SizedBox(height: 5),
        const Text(
          'JPG, PNG, or WebP · one photo · 5 MB maximum',
          style: TextStyle(color: _muted, fontSize: 11.5),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 9,
          runSpacing: 9,
          children: [
            for (int index = 0; index < _reviewPhotos.length; index++)
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: FutureBuilder<List<int>>(
                          future: _reviewPhotos[index].readAsBytes(),
                          builder:
                              (
                                BuildContext context,
                                AsyncSnapshot<List<int>> snapshot,
                              ) {
                                if (snapshot.hasError) {
                                  return const ColoredBox(
                                    color: _soft,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: _muted,
                                    ),
                                  );
                                }
                                if (!snapshot.hasData) {
                                  return const ColoredBox(
                                    color: _soft,
                                    child: Center(
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: _maroon,
                                        ),
                                      ),
                                    ),
                                  );
                                }
                                return Image.memory(
                                  Uint8List.fromList(snapshot.data!),
                                  fit: BoxFit.cover,
                                );
                              },
                        ),
                      ),
                    ),
                    if (!locked)
                      Positioned(
                        top: 2,
                        right: 2,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _reviewPhotos.removeAt(index);
                            });
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: const CircleAvatar(
                            radius: 12,
                            backgroundColor: _maroon,
                            child: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            if (!locked && _reviewPhotos.length < 5)
              OutlinedButton(
                onPressed: _submittingReview ? null : _addReviewPhotos,
                style: OutlinedButton.styleFrom(
                  foregroundColor: _maroon,
                  side: const BorderSide(color: _border),
                  minimumSize: const Size(76, 76),
                  padding: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: const Icon(Icons.add_photo_alternate_outlined),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildReviewMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    final BuyerOrderProductData? product = _selectedReviewProduct;

    if (product == null) {
      return _buildOrderNotFound();
    }

    return Form(
      key: _reviewFormKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Text(
            'ORDER #${order.id}',
            style: const TextStyle(
              color: _maroon,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Rate and review your order',
            style: TextStyle(
              color: _text,
              fontSize: 27,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Ratings and photos lock after your first submission. Review text can still be edited.',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (order.products.length > 1) ...[
                  const _InputLabel(text: 'Product'),

                  const SizedBox(height: 7),

                  DropdownButtonFormField<String>(
                    initialValue: _selectedReviewProductId,
                    isExpanded: true,
                    decoration: _inputDecoration(hintText: 'Choose product'),
                    items: order.products.map((BuyerOrderProductData item) {
                      final bool reviewed = _reviewedProductIds.contains(
                        item.id,
                      );

                      return DropdownMenuItem<String>(
                        value: item.id,
                        child: Text(
                          reviewed ? '${item.name} — Reviewed' : item.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: _submittingReview
                        ? null
                        : (String? value) {
                            if (value == null) {
                              return;
                            }
                            _selectReviewProduct(value);
                          },
                  ),

                  const SizedBox(height: 16),
                ],

                _SelectedProduct(product: product),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Divider(height: 1, color: _border),
                ),

                _buildRatingPicker(
                  label: 'Product rating',
                  rating: _rating,
                  enabled:
                      !_submittingReview &&
                      !_reviewedProductIds.contains(product.id),
                  onChanged: (int value) {
                    setState(() {
                      _rating = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                _buildRatingPicker(
                  label: 'Delivery rider rating',
                  rating: _riderRating,
                  enabled:
                      !_submittingReview &&
                      !_reviewedProductIds.contains(product.id),
                  onChanged: (int value) {
                    setState(() {
                      _riderRating = value;
                    });
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(
                  text: 'Rider review (optional)',
                  requiredField: false,
                ),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _riderReviewController,
                  enabled: !_submittingReview,
                  minLines: 2,
                  maxLines: 4,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hintText: 'Comment on the delivery experience',
                  ),
                ),

                const SizedBox(height: 16),

                _buildReviewPhotoPicker(
                  locked:
                      _submittingReview ||
                      _reviewedProductIds.contains(product.id),
                ),

                const SizedBox(height: 18),

                const _InputLabel(text: 'Product review'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _reviewController,
                  enabled: !_submittingReview,
                  minLines: 3,
                  maxLines: 6,
                  maxLength: 3000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hintText: 'Quality, fit, packaging, and your experience...',
                  ),
                  validator: (String? value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Write your review.';
                    }

                    if (value.trim().length > 3000) {
                      return 'Review must not exceed 3000 characters.';
                    }

                    return null;
                  },
                ),

                _buildReviewNotice(),

                const SizedBox(height: 17),

                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: ElevatedButton(
                    onPressed: _submittingReview ? null : _submitReview,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _submittingReview
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _reviewedProductIds.contains(product.id)
                                ? 'Update Review'
                                : 'Submit Review',
                            style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildReviewNotice() {
    final String? message = _reviewNotice;
    if (message == null || message.isEmpty) {
      return const SizedBox.shrink();
    }

    final Color color = _reviewNoticeIsError ? _danger : _maroon;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _reviewNoticeIsError
            ? const Color(0xFFFFF3F2)
            : const Color(0xFFF4F7F2),
        border: Border.all(color: color.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            _reviewNoticeIsError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnItemSelector(BuyerOrderProductData product) {
    final bool selected = _returnQuantities.containsKey(product.id);
    final int quantity = _returnQuantities[product.id] ?? 1;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF7F5) : const Color(0xFFFAFAFA),
        border: Border.all(
          color: selected ? _maroon.withOpacity(0.25) : _border,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Checkbox(
            value: selected,
            activeColor: _maroon,
            onChanged: _submittingReturn
                ? null
                : (bool? value) {
                    setState(() {
                      if (value == true) {
                        _returnQuantities[product.id] = 1;
                      } else {
                        _returnQuantities.remove(product.id);
                      }
                    });
                  },
          ),
          Expanded(child: _SelectedProduct(product: product)),
          if (selected) ...[
            const SizedBox(width: 8),
            DropdownButton<int>(
              value: quantity,
              underline: const SizedBox.shrink(),
              items: List<DropdownMenuItem<int>>.generate(
                product.safeQuantity,
                (int index) => DropdownMenuItem<int>(
                  value: index + 1,
                  child: Text('Qty ${index + 1}'),
                ),
              ),
              onChanged: _submittingReturn
                  ? null
                  : (int? value) {
                      if (value != null) {
                        setState(() => _returnQuantities[product.id] = value);
                      }
                    },
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReturnEvidenceTile(int index) {
    final XFile file = _returnEvidence[index];
    return SizedBox(
      width: 76,
      height: 76,
      child: Stack(
        children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: FutureBuilder<List<int>>(
                future: file.readAsBytes(),
                builder:
                    (BuildContext context, AsyncSnapshot<List<int>> snapshot) {
                      if (!snapshot.hasData) {
                        return const ColoredBox(
                          color: _soft,
                          child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        );
                      }
                      return Image.memory(
                        Uint8List.fromList(snapshot.data!),
                        fit: BoxFit.cover,
                      );
                    },
              ),
            ),
          ),
          Positioned(
            top: 2,
            right: 2,
            child: InkWell(
              onTap: _submittingReturn
                  ? null
                  : () => setState(() => _returnEvidence.removeAt(index)),
              borderRadius: BorderRadius.circular(24),
              child: const CircleAvatar(
                radius: 12,
                backgroundColor: _maroon,
                child: Icon(Icons.close_rounded, color: Colors.white, size: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReturnMode() {
    final BuyerOrderData? order = _selectedOrder;

    if (order == null) {
      return _buildOrderNotFound();
    }

    return Form(
      key: _returnFormKey,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
        children: [
          Text(
            'ORDER #${order.id}',
            style: const TextStyle(
              color: _maroon,
              fontSize: 11,
              letterSpacing: 1.6,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 6),

          const Text(
            'Return / Refund Request',
            style: TextStyle(
              color: _text,
              fontSize: 25,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          const Text(
            'Select the affected items, describe the issue, and attach clear photos.',
            style: TextStyle(color: _muted, fontSize: 12.5),
          ),

          if (order.returnDeadlineForDisplay != null) ...[
            const SizedBox(height: 8),
            Text(
              order.canRequestReturn
                  ? 'Submit by ' +
                        _formatBuyerReturnDate(
                          order.returnDeadlineForDisplay!,
                        ) +
                        '. Eligibility ends after this date.'
                  : order.returnRequestSubtitle,
              style: const TextStyle(
                color: _maroon,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 17),

          Container(
            padding: const EdgeInsets.all(15),
            decoration: BoxDecoration(
              color: _surface,
              border: Border.all(color: _border),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _InputLabel(text: 'Items affected'),

                const SizedBox(height: 7),

                for (final BuyerOrderProductData product in order.products)
                  _buildReturnItemSelector(product),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Divider(height: 1, color: _border),
                ),

                const _InputLabel(text: 'Issue category'),

                const SizedBox(height: 7),

                DropdownButtonFormField<String>(
                  initialValue: _returnIssueCategory,
                  isExpanded: true,
                  decoration: _inputDecoration(hintText: 'Choose an issue'),
                  items: _returnIssueLabels.entries.map((
                    MapEntry<String, String> entry,
                  ) {
                    return DropdownMenuItem<String>(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: _submittingReturn
                      ? null
                      : (String? value) {
                          setState(() {
                            _returnIssueCategory = value;
                            _returnReason = null;
                          });
                        },
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Choose an issue category.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Specific issue'),

                const SizedBox(height: 7),

                DropdownButtonFormField<String>(
                  initialValue: _returnReason,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText: 'Choose what happened',
                  ),
                  items:
                      (_returnIssueReasons[_returnIssueCategory] ??
                              const <String>[])
                          .map((String reason) {
                            return DropdownMenuItem<String>(
                              value: reason,
                              child: Text(reason),
                            );
                          })
                          .toList(),
                  onChanged: _submittingReturn
                      ? null
                      : (String? value) {
                          setState(() {
                            _returnReason = value;
                          });
                        },
                  validator: (String? value) {
                    if (value == null || value.isEmpty) {
                      return 'Choose the specific issue.';
                    }

                    if (value.length > 255) {
                      return 'Reason must not exceed 255 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Refund method'),

                const SizedBox(height: 7),

                DropdownButtonFormField<String>(
                  initialValue: _returnRefundMethod,
                  isExpanded: true,
                  decoration: _inputDecoration(
                    hintText: 'Choose a refund method',
                  ),
                  items: const <DropdownMenuItem<String>>[
                    DropdownMenuItem<String>(
                      value: 'original_payment_method',
                      child: Text('Original payment method'),
                    ),
                    DropdownMenuItem<String>(
                      value: 'cash',
                      child: Text('Cash refund'),
                    ),
                  ],
                  onChanged: _submittingReturn
                      ? null
                      : (String? value) {
                          if (value == null) return;
                          setState(() => _returnRefundMethod = value);
                        },
                  validator: (String? value) => value == null || value.isEmpty
                      ? 'Choose a refund method.'
                      : null,
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Contact email'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _returnEmailController,
                  enabled: !_submittingReturn,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: _inputDecoration(
                    hintText: 'Email for case updates',
                  ),
                  validator: (String? value) {
                    final String email = value?.trim() ?? '';
                    if (email.isEmpty) return 'Enter your email address.';
                    if (!RegExp(
                      r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                    ).hasMatch(email)) {
                      return 'Enter a valid email address.';
                    }
                    if (email.length > 255) return 'Email address is too long.';
                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Describe the issue'),

                const SizedBox(height: 7),

                TextFormField(
                  controller: _returnDetailsController,
                  enabled: !_submittingReturn,
                  minLines: 5,
                  maxLines: 7,
                  maxLength: 2000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: _inputDecoration(
                    hintText: 'Give enough detail to review this request.',
                  ),
                  validator: (String? value) {
                    final String text = value?.trim() ?? '';

                    if (text.isEmpty) {
                      return 'Explain what happened.';
                    }

                    if (text.length < 10) {
                      return 'Please provide at least 10 characters.';
                    }

                    if (text.length > 2000) {
                      return 'Details must not exceed 2000 characters.';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 16),

                const _InputLabel(text: 'Photo evidence'),

                const SizedBox(height: 4),

                const Text(
                  'Add at least one clear photo. Up to five photos, 5 MB each.',
                  style: TextStyle(color: _muted, fontSize: 11.5),
                ),

                const SizedBox(height: 9),

                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (int index = 0; index < _returnEvidence.length; index++)
                      _buildReturnEvidenceTile(index),
                    if (_returnEvidence.length < 5)
                      OutlinedButton(
                        key: const ValueKey<String>(
                          'buyer-return-add-evidence',
                        ),
                        onPressed: _submittingReturn
                            ? null
                            : _addReturnEvidence,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _maroon,
                          side: const BorderSide(color: _border),
                          minimumSize: const Size(76, 76),
                          padding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Icon(Icons.add_photo_alternate_outlined),
                      ),
                  ],
                ),

                const SizedBox(height: 12),

                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _confirmReturnCashTerms,
                    activeColor: _maroon,
                    title: const Text(
                      'I understand the refund amount and method follow the platform’s return and refund policy.',
                      style: TextStyle(
                        color: _text,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    onChanged: _submittingReturn
                        ? null
                        : (bool? value) => setState(
                            () => _confirmReturnCashTerms = value ?? false,
                          ),
                  ),
                ),

                Material(
                  color: Colors.transparent,
                  child: CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    value: _confirmReturnRequest,
                    activeColor: _maroon,
                    title: const Text(
                      'I confirm these details are accurate and authorize this request to be reviewed.',
                      style: TextStyle(
                        color: _text,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                    onChanged: _submittingReturn
                        ? null
                        : (bool? value) => setState(
                            () => _confirmReturnRequest = value ?? false,
                          ),
                  ),
                ),

                const SizedBox(height: 15),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF7E7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Submitting this form creates a request for review. It does not automatically mean the refund or return has been approved.',
                    style: TextStyle(
                      color: Color(0xFF7A5115),
                      fontSize: 11.5,
                      height: 1.5,
                    ),
                  ),
                ),

                if (_returnSubmissionError != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFEFEE),
                      border: Border.all(color: const Color(0xFFF4B7B2)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _danger,
                          size: 19,
                        ),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Request not submitted',
                                style: TextStyle(
                                  color: _danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              SelectableText(
                                _returnSubmissionError!,
                                style: const TextStyle(
                                  color: Color(0xFF7A271A),
                                  fontSize: 12,
                                  height: 1.45,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 17),

                SizedBox(
                  width: double.infinity,
                  height: 49,
                  child: ElevatedButton(
                    onPressed: _submittingReturn ? null : _submitReturn,
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      backgroundColor: _maroon,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: _submittingReturn
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Submit Request',
                            style: TextStyle(fontWeight: FontWeight.w800),
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

  Widget _buildOrderNotFound() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(30),
      children: [
        const SizedBox(height: 80),

        const Icon(Icons.search_off_rounded, size: 58, color: _muted2),

        const SizedBox(height: 15),

        const Text(
          'Order not found',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _text,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),

        const SizedBox(height: 7),

        const Text(
          'This order is unavailable or does not belong to your account.',
          textAlign: TextAlign.center,
          style: TextStyle(color: _muted, fontSize: 12.5),
        ),

        const SizedBox(height: 18),

        Center(
          child: OutlinedButton(
            onPressed: _openIndex,
            child: const Text('Back to Orders'),
          ),
        ),
      ],
    );
  }

  InputDecoration _inputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _muted2, fontSize: 12.5),
      filled: true,
      fillColor: _soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _maroon, width: 1.3),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _danger, width: 1.3),
      ),
    );
  }

  InputDecoration _sheetInputDecoration({required String hintText}) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(color: _muted2, fontSize: 12.5),
      filled: true,
      fillColor: _soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _maroon),
      ),
    );
  }

  static String _formatPrice(double value) {
    return formatPesoAmount(value);
  }
}

class _OrderCard extends StatelessWidget {
  final BuyerOrderData order;

  final VoidCallback? onOpen;
  final VoidCallback? onTrack;
  final VoidCallback? onCancel;
  final VoidCallback? onReceive;
  final VoidCallback? onReview;
  final VoidCallback? onReturn;
  final VoidCallback? onBuyAgain;
  final VoidCallback? onConfirmDeliveryPin;
  final bool confirmingDeliveryPin;
  final VoidCallback? onContactSeller;
  final VoidCallback? onViewStore;

  final bool receiving;

  const _OrderCard({
    required this.order,
    required this.onOpen,
    required this.onTrack,
    required this.onCancel,
    required this.onReceive,
    required this.onReview,
    required this.onReturn,
    required this.onBuyAgain,
    required this.onConfirmDeliveryPin,
    required this.confirmingDeliveryPin,
    required this.onContactSeller,
    required this.onViewStore,
    required this.receiving,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: ShopColors.surface,
        border: Border.all(color: ShopColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
            decoration: const BoxDecoration(color: Color(0xFFFAF5EF)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Order ${order.orderNumber?.trim().isNotEmpty == true ? order.orderNumber!.trim() : order.id}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.text,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_placedLabel(order.createdAt).isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _placedLabel(order.createdAt),
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),

          if (order.sellerName?.trim().isNotEmpty == true)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 11),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.storefront_outlined,
                        size: 17,
                        color: ShopColors.accentDark,
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          order.sellerName!.trim(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: ShopColors.text,
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (onContactSeller != null || onViewStore != null) ...[
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 12,
                      children: [
                        if (onContactSeller != null)
                          _SellerAction(
                            text: 'Chat',
                            onPressed: onContactSeller!,
                          ),
                        if (onViewStore != null)
                          _SellerAction(
                            text: 'View Shop',
                            onPressed: onViewStore!,
                          ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

          if (order.tabStatus != 'cancelled' && order.tabStatus != 'returns')
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: _ParcelUpdateCard(
                order: order,
                onTap:
                    (order.tracking?.trim().isNotEmpty == true ||
                        order.shipmentId?.trim().isNotEmpty == true)
                    ? onTrack
                    : null,
              ),
            ),

          if (order.products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'No products recorded for this order.',
                  style: TextStyle(color: ShopColors.muted, fontSize: 12.5),
                ),
              ),
            )
          else
            Column(
              children: List<Widget>.generate(order.products.length, (
                int index,
              ) {
                return _OrderProductRow(
                  product: order.products[index],
                  showDivider: index != order.products.length - 1,
                );
              }, growable: false),
            ),

          const Divider(height: 1, color: ShopColors.border),

          Padding(
            padding: const EdgeInsets.all(13),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${_itemCount(order)} ${_itemCount(order) == 1 ? 'item' : 'items'} - Total',
                    style: const TextStyle(
                      color: ShopColors.muted,
                      fontSize: 11.5,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: order.payment),
                            const TextSpan(text: ' - '),
                            TextSpan(
                              text: _price(order.total),
                              style: const TextStyle(
                                color: ShopColors.text,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),

                if (onOpen != null ||
                    onTrack != null ||
                    onCancel != null ||
                    onReceive != null ||
                    onReview != null ||
                    onReturn != null ||
                    onBuyAgain != null ||
                    onConfirmDeliveryPin != null ||
                    confirmingDeliveryPin) ...[
                  const SizedBox(height: 12),

                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      alignment: WrapAlignment.end,
                      spacing: 7,
                      runSpacing: 7,
                      children: [
                        if (onBuyAgain != null)
                          _SmallActionButton(
                            text: 'Buy Again',
                            onPressed: onBuyAgain,
                          ),

                        if (onConfirmDeliveryPin != null ||
                            confirmingDeliveryPin)
                          _SmallActionButton(
                            text: confirmingDeliveryPin
                                ? 'Confirming...'
                                : 'Confirm delivery pin',
                            onPressed: confirmingDeliveryPin
                                ? null
                                : onConfirmDeliveryPin,
                          ),

                        if (onCancel != null)
                          _SmallActionButton(
                            text: 'Cancel',
                            onPressed: onCancel,
                            danger: true,
                          ),

                        if (onReturn != null)
                          _SmallActionButton(
                            text: 'Return / Refund',
                            onPressed: onReturn,
                          ),

                        if (onReview != null)
                          _SmallActionButton(
                            text: 'Review',
                            onPressed: onReview,
                          ),

                        if (onReceive != null)
                          _SmallActionButton(
                            text: receiving ? 'Updating...' : 'Order Received',
                            onPressed: receiving ? null : onReceive,
                            filled: true,
                          ),

                        if (onTrack != null &&
                            (order.tracking?.trim().isNotEmpty == true ||
                                order.shipmentId?.trim().isNotEmpty == true))
                          _SmallActionButton(
                            text: 'Track Parcel',
                            onPressed: onTrack,
                            filled: onReceive == null,
                          ),

                        if (onOpen != null)
                          _SmallActionButton(
                            text: 'View Details',
                            onPressed: onOpen,
                            filled: false,
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _placedLabel(DateTime? value) {
    if (value == null) {
      return '';
    }

    const List<String> months = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    final DateTime local = value.toLocal();

    return '${months[local.month - 1]} ${local.day}, ${local.year}';
  }

  static int _itemCount(BuyerOrderData order) {
    return order.products.fold<int>(
      0,
      (int total, BuyerOrderProductData product) =>
          total + product.safeQuantity,
    );
  }

  static String _price(double value) {
    return formatPesoAmount(value);
  }
}

class _ParcelUpdateCard extends StatelessWidget {
  final BuyerOrderData order;
  final VoidCallback? onTap;

  const _ParcelUpdateCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final BuyerOrderTimelineEvent? latestEvent = order.timeline.isEmpty
        ? null
        : order.timeline.last;
    final String title = latestEvent?.label.trim().isNotEmpty == true
        ? latestEvent!.label
        : order.statusLabel;
    final String details = latestEvent?.details.trim().isNotEmpty == true
        ? latestEvent!.details
        : _fallbackDetails;
    final String trackingReference = order.tracking?.trim().isNotEmpty == true
        ? order.tracking!.trim()
        : order.shipmentId?.trim() ?? '';

    return Material(
      color: const Color(0xFFEEF9F6),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.local_shipping_outlined,
                  color: Color(0xFF338D78),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (trackingReference.isNotEmpty) ...[
                      Text(
                        'Parcel 1 - Tracking $trackingReference',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                    ],
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF267B69),
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      details,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.muted,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                    if (latestEvent?.time.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 5),
                      Text(
                        latestEvent!.time,
                        style: const TextStyle(
                          color: Color(0xFF6F9188),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (onTap != null) ...[
                const SizedBox(width: 6),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF6F9188),
                  size: 22,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String get _fallbackDetails {
    if (order.riderLocation != null) {
      return 'Your rider is on the way. Live location is available.';
    }
    if (order.tracking?.trim().isNotEmpty == true) {
      return 'Tracking is active. Waiting for the next parcel update.';
    }
    return switch (order.tabStatus) {
      'to-pay' => 'Waiting for payment confirmation.',
      'to-ship' => 'The seller is preparing your parcel.',
      'to-receive' => 'Parcel updates will appear here as it moves.',
      'completed' => 'This order has been delivered.',
      _ => 'Parcel updates will appear here when available.',
    };
  }
}

class _OrderProductRow extends StatelessWidget {
  final BuyerOrderProductData product;
  final bool showDivider;

  const _OrderProductRow({required this.product, required this.showDivider});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(15, 12, 15, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 66,
                height: 66,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: ShopColors.soft,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: ShopColors.border),
                ),
                child: _OrderProductGallery(images: product.galleryImages),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ShopColors.text,
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    if (product.variant?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 4),
                      Text(
                        product.variant!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 11.5,
                        ),
                      ),
                    ],

                    const SizedBox(height: 5),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: ShopColors.soft,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Qty ${product.safeQuantity}',
                            style: const TextStyle(
                              color: ShopColors.secondaryText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          formatPesoAmount(product.lineTotal),
                          style: const TextStyle(
                            color: ShopColors.accentDark,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
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

        if (showDivider) const Divider(height: 1, color: ShopColors.border),
      ],
    );
  }
}

class _SellerAction extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _SellerAction({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(5),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(
          text,
          style: const TextStyle(
            color: ShopColors.accentDark,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _SmallActionButton extends StatelessWidget {
  final String text;

  final VoidCallback? onPressed;

  final bool filled;
  final bool danger;

  const _SmallActionButton({
    required this.text,
    required this.onPressed,
    this.filled = false,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    if (filled) {
      return SizedBox(
        height: 38,
        child: ElevatedButton(
          onPressed: onPressed,
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: ShopColors.accent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          child: Text(
            text,
            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
          ),
        ),
      );
    }

    return SizedBox(
      height: 38,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? const Color(0xFFB42318) : ShopColors.accent,
          side: BorderSide(
            color: danger ? const Color(0xFFE5B4A9) : ShopColors.tan,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800),
        ),
      ),
    );
  }
}

class _BuyerDetailCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _BuyerDetailCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: ShopColors.surface,
        border: Border.all(color: ShopColors.border),
        borderRadius: BorderRadius.circular(20),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class _BuyerDetailActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  const _BuyerDetailActionRow({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: ShopColors.soft,
                borderRadius: BorderRadius.circular(11),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                color: onTap == null
                    ? ShopColors.faint
                    : ShopColors.secondaryText,
                size: 18,
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: onTap == null
                          ? ShopColors.secondaryText
                          : ShopColors.text,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        color: ShopColors.muted,
                        fontSize: 10.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null) ...[
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(
                  Icons.chevron_right_rounded,
                  color: ShopColors.faint,
                  size: 23,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BuyerDetailBottomButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool filled;

  const _BuyerDetailBottomButton({
    required this.label,
    required this.onPressed,
    this.filled = false,
  });

  @override
  Widget build(BuildContext context) {
    final ButtonStyle style = filled
        ? ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: ShopColors.accent,
            foregroundColor: Colors.white,
            disabledBackgroundColor: const Color(0xFFD8CBC3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: ShopColors.accent,
            side: const BorderSide(color: ShopColors.accent),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          );

    return SizedBox(
      height: 48,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
    );
  }
}

class _SelectedProduct extends StatelessWidget {
  final BuyerOrderProductData product;

  const _SelectedProduct({required this.product});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: ShopColors.soft,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _OrderProductGallery(images: product.galleryImages),
        ),

        const SizedBox(width: 11),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(
                  color: ShopColors.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),

              if (product.variant?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 4),

                Text(
                  product.variant!,
                  style: const TextStyle(color: ShopColors.muted, fontSize: 11),
                ),
              ],

              const SizedBox(height: 4),

              Text(
                'Qty ${product.safeQuantity}',
                style: const TextStyle(color: ShopColors.faint, fontSize: 11),
              ),
            ],
          ),
        ),

        Text(
          formatPesoAmount(product.lineTotal),
          style: const TextStyle(
            color: ShopColors.accent,
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _OrderProductGallery extends StatefulWidget {
  final List<String> images;

  const _OrderProductGallery({required this.images});

  @override
  State<_OrderProductGallery> createState() => _OrderProductGalleryState();
}

class _OrderProductGalleryState extends State<_OrderProductGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final List<String> images = widget.images;
    if (images.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: ShopColors.faint, size: 28),
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
            return _OrderProductImage(url: images[index]);
          },
        ),
        if (images.length > 1)
          Positioned(
            left: 0,
            right: 0,
            bottom: 4,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List<Widget>.generate(images.length, (int index) {
                final bool active = index == _currentIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  margin: const EdgeInsets.symmetric(horizontal: 1.5),
                  width: active ? 9 : 4,
                  height: 3,
                  decoration: BoxDecoration(
                    color: active
                        ? ShopColors.accent
                        : ShopColors.faint.withValues(alpha: 0.55),
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

class _OrderProductImage extends StatelessWidget {
  final String? url;
  const _OrderProductImage({required this.url});
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

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: ShopColors.muted, fontSize: 12),
          ),
        ),

        const SizedBox(width: 12),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: ShopColors.text,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _InputLabel extends StatelessWidget {
  final String text;

  final bool requiredField;

  const _InputLabel({required this.text, this.requiredField = true});

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: text),

          if (requiredField)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFB42318)),
            ),
        ],
      ),
      style: const TextStyle(
        color: ShopColors.text,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  final String message;

  const _NoticeCard({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCECE7),
        border: Border.all(color: const Color(0xFFEBC9C0)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: ShopColors.accent,
            size: 18,
          ),

          const SizedBox(width: 8),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: ShopColors.accent,
                fontSize: 12,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

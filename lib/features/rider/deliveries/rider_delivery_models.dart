class RiderDeliveryData {
  final int id;

  final String trackingCode;

  final String buyerName;

  final String contact;

  final String address;

  final double amount;

  final String status;

  final String statusLabel;

  final String? imageUrl;

  final String? failureReason;

  final double? deliveryLatitude;

  final double? deliveryLongitude;

  final bool isPreview;

  const RiderDeliveryData({
    required this.id,
    required this.trackingCode,
    required this.buyerName,
    required this.contact,
    required this.address,
    required this.amount,
    required this.status,
    required this.statusLabel,
    this.imageUrl,
    this.failureReason,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.isPreview = false,
  });

  factory RiderDeliveryData.fromApi(Map<String, dynamic> json) {
    final Map<String, dynamic>? order = _asMap(
      json['order'] ?? json['shipment'],
    );
    final dynamic rawBuyer = json['buyer'] ?? order?['buyer'];
    final Map<String, dynamic>? buyer = _asMap(rawBuyer);
    final dynamic rawAddress =
        json['delivery_address'] ??
        json['shipping_address'] ??
        json['address'] ??
        order?['delivery_address'] ??
        order?['shipping_address'] ??
        order?['address'];
    final Map<String, dynamic>? address = _asMap(rawAddress);
    final dynamic rawLocation =
        json['delivery_location'] ??
        json['buyer_location'] ??
        json['shipping_location'] ??
        json['destination'] ??
        json['delivery_coordinates'] ??
        json['coordinates'] ??
        order?['delivery_location'] ??
        order?['shipping_location'] ??
        order?['delivery_coordinates'] ??
        order?['coordinates'] ??
        address?['location'] ??
        address ??
        buyer?['location'] ??
        buyer;
    final Map<String, dynamic>? location = rawLocation is Map
        ? Map<String, dynamic>.from(rawLocation)
        : null;
    final List<dynamic>? coordinatePair = _parseCoordinatePair(rawLocation);

    return RiderDeliveryData(
      id: int.tryParse((json['id'] ?? 0).toString()) ?? 0,
      trackingCode: (json['tracking'] ?? json['tracking_code'] ?? '')
          .toString(),
      buyerName:
          (json['buyer_name'] ??
                  buyer?['name'] ??
                  (rawBuyer is String ? rawBuyer : null) ??
                  'Buyer')
              .toString(),
      contact:
          (json['contact'] ??
                  json['buyer_contact'] ??
                  buyer?['contact_number'] ??
                  buyer?['phone'] ??
                  'Not available')
              .toString(),
      address: _parseAddress(rawAddress),
      amount: _parseAmount(
        json['amount'] ?? json['subtotal'] ?? json['total'] ?? 0,
      ),
      status: (json['status'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? json['status'] ?? '').toString(),
      imageUrl: (json['image'] ?? json['image_url'])?.toString(),
      failureReason: (json['failure_reason'] ?? json['failure_note'])
          ?.toString(),
      deliveryLatitude: _parseCoordinate(
        json['delivery_latitude'] ??
            json['delivery_lat'] ??
            json['buyer_latitude'] ??
            json['buyer_lat'] ??
            json['latitude'] ??
            json['lat'] ??
            order?['delivery_latitude'] ??
            order?['delivery_lat'] ??
            location?['latitude'] ??
            location?['lat'] ??
            (coordinatePair != null ? coordinatePair[1] : null),
      ),
      deliveryLongitude: _parseCoordinate(
        json['delivery_longitude'] ??
            json['delivery_lng'] ??
            json['buyer_longitude'] ??
            json['buyer_lng'] ??
            json['longitude'] ??
            json['lng'] ??
            json['lon'] ??
            order?['delivery_longitude'] ??
            order?['delivery_lng'] ??
            location?['longitude'] ??
            location?['lng'] ??
            location?['lon'] ??
            (coordinatePair != null ? coordinatePair[0] : null),
      ),
      isPreview: json['is_preview'] == true,
    );
  }

  String get normalizedStatus {
    return status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');
  }

  bool get isAssigned {
    return normalizedStatus == 'assigned';
  }

  bool get isPickedUp {
    return normalizedStatus == 'picked_up';
  }

  bool get isInTransit {
    return normalizedStatus == 'in_transit';
  }

  bool get isOutForDelivery {
    return normalizedStatus == 'out_for_delivery';
  }

  bool get isDelivered {
    return normalizedStatus == 'delivered';
  }

  bool get isFailed {
    return normalizedStatus == 'failed' ||
        normalizedStatus == 'delivery_failed';
  }

  bool get hasDeliveryCoordinates {
    final double? latitude = deliveryLatitude;
    final double? longitude = deliveryLongitude;
    return latitude != null &&
        longitude != null &&
        latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180 &&
        (latitude != 0 || longitude != 0);
  }

  RiderDeliveryData copyWith({
    int? id,
    String? trackingCode,
    String? buyerName,
    String? contact,
    String? address,
    double? amount,
    String? status,
    String? statusLabel,
    String? imageUrl,
    String? failureReason,
    double? deliveryLatitude,
    double? deliveryLongitude,
    bool? isPreview,
  }) {
    return RiderDeliveryData(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      buyerName: buyerName ?? this.buyerName,
      contact: contact ?? this.contact,
      address: address ?? this.address,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      failureReason: failureReason,
      deliveryLatitude: deliveryLatitude ?? this.deliveryLatitude,
      deliveryLongitude: deliveryLongitude ?? this.deliveryLongitude,
      isPreview: isPreview ?? this.isPreview,
    );
  }

  static double _parseAmount(dynamic value) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    String text = value.toString().trim();

    text = text
        .replaceAll('₱', '')
        .replaceAll('PHP', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(text) ?? 0;
  }

  static double? _parseCoordinate(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value?.toString().trim() ?? '');
  }

  static List<dynamic>? _parseCoordinatePair(dynamic value) {
    if (value is List && value.length >= 2) {
      return value;
    }

    if (value is! Map) {
      return null;
    }

    final Map<String, dynamic> map = Map<String, dynamic>.from(value);
    final dynamic coordinates = map['coordinates'];
    if (coordinates is List && coordinates.length >= 2) {
      return coordinates;
    }

    return _parseCoordinatePair(map['geometry'] ?? map['location']);
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static String _parseAddress(dynamic value) {
    if (value is! Map) {
      return value?.toString().trim() ?? '';
    }

    final Map<String, dynamic> address = Map<String, dynamic>.from(value);
    final String formatted =
        (address['formatted_address'] ??
                address['full_address'] ??
                address['label'] ??
                '')
            .toString()
            .trim();
    if (formatted.isNotEmpty) {
      return formatted;
    }

    return <dynamic>[
          address['house_number'],
          address['street'],
          address['barangay'],
          address['municipality'] ?? address['city'],
          address['province'] ?? address['state'],
          address['postal_code'] ?? address['zip_code'],
          address['country'],
        ]
        .where(
          (dynamic part) => part != null && part.toString().trim().isNotEmpty,
        )
        .map((dynamic part) => part.toString().trim())
        .join(', ');
  }
}

class RiderDeliveryStatsData {
  final int assigned;

  final int outForDelivery;

  final int deliveredToday;

  final int failedToday;

  const RiderDeliveryStatsData({
    required this.assigned,
    required this.outForDelivery,
    required this.deliveredToday,
    required this.failedToday,
  });

  factory RiderDeliveryStatsData.fromApi(Map<String, dynamic> json) {
    return RiderDeliveryStatsData(
      assigned: int.tryParse((json['assigned'] ?? 0).toString()) ?? 0,
      outForDelivery:
          int.tryParse((json['out_for_delivery'] ?? 0).toString()) ?? 0,
      deliveredToday:
          int.tryParse((json['delivered_today'] ?? 0).toString()) ?? 0,
      failedToday: int.tryParse((json['failed_today'] ?? 0).toString()) ?? 0,
    );
  }

  int get totalActive {
    return assigned + outForDelivery;
  }
}

class RiderDeliveryTransitionRequest {
  final RiderDeliveryData delivery;

  final String status;

  final String? note;

  final String? receiverName;

  final String? proofPath;

  const RiderDeliveryTransitionRequest({
    required this.delivery,
    required this.status,
    this.note,
    this.receiverName,
    this.proofPath,
  });

  Map<String, dynamic> toFields() {
    final Map<String, dynamic> data = <String, dynamic>{'status': status};

    if (note != null && note!.trim().isNotEmpty) {
      data['note'] = note!.trim();
    }

    if (receiverName != null && receiverName!.trim().isNotEmpty) {
      data['receiver_name'] = receiverName!.trim();
    }

    return data;
  }

  bool get requiresFailureNote {
    return status.trim().toLowerCase() == 'failed';
  }

  bool get requiresDeliveryProof {
    return status.trim().toLowerCase() == 'delivered';
  }

  bool get isValid {
    final String normalized = status
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    const Set<String> allowed = <String>{
      'accepted',
      'picked_up',
      'in_transit',
      'out_for_delivery',
      'delivered',
      'failed',
    };

    if (!allowed.contains(normalized)) {
      return false;
    }

    if (normalized == 'failed') {
      return note != null && note!.trim().isNotEmpty;
    }

    if (normalized == 'delivered') {
      return receiverName != null &&
          receiverName!.trim().isNotEmpty &&
          proofPath != null &&
          proofPath!.trim().isNotEmpty;
    }

    return true;
  }
}

typedef RiderDeliveryCallback = void Function(RiderDeliveryData delivery);

typedef RiderDeliveryRefreshCallback = Future<void> Function();

typedef RiderDeliveryTransitionCallback =
    Future<void> Function(RiderDeliveryTransitionRequest request);

typedef RiderProofPickerCallback = Future<String?> Function();

typedef RiderExternalActionCallback =
    Future<void> Function(RiderDeliveryData delivery);

String formatRiderMoney(double amount) {
  return '₱${amount.toStringAsFixed(2)}';
}

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

  factory RiderDeliveryData.fromApi(
    Map<String, dynamic> json,
  ) {
    final dynamic rawLocation =
        json['delivery_location'] ??
            json['buyer_location'] ??
            json['shipping_location'] ??
            json['destination'];
    final Map<String, dynamic>? location =
        rawLocation is Map
            ? Map<String, dynamic>.from(
                rawLocation,
              )
            : null;

    return RiderDeliveryData(
      id: int.tryParse(
            (json['id'] ?? 0).toString(),
          ) ??
          0,
      trackingCode:
          (json['tracking'] ??
                  json['tracking_code'] ??
                  '')
              .toString(),
      buyerName:
          (json['buyer'] ??
                  json['buyer_name'] ??
                  'Buyer')
              .toString(),
      contact:
          (json['contact'] ??
                  json['buyer_contact'] ??
                  'Not available')
              .toString(),
      address:
          (json['address'] ??
                  json['delivery_address'] ??
                  '')
              .toString(),
      amount: _parseAmount(
        json['amount'] ??
            json['subtotal'] ??
            json['total'] ??
            0,
      ),
      status:
          (json['status'] ?? '').toString(),
      statusLabel:
          (json['status_label'] ??
                  json['status'] ??
                  '')
              .toString(),
      imageUrl:
          (json['image'] ??
                  json['image_url'])
              ?.toString(),
      failureReason:
          (json['failure_reason'] ??
                  json['failure_note'])
              ?.toString(),
      deliveryLatitude: _parseCoordinate(
        json['delivery_latitude'] ??
            json['delivery_lat'] ??
            json['buyer_latitude'] ??
            json['buyer_lat'] ??
            location?['latitude'] ??
            location?['lat'],
      ),
      deliveryLongitude: _parseCoordinate(
        json['delivery_longitude'] ??
            json['delivery_lng'] ??
            json['buyer_longitude'] ??
            json['buyer_lng'] ??
            location?['longitude'] ??
            location?['lng'] ??
            location?['lon'],
      ),
      isPreview:
          json['is_preview'] == true,
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
    return normalizedStatus ==
        'assigned';
  }

  bool get isPickedUp {
    return normalizedStatus ==
        'picked_up';
  }

  bool get isInTransit {
    return normalizedStatus ==
        'in_transit';
  }

  bool get isOutForDelivery {
    return normalizedStatus ==
        'out_for_delivery';
  }

  bool get isDelivered {
    return normalizedStatus ==
        'delivered';
  }

  bool get isFailed {
    return normalizedStatus ==
            'failed' ||
        normalizedStatus ==
            'delivery_failed';
  }

  bool get hasDeliveryCoordinates {
    return deliveryLatitude != null &&
        deliveryLongitude != null;
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
      id:
          id ??
              this.id,
      trackingCode:
          trackingCode ??
              this.trackingCode,
      buyerName:
          buyerName ??
              this.buyerName,
      contact:
          contact ??
              this.contact,
      address:
          address ??
              this.address,
      amount:
          amount ??
              this.amount,
      status:
          status ??
              this.status,
      statusLabel:
          statusLabel ??
              this.statusLabel,
      imageUrl:
          imageUrl ??
              this.imageUrl,
      failureReason:
          failureReason,
      deliveryLatitude:
          deliveryLatitude ??
              this.deliveryLatitude,
      deliveryLongitude:
          deliveryLongitude ??
              this.deliveryLongitude,
      isPreview:
          isPreview ??
              this.isPreview,
    );
  }

  static double _parseAmount(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    String text =
        value.toString().trim();

    text = text
        .replaceAll('₱', '')
        .replaceAll('PHP', '')
        .replaceAll(',', '')
        .trim();

    return double.tryParse(
          text,
        ) ??
        0;
  }

  static double? _parseCoordinate(
    dynamic value,
  ) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value?.toString().trim() ?? '',
    );
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

  factory RiderDeliveryStatsData.fromApi(
    Map<String, dynamic> json,
  ) {
    return RiderDeliveryStatsData(
      assigned: int.tryParse(
            (json['assigned'] ?? 0)
                .toString(),
          ) ??
          0,
      outForDelivery:
          int.tryParse(
                (json['out_for_delivery'] ??
                        0)
                    .toString(),
              ) ??
              0,
      deliveredToday:
          int.tryParse(
                (json['delivered_today'] ??
                        0)
                    .toString(),
              ) ??
              0,
      failedToday:
          int.tryParse(
                (json['failed_today'] ??
                        0)
                    .toString(),
              ) ??
              0,
    );
  }

  int get totalActive {
    return assigned +
        outForDelivery;
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
    final Map<String, dynamic> data =
        <String, dynamic>{
      'status': status,
    };

    if (note != null &&
        note!.trim().isNotEmpty) {
      data['note'] =
          note!.trim();
    }

    if (receiverName != null &&
        receiverName!
            .trim()
            .isNotEmpty) {
      data['receiver_name'] =
          receiverName!.trim();
    }

    return data;
  }

  bool get requiresFailureNote {
    return status
            .trim()
            .toLowerCase() ==
        'failed';
  }

  bool get requiresDeliveryProof {
    return status
            .trim()
            .toLowerCase() ==
        'delivered';
  }

  bool get isValid {
    final String normalized =
        status
            .trim()
            .toLowerCase()
            .replaceAll('-', '_')
            .replaceAll(' ', '_');

    const Set<String> allowed =
        <String>{
      'picked_up',
      'in_transit',
      'out_for_delivery',
      'delivered',
      'failed',
    };

    if (!allowed.contains(
      normalized,
    )) {
      return false;
    }

    if (normalized ==
        'failed') {
      return note != null &&
          note!
              .trim()
              .isNotEmpty;
    }

    if (normalized ==
        'delivered') {
      return receiverName != null &&
          receiverName!
              .trim()
              .isNotEmpty &&
          proofPath != null &&
          proofPath!
              .trim()
              .isNotEmpty;
    }

    return true;
  }
}

typedef RiderDeliveryCallback =
    void Function(
  RiderDeliveryData delivery,
);

typedef RiderDeliveryRefreshCallback =
    Future<void> Function();

typedef RiderDeliveryTransitionCallback =
    Future<void> Function(
  RiderDeliveryTransitionRequest request,
);

typedef RiderProofPickerCallback =
    Future<String?> Function();

typedef RiderExternalActionCallback =
    Future<void> Function(
  RiderDeliveryData delivery,
);

String formatRiderMoney(
  double amount,
) {
  return '₱${amount.toStringAsFixed(2)}';
}

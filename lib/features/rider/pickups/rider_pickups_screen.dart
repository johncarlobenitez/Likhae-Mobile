import 'dart:async';

import 'package:flutter/material.dart';
import '../../../shared/widgets/sized_network_image.dart';
import '../rider_product_image.dart';

class RiderPickupStatsData {
  final int ready;
  final int accepted;
  final int pickedUp;
  final int completedToday;

  const RiderPickupStatsData({
    required this.ready,
    required this.accepted,
    required this.pickedUp,
    this.completedToday = 0,
  });

  factory RiderPickupStatsData.fromApi(Map<String, dynamic> json) {
    return RiderPickupStatsData(
      ready: _toInt(json['assigned'] ?? json['ready']),
      accepted: _toInt(json['accepted']),
      pickedUp: _toInt(json['in_progress'] ?? json['picked_up']),
      completedToday: _toInt(json['completed_today']),
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class RiderPickupData {
  final int id;
  final String trackingCode;
  final String sellerName;
  final String buyerName;
  final String address;
  final int itemCount;
  final String amount;
  final String status;
  final String statusLabel;
  final String? imageUrl;
  final String batchNumber;
  final String logisticsCenter;
  final String destinationAddress;
  final String shipmentStatus;
  final double? sellerLatitude;
  final double? sellerLongitude;
  final double? logisticsCenterLatitude;
  final double? logisticsCenterLongitude;
  final bool isBatch;
  final int approvedCapacity;
  final int collectedCount;
  final List<RiderPickupBatchItemData> parcels;

  const RiderPickupData({
    required this.id,
    required this.trackingCode,
    required this.sellerName,
    required this.buyerName,
    required this.address,
    required this.itemCount,
    required this.amount,
    required this.status,
    required this.statusLabel,
    this.imageUrl,
    this.batchNumber = '',
    this.logisticsCenter = '',
    this.destinationAddress = '',
    this.shipmentStatus = '',
    this.sellerLatitude,
    this.sellerLongitude,
    this.logisticsCenterLatitude,
    this.logisticsCenterLongitude,
    this.isBatch = false,
    this.approvedCapacity = 0,
    this.collectedCount = 0,
    this.parcels = const <RiderPickupBatchItemData>[],
  });

  factory RiderPickupData.fromApi(Map<String, dynamic> json) {
    final dynamic rawCenter = json['logistics_center'];
    final Map<String, dynamic>? center = rawCenter is Map
        ? Map<String, dynamic>.from(rawCenter)
        : null;
    final Map<String, dynamic>? centerAddress = center?['address'] is Map
        ? Map<String, dynamic>.from(center!['address'] as Map)
        : null;
    final String status = (json['assignment_status'] ?? json['status'] ?? '')
        .toString();
    final List<RiderPickupBatchItemData> parcels = json['items'] is List
        ? (json['items'] as List)
              .whereType<Map>()
              .map(
                (Map item) => RiderPickupBatchItemData.fromApi(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <RiderPickupBatchItemData>[];
    final String trackingCode =
        (json['tracking'] ??
                json['tracking_code'] ??
                json['batch_number'] ??
                'P-${json['id'] ?? ''}')
            .toString();
    final String centerName =
        (json['logistics_center_name'] ??
                center?['business_name'] ??
                center?['name'] ??
                (rawCenter is String ? rawCenter : ''))
            .toString();
    final dynamic rawSellerLatitude =
        json['seller_latitude'] ?? json['delivery_latitude'];
    final dynamic rawSellerLongitude =
        json['seller_longitude'] ?? json['delivery_longitude'];
    return RiderPickupData(
      id: _toInt(json['id']),
      trackingCode: trackingCode,
      sellerName: (json['seller'] ?? json['seller_name'] ?? '').toString(),
      buyerName: (json['buyer_name'] ?? json['buyer'] ?? centerName).toString(),
      address: (json['pickup_address'] ?? json['address'] ?? '').toString(),
      itemCount: _toInt(
        json['parcel_count'] ??
            json['item_count'] ??
            (json['items'] is num ? json['items'] : null),
      ),
      amount: _amountLabel(json['amount']),
      status: status,
      statusLabel: (json['status_label'] ?? _statusLabel(status)).toString(),
      imageUrl: riderProductImageUrl(json),
      batchNumber: (json['batch_number'] ?? trackingCode).toString(),
      logisticsCenter: centerName,
      destinationAddress:
          (json['logistics_center_address'] ??
                  json['destination_address'] ??
                  centerAddress?['formatted_address'] ??
                  _formatCoordinatesAddress(centerAddress))
              .toString(),
      shipmentStatus: (json['shipment_status'] ?? json['current_status'] ?? '')
          .toString(),
      sellerLatitude: _toDouble(rawSellerLatitude),
      sellerLongitude: _toDouble(rawSellerLongitude),
      logisticsCenterLatitude: _toDouble(
        json['logistics_center_latitude'] ?? centerAddress?['latitude'],
      ),
      logisticsCenterLongitude: _toDouble(
        json['logistics_center_longitude'] ?? centerAddress?['longitude'],
      ),
      isBatch: json['batch_number'] != null || json['items'] is List,
      approvedCapacity: _toInt(json['approved_capacity']),
      collectedCount: _toInt(json['collected_count']),
      parcels: parcels,
    );
  }

  String get normalizedStatus {
    return status.trim().toUpperCase();
  }

  bool get isPickupAssigned {
    return <String>{
      'PICKUP_ASSIGNED',
      'ASSIGNED',
      'ACCEPTED',
      'LOADING',
      'READY',
      'IN_PROGRESS',
      'EN_ROUTE_TO_HUB',
    }.contains(normalizedStatus);
  }

  bool get isPickedUp {
    return normalizedStatus == 'PICKED_UP' ||
        normalizedStatus == 'COMPLETED' ||
        normalizedStatus == 'EN_ROUTE_TO_HUB' ||
        shipmentStatus.trim().toUpperCase() == 'PICKED_UP';
  }

  bool get isAccepted =>
      normalizedStatus == 'ACCEPTED' || normalizedStatus == 'IN_PROGRESS';

  bool get isInProgress => normalizedStatus == 'IN_PROGRESS';

  RiderPickupData copyWith({
    int? id,
    String? trackingCode,
    String? sellerName,
    String? buyerName,
    String? address,
    int? itemCount,
    String? amount,
    String? status,
    String? statusLabel,
    String? imageUrl,
    String? shipmentStatus,
  }) {
    return RiderPickupData(
      id: id ?? this.id,
      trackingCode: trackingCode ?? this.trackingCode,
      sellerName: sellerName ?? this.sellerName,
      buyerName: buyerName ?? this.buyerName,
      address: address ?? this.address,
      itemCount: itemCount ?? this.itemCount,
      amount: amount ?? this.amount,
      status: status ?? this.status,
      statusLabel: statusLabel ?? this.statusLabel,
      imageUrl: imageUrl ?? this.imageUrl,
      batchNumber: batchNumber,
      logisticsCenter: logisticsCenter,
      destinationAddress: destinationAddress,
      shipmentStatus: shipmentStatus ?? this.shipmentStatus,
      sellerLatitude: sellerLatitude,
      sellerLongitude: sellerLongitude,
      logisticsCenterLatitude: logisticsCenterLatitude,
      logisticsCenterLongitude: logisticsCenterLongitude,
      isBatch: isBatch,
      approvedCapacity: approvedCapacity,
      collectedCount: collectedCount,
      parcels: parcels,
    );
  }

  static int _toInt(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  static String _formatCoordinatesAddress(Map<String, dynamic>? address) {
    if (address == null) return '';
    return <String>[
          address['house_number'],
          address['street_address'] ?? address['street'],
          address['barangay_name'] ?? address['barangay'],
          address['municipality_name'] ?? address['municipality'],
          address['province_name'] ?? address['province'],
        ]
        .where((dynamic value) => value?.toString().trim().isNotEmpty == true)
        .join(', ');
  }

  static String _statusLabel(String status) {
    return switch (status.trim().toUpperCase()) {
      'LOADING' => 'Waiting for acceptance',
      'READY' => 'Accepted',
      'IN_PROGRESS' => 'Pickup in progress',
      'ACCEPTED' => 'Accepted',
      'ASSIGNED' => 'Assigned',
      'EN_ROUTE_TO_HUB' => 'On the way to hub',
      'COMPLETED' => 'Completed',
      '' => 'Unknown',
      final value => value.replaceAll('_', ' '),
    };
  }

  static String _amountLabel(dynamic value) {
    if (value == null) {
      return '';
    }

    if (value is num) {
      return '₱${value.toDouble().toStringAsFixed(2)}';
    }

    final String raw = value.toString().trim();

    if (raw.isEmpty) {
      return '';
    }

    if (raw.contains('₱') || raw.toUpperCase().contains('PHP')) {
      return raw;
    }

    final double? parsed = double.tryParse(
      raw.replaceAll(',', '').replaceAll(' ', ''),
    );

    if (parsed != null) {
      return '₱${parsed.toStringAsFixed(2)}';
    }

    return raw;
  }
}

class RiderPickupBatchItemData {
  final int assignmentId;
  final String trackingCode;
  final String sellerOrderNumber;
  final List<String> products;
  final String assignmentStatus;
  final String shipmentStatus;
  final String? notCollectedReason;
  final String? imageUrl;

  const RiderPickupBatchItemData({
    required this.assignmentId,
    required this.trackingCode,
    required this.sellerOrderNumber,
    required this.products,
    required this.assignmentStatus,
    required this.shipmentStatus,
    this.notCollectedReason,
    this.imageUrl,
  });

  factory RiderPickupBatchItemData.fromApi(Map<String, dynamic> json) {
    return RiderPickupBatchItemData(
      assignmentId: _toInt(json['assignment_id']),
      trackingCode: (json['tracking'] ?? '').toString(),
      sellerOrderNumber: (json['seller_order_number'] ?? '').toString(),
      products: json['products'] is List
          ? (json['products'] as List)
                .map((dynamic product) => product.toString())
                .toList(growable: false)
          : const <String>[],
      assignmentStatus: (json['assignment_status'] ?? '').toString(),
      shipmentStatus: (json['shipment_status'] ?? '').toString(),
      notCollectedReason: _nullableString(json['not_collected_reason']),
      imageUrl: riderProductImageUrl(json),
    );
  }

  String get normalizedStatus => assignmentStatus.trim().toUpperCase();

  bool get isResolved => const <String>{
    'COMPLETED',
    'REJECTED',
    'CANCELLED',
  }.contains(normalizedStatus);

  bool get wasCollected => normalizedStatus == 'COMPLETED';

  static int _toInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String? _nullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }
}

class RiderPickupTransitionRequest {
  final RiderPickupData pickup;

  final String status;
  final String? scannedCode;
  final String scanMethod;

  const RiderPickupTransitionRequest({
    required this.pickup,
    required this.status,
    this.scannedCode,
    this.scanMethod = 'MANUAL',
  });
}

typedef RiderPickupCallback = void Function(RiderPickupData pickup);

typedef RiderPickupRefreshCallback = Future<void> Function();

typedef RiderPickupTransitionCallback =
    Future<void> Function(RiderPickupTransitionRequest request);

typedef RiderPickupVerifyCallback =
    Future<bool> Function(RiderPickupData pickup, String trackingCode);

class RiderPickupsScreen extends StatefulWidget {
  final List<RiderPickupData> pickups;

  final RiderPickupStatsData stats;

  final String? statusMessage;

  final Future<void> Function(RiderPickupData pickup)? onViewPickup;

  final RiderPickupRefreshCallback? onRefresh;

  final VoidCallback? onViewDeliveries;

  const RiderPickupsScreen({
    super.key,
    this.pickups = const <RiderPickupData>[],
    this.stats = const RiderPickupStatsData(ready: 0, accepted: 0, pickedUp: 0),
    this.statusMessage,
    this.onViewPickup,
    this.onRefresh,
    this.onViewDeliveries,
  });

  @override
  State<RiderPickupsScreen> createState() {
    return _RiderPickupsScreenState();
  }
}

class _RiderPickupsScreenState extends State<RiderPickupsScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _warning = Color(0xFF946514);

  static const Color _warningSoft = Color(0xFFFFF3DC);

  static const Color _danger = Color(0xFF9E3328);

  static const Color _dangerSoft = Color(0xFFFFF1F0);

  Future<void> _refresh() async {
    final RiderPickupRefreshCallback? callback = widget.onRefresh;

    if (callback != null) {
      await callback();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: _text,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text(
          'Pickups',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: _text,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
        ),
        actions: <Widget>[
          if (widget.onViewDeliveries != null)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: FilledButton(
                onPressed: widget.onViewDeliveries,
                style: FilledButton.styleFrom(
                  backgroundColor: _maroon,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  minimumSize: const Size(0, 38),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'Deliveries',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 16),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
            children: <Widget>[
              if (widget.statusMessage?.trim().isNotEmpty == true) ...<Widget>[
                _buildStatusMessage(widget.statusMessage!),

                const SizedBox(height: 18),
              ],

              _buildHeader(),

              const SizedBox(height: 18),

              _buildStats(),

              const SizedBox(height: 20),

              _buildPickupTasks(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'PICKUP MANAGEMENT',
          style: TextStyle(
            color: _maroon,
            fontSize: 11.5,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          'Seller Pickup Batches',
          style: TextStyle(
            color: _text,
            fontSize: 26,
            height: 1.12,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Accept a seller batch, scan each parcel, then take the collected items to the logistics center.',
          style: TextStyle(color: _muted, fontSize: 13.5, height: 1.55),
        ),

        const SizedBox(height: 14),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: _warningSoft,
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            '${widget.stats.ready} Assigned Batch${widget.stats.ready == 1 ? '' : 'es'}',
            style: const TextStyle(
              color: _warning,
              fontSize: 12.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStats() {
    final List<_PickupStatData> stats = <_PickupStatData>[
      _PickupStatData(
        label: 'Assigned',
        value: widget.stats.ready,
        icon: Icons.inventory_2_outlined,
      ),
      _PickupStatData(
        label: 'Accepted',
        value: widget.stats.accepted,
        icon: Icons.assignment_turned_in_outlined,
      ),
      _PickupStatData(
        label: 'In Progress',
        value: widget.stats.pickedUp,
        icon: Icons.local_shipping_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 500;

        if (compact) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (int index = 0; index < stats.length; index++) ...<Widget>[
                Expanded(
                  child: _PickupStatCard(stat: stats[index], compact: true),
                ),
                if (index != stats.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
        }

        return Row(
          children: <Widget>[
            for (int index = 0; index < stats.length; index++) ...<Widget>[
              Expanded(child: _PickupStatCard(stat: stats[index])),

              if (index != stats.length - 1) const SizedBox(width: 10),
            ],
          ],
        );
      },
    );
  }

  Widget _buildPickupTasks() {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Pickup Tasks',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'Each card groups parcels from the same seller into one pickup batch.',
                  style: TextStyle(color: _muted, fontSize: 12.5, height: 1.45),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: _border),

          if (widget.pickups.isEmpty)
            const _PickupEmptyState()
          else
            ...List<Widget>.generate(widget.pickups.length, (int index) {
              final RiderPickupData pickup = widget.pickups[index];

              return Column(
                children: <Widget>[
                  _PickupTaskCard(
                    pickup: pickup,
                    onView: widget.onViewPickup == null
                        ? null
                        : () => unawaited(widget.onViewPickup!(pickup)),
                  ),

                  if (index != widget.pickups.length - 1)
                    const Divider(height: 1, color: _border),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatusMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _dangerSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF1B7B2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.error_outline_rounded, color: _danger, size: 20),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _danger,
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupStatData {
  final String label;
  final int value;
  final IconData icon;

  const _PickupStatData({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _PickupStatCard extends StatelessWidget {
  final _PickupStatData stat;
  final bool compact;

  const _PickupStatCard({required this.stat, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(minHeight: compact ? 76 : 118),
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(compact ? 16 : 18),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: compact
            ? <Widget>[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Icon(stat.icon, color: const Color(0xFF561C17), size: 18),
                    Text(
                      stat.value.toString(),
                      style: const TextStyle(
                        color: Color(0xFF3B211B),
                        fontSize: 22,
                        height: 1,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  stat.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF987865),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ]
            : <Widget>[
                Icon(stat.icon, color: const Color(0xFF561C17), size: 22),
                const SizedBox(height: 16),
                Text(
                  stat.label,
                  style: const TextStyle(
                    color: Color(0xFF987865),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  stat.value.toString(),
                  style: const TextStyle(
                    color: Color(0xFF3B211B),
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
      ),
    );
  }
}

class _PickupTaskCard extends StatelessWidget {
  final RiderPickupData pickup;

  final VoidCallback? onView;

  const _PickupTaskCard({required this.pickup, this.onView});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _PickupImage(imageUrl: pickup.imageUrl),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pickup.batchNumber.isEmpty
                          ? 'Pickup batch ${pickup.trackingCode}'
                          : 'Pickup batch ${pickup.batchNumber}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF3B211B),
                        fontSize: 15,
                        height: 1.25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),

                    const SizedBox(height: 6),

                    Text(
                      'Seller: ${pickup.sellerName}',
                      style: const TextStyle(
                        color: Color(0xFF987865),
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      pickup.address,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF987865),
                        fontSize: 12,
                        height: 1.4,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      '${pickup.itemCount} item(s)',
                      style: const TextStyle(
                        color: Color(0xFF987865),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: <Widget>[
              _PickupStatusBadge(label: pickup.statusLabel),

              const Spacer(),

              OutlinedButton(
                onPressed: onView,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF3B211B),
                  side: const BorderSide(color: Color(0xFFEADCCC)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                ),
                child: const Text(
                  'View',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickupStatusBadge extends StatelessWidget {
  final String label;

  const _PickupStatusBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3DC),
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF946514),
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _PickupImage extends StatelessWidget {
  final String? imageUrl;

  const _PickupImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    return Container(
      width: 64,
      height: 64,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFFF3ECE4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: url == null || url.isEmpty
          ? const Center(
              child: Icon(Icons.inventory_2_outlined, color: Color(0xFFA99386)),
            )
          : SizedNetworkImage(
              url: url,
              fit: BoxFit.cover,
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: Color(0xFFA99386),
                      ),
                    );
                  },
            ),
    );
  }
}

class _PickupEmptyState extends StatelessWidget {
  const _PickupEmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 38),
      child: Center(
        child: Column(
          children: <Widget>[
            Icon(
              Icons.inventory_2_outlined,
              color: Color(0xFFA99386),
              size: 46,
            ),

            SizedBox(height: 13),

            Text(
              'No seller pickup batches are available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF987865), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

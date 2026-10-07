import 'package:flutter/material.dart';

class RiderPickupStatsData {
  final int ready;
  final int accepted;
  final int pickedUp;

  const RiderPickupStatsData({
    required this.ready,
    required this.accepted,
    required this.pickedUp,
  });

  factory RiderPickupStatsData.fromApi(Map<String, dynamic> json) {
    return RiderPickupStatsData(
      ready: _toInt(json['ready']),
      accepted: _toInt(json['accepted']),
      pickedUp: _toInt(json['picked_up']),
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
  });

  factory RiderPickupData.fromApi(Map<String, dynamic> json) {
    return RiderPickupData(
      id: _toInt(json['id']),
      trackingCode: (json['tracking'] ?? json['tracking_code'] ?? '')
          .toString(),
      sellerName: (json['seller'] ?? json['seller_name'] ?? '').toString(),
      buyerName: (json['buyer'] ?? json['buyer_name'] ?? '').toString(),
      address: (json['address'] ?? '').toString(),
      itemCount: _toInt(json['items'] ?? json['item_count']),
      amount: _amountLabel(json['amount']),
      status: (json['status'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? json['status'] ?? '').toString(),
      imageUrl: _nullableString(json['image'] ?? json['image_url']),
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
      'IN_PROGRESS',
    }.contains(normalizedStatus);
  }

  bool get isPickedUp {
    return normalizedStatus == 'PICKED_UP';
  }

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

  static String? _nullableString(dynamic value) {
    final String text = value?.toString().trim() ?? '';

    if (text.isEmpty) {
      return null;
    }

    return text;
  }
}

class RiderPickupTransitionRequest {
  final RiderPickupData pickup;

  final String status;

  const RiderPickupTransitionRequest({
    required this.pickup,
    required this.status,
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

  final RiderPickupCallback? onViewPickup;

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

  static const Color _success = Color(0xFF237A44);

  static const Color _successSoft = Color(0xFFEAF6EE);

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
          'Pickup Assignments',
          style: TextStyle(
            color: _text,
            fontSize: 19,
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
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 100),
            children: <Widget>[
              if (widget.statusMessage?.trim().isNotEmpty == true) ...<Widget>[
                _buildStatusMessage(widget.statusMessage!),

                const SizedBox(height: 18),
              ],

              _buildHeader(),

              const SizedBox(height: 22),

              _buildStats(),

              const SizedBox(height: 24),

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
          'Pickup Assignments',
          style: TextStyle(
            color: _text,
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.4,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 9),

        const Text(
          'Accept seller pickup requests, confirm parcel pickup, then deliver to the sorting center.',
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
            '${widget.stats.ready} Ready Pickup',
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
        label: 'Ready For Pickup',
        value: widget.stats.ready,
        icon: Icons.inventory_2_outlined,
      ),
      _PickupStatData(
        label: 'Accepted',
        value: widget.stats.accepted,
        icon: Icons.assignment_turned_in_outlined,
      ),
      _PickupStatData(
        label: 'Picked Up',
        value: widget.stats.pickedUp,
        icon: Icons.local_shipping_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool compact = constraints.maxWidth < 500;

        if (compact) {
          return Column(
            children: stats
                .map(
                  (_PickupStatData stat) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PickupStatCard(stat: stat),
                  ),
                )
                .toList(growable: false),
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
                  'Only real delivery records from seller pickup requests are listed.',
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
                        : () {
                            widget.onViewPickup!(pickup);
                          },
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
        color: _successSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7DFC5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(
            Icons.check_circle_outline_rounded,
            color: _success,
            size: 20,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _success,
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

  const _PickupStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 118),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(stat.icon, color: const Color(0xFF561C17), size: 22),

          const SizedBox(height: 16),

          Text(
            stat.label,
            style: const TextStyle(color: Color(0xFF987865), fontSize: 12),
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
                      pickup.trackingCode.isEmpty
                          ? 'No tracking code'
                          : pickup.trackingCode,
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
          : Image.network(
              url,
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
              'No pickup requests are available.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF987865), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

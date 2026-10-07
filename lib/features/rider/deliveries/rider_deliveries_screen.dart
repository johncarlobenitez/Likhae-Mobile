import 'package:flutter/material.dart';

import 'rider_delivery_models.dart';

class RiderDeliveriesScreen extends StatefulWidget {
  final List<RiderDeliveryData> deliveries;
  final RiderDeliveryStatsData? stats;
  final String? statusMessage;
  final bool showPreviewWhenEmpty;
  final RiderDeliveryCallback? onViewDelivery;
  final RiderDeliveryRefreshCallback? onRefresh;
  final VoidCallback? onBack;

  const RiderDeliveriesScreen({
    super.key,
    this.deliveries = const <RiderDeliveryData>[],
    this.stats,
    this.statusMessage,
    this.showPreviewWhenEmpty = true,
    this.onViewDelivery,
    this.onRefresh,
    this.onBack,
  });

  @override
  State<RiderDeliveriesScreen> createState() => _RiderDeliveriesScreenState();
}

class _RiderDeliveriesScreenState extends State<RiderDeliveriesScreen> {
  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _soft = Color(0xFFF6EFE7);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _maroon = Color(0xFF561C17);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _success = Color(0xFF1B7A46);

  static const List<RiderDeliveryData> _sampleDeliveries = <RiderDeliveryData>[
    RiderDeliveryData(
      id: 41,
      trackingCode: 'LKH-DLV-2026-0041',
      buyerName: 'Maria Santos',
      contact: '0917 123 4567',
      address: 'Masico, Pila, Laguna',
      amount: 965,
      status: 'assigned',
      statusLabel: 'Assigned',
      imageUrl:
          'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
    RiderDeliveryData(
      id: 40,
      trackingCode: 'LKH-DLV-2026-0040',
      buyerName: 'Juan Dela Cruz',
      contact: '0918 555 0112',
      address: 'Santa Cruz, Laguna',
      amount: 495,
      status: 'picked_up',
      statusLabel: 'Picked Up',
      imageUrl:
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
    RiderDeliveryData(
      id: 39,
      trackingCode: 'LKH-DLV-2026-0039',
      buyerName: 'Angela Reyes',
      contact: '0919 765 4321',
      address: 'Calamba, Laguna',
      amount: 3365,
      status: 'out_for_delivery',
      statusLabel: 'Out For Delivery',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
  ];

  bool get _usingPreview {
    return widget.showPreviewWhenEmpty && widget.deliveries.isEmpty;
  }

  List<RiderDeliveryData> get _displayDeliveries {
    if (widget.deliveries.isNotEmpty) {
      return widget.deliveries;
    }

    if (_usingPreview) {
      return _sampleDeliveries;
    }

    return const <RiderDeliveryData>[];
  }

  RiderDeliveryStatsData get _displayStats {
    if (widget.stats != null && !_usingPreview) {
      return widget.stats!;
    }

    final List<RiderDeliveryData> rows = _displayDeliveries;

    return RiderDeliveryStatsData(
      assigned: rows.where((RiderDeliveryData row) => row.normalizedStatus == 'assigned').length,
      outForDelivery: rows
          .where((RiderDeliveryData row) => row.normalizedStatus == 'out_for_delivery')
          .length,
      deliveredToday: rows
          .where((RiderDeliveryData row) => row.normalizedStatus == 'delivered')
          .length,
      failedToday: rows
          .where(
            (RiderDeliveryData row) =>
                row.normalizedStatus == 'failed' ||
                row.normalizedStatus == 'delivery_failed',
          )
          .length,
    );
  }

  Future<void> _refresh() async {
    final RiderDeliveryRefreshCallback? callback = widget.onRefresh;
    if (callback != null) {
      await callback();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<RiderDeliveryData> deliveries = _displayDeliveries;
    final RiderDeliveryStatsData stats = _displayStats;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: _refresh,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: <Widget>[
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(
                    <Widget>[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          tooltip: 'Back',
                          onPressed:
                              widget.onBack ??
                              () => Navigator.of(context).maybePop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          color: _text,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (widget.statusMessage?.trim().isNotEmpty == true) ...<Widget>[
                        _StatusNotice(message: widget.statusMessage!),
                        const SizedBox(height: 16),
                      ],
                      if (_usingPreview) ...<Widget>[
                        const _PreviewNotice(),
                        const SizedBox(height: 18),
                      ],
                      _buildHeader(deliveries.length),
                      const SizedBox(height: 22),
                      _buildStats(stats),
                      const SizedBox(height: 24),
                      _buildAssignments(deliveries),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(int count) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'DELIVERY MANAGEMENT',
          style: TextStyle(
            color: _maroon,
            fontSize: 12,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Delivery Assignments',
                    style: TextStyle(
                      color: _text,
                      fontSize: 28,
                      height: 1.08,
                      letterSpacing: -0.6,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Parcels assigned by the sorting center to your rider account.',
                    style: TextStyle(
                      color: _muted,
                      fontSize: 14,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF1E4D7),
                borderRadius: BorderRadius.circular(100),
              ),
              child: Text(
                '$count Active',
                style: const TextStyle(
                  color: _maroon,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStats(RiderDeliveryStatsData stats) {
    final List<_DeliveryStat> items = <_DeliveryStat>[
      _DeliveryStat('Assigned', stats.assigned, Icons.assignment_outlined),
      _DeliveryStat('Out For Delivery', stats.outForDelivery, Icons.near_me_outlined),
      _DeliveryStat('Delivered Today', stats.deliveredToday, Icons.task_alt_rounded),
      _DeliveryStat('Failed Today', stats.failedToday, Icons.error_outline_rounded),
    ];

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        const double gap = 12;
        final int columns = constraints.maxWidth >= 760 ? 4 : 2;
        final double width =
            (constraints.maxWidth - (gap * (columns - 1))) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (_DeliveryStat item) => SizedBox(
                  width: width,
                  child: _StatCard(data: item),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildAssignments(List<RiderDeliveryData> deliveries) {
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
            padding: EdgeInsets.fromLTRB(17, 17, 17, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Assigned Deliveries',
                  style: TextStyle(
                    color: _text,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Real assignments will appear here when the Rider API is connected.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 12.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: _border),
          if (deliveries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(28),
              child: Center(
                child: Text(
                  'No active delivery assignments found.',
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
              ),
            )
          else
            ...List<Widget>.generate(
              deliveries.length,
              (int index) {
                final RiderDeliveryData delivery = deliveries[index];
                return Column(
                  children: <Widget>[
                    _DeliveryTile(
                      delivery: delivery,
                      onTap: widget.onViewDelivery == null
                          ? null
                          : () => widget.onViewDelivery!(delivery),
                    ),
                    if (index != deliveries.length - 1)
                      const Divider(height: 1, color: _border),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DeliveryStat {
  final String label;
  final int value;
  final IconData icon;

  const _DeliveryStat(this.label, this.value, this.icon);
}

class _StatCard extends StatelessWidget {
  final _DeliveryStat data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 130),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E4D7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(data.icon, color: const Color(0xFF561C17), size: 19),
          ),
          const SizedBox(height: 17),
          Text(
            data.label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFF987865),
              fontSize: 12.5,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '${data.value}',
            style: const TextStyle(
              color: Color(0xFF3B211B),
              fontSize: 29,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DeliveryTile extends StatelessWidget {
  final RiderDeliveryData delivery;
  final VoidCallback? onTap;

  const _DeliveryTile({required this.delivery, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 72,
                    height: 72,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3ECE4),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFEADCCC)),
                    ),
                    child: _DeliveryImage(imageUrl: delivery.imageUrl),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          delivery.trackingCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF3B211B),
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Buyer: ${delivery.buyerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF6C4936),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          delivery.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF987865),
                            fontSize: 12,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          formatRiderMoney(delivery.amount),
                          style: const TextStyle(
                            color: Color(0xFF561C17),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 13),
              Row(
                children: <Widget>[
                  _DeliveryStatusBadge(delivery: delivery),
                  const Spacer(),
                  SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF561C17),
                        side: const BorderSide(color: Color(0xFFC19771)),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded, size: 17),
                      label: const Text(
                        'View',
                        style: TextStyle(
                          fontSize: 12.5,
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
      ),
    );
  }
}

class _DeliveryStatusColors {
  final Color background;
  final Color foreground;

  const _DeliveryStatusColors({
    required this.background,
    required this.foreground,
  });

  factory _DeliveryStatusColors.fromStatus(String status) {
    switch (status) {
      case 'delivered':
        return const _DeliveryStatusColors(
          background: Color(0xFFEAF6EE),
          foreground: Color(0xFF237A44),
        );
      case 'failed':
      case 'delivery_failed':
        return const _DeliveryStatusColors(
          background: Color(0xFFFCEBE8),
          foreground: Color(0xFFB42318),
        );
      case 'out_for_delivery':
        return const _DeliveryStatusColors(
          background: Color(0xFFEAF1FF),
          foreground: Color(0xFF315B9A),
        );
      case 'picked_up':
      case 'in_transit':
        return const _DeliveryStatusColors(
          background: Color(0xFFFFF3DC),
          foreground: Color(0xFF906010),
        );
      case 'assigned':
      default:
        return const _DeliveryStatusColors(
          background: Color(0xFFF1E4D7),
          foreground: Color(0xFF561C17),
        );
    }
  }
}

class _DeliveryStatusBadge extends StatelessWidget {
  final RiderDeliveryData delivery;

  const _DeliveryStatusBadge({required this.delivery});

  @override
  Widget build(BuildContext context) {
    final _DeliveryStatusColors colors =
        _DeliveryStatusColors.fromStatus(delivery.normalizedStatus);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        delivery.statusLabel,
        style: TextStyle(
          color: colors.foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _DeliveryImage extends StatelessWidget {
  final String? imageUrl;

  const _DeliveryImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFFA99386),
          size: 30,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (
        BuildContext context,
        Object error,
        StackTrace? stackTrace,
      ) {
        return const Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: Color(0xFFA99386),
            size: 28,
          ),
        );
      },
    );
  }
}

class _StatusNotice extends StatelessWidget {
  final String message;

  const _StatusNotice({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF6EE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFB7DFC5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Icon(Icons.check_circle_outline_rounded, color: _RiderDeliveriesScreenState._success, size: 20),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _RiderDeliveriesScreenState._success,
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

class _PreviewNotice extends StatelessWidget {
  const _PreviewNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _RiderDeliveriesScreenState._soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _RiderDeliveriesScreenState._border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.visibility_outlined, color: _RiderDeliveriesScreenState._maroon, size: 20),
          SizedBox(width: 9),
          Expanded(
            child: Text(
              'Sample delivery assignments only. They are not stored in Laravel and will disappear when real Rider API data is supplied.',
              style: TextStyle(
                color: _RiderDeliveriesScreenState._muted,
                fontSize: 12.5,
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

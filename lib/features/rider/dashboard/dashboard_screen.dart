import 'package:flutter/material.dart';

import '../deliveries/rider_delivery_models.dart';
import '../rider_product_image.dart';

class RiderDashboardStatData {
  final String label;
  final int value;

  const RiderDashboardStatData({required this.label, required this.value});

  factory RiderDashboardStatData.fromApi(Map<String, dynamic> json) {
    return RiderDashboardStatData(
      label: (json['label'] ?? '').toString(),
      value: int.tryParse((json['value'] ?? 0).toString()) ?? 0,
    );
  }
}

class RiderDashboardParcelData {
  final int id;

  final String trackingCode;

  final String buyerName;
  final String contact;
  final String address;
  final double amount;

  final String status;
  final String statusLabel;

  final String? imageUrl;
  final double? deliveryLatitude;
  final double? deliveryLongitude;
  final bool isPreview;

  const RiderDashboardParcelData({
    required this.id,
    required this.trackingCode,
    required this.buyerName,
    this.contact = 'Not available',
    required this.address,
    this.amount = 0,
    required this.status,
    required this.statusLabel,
    this.imageUrl,
    this.deliveryLatitude,
    this.deliveryLongitude,
    this.isPreview = false,
  });

  factory RiderDashboardParcelData.fromApi(Map<String, dynamic> json) {
    final RiderDeliveryData delivery = RiderDeliveryData.fromApi(json);
    return RiderDashboardParcelData(
      id: delivery.id,
      trackingCode: delivery.trackingCode,
      buyerName: delivery.buyerName,
      contact: delivery.contact,
      address: delivery.address,
      amount: delivery.amount,
      status: delivery.status,
      statusLabel: delivery.statusLabel,
      imageUrl: delivery.imageUrl,
      deliveryLatitude: delivery.deliveryLatitude,
      deliveryLongitude: delivery.deliveryLongitude,
      isPreview: delivery.isPreview,
    );
  }
}

typedef RiderDashboardParcelCallback =
    void Function(RiderDashboardParcelData parcel);

typedef RiderDashboardRefreshCallback = Future<void> Function();

class RiderDashboardScreen extends StatelessWidget {
  final List<RiderDashboardStatData> stats;
  final List<RiderDashboardParcelData> recentParcels;
  final String riderName;
  final String? statusMessage;
  final RiderDashboardParcelCallback? onViewParcel;
  final VoidCallback? onViewAllShipments;
  final VoidCallback? onOpenPickups;
  final VoidCallback? onOpenEarnings;
  final VoidCallback? onOpenScanner;
  final VoidCallback? onOpenMessages;
  final VoidCallback? onOpenNotifications;
  final RiderDashboardRefreshCallback? onRefresh;

  const RiderDashboardScreen({
    super.key,
    this.stats = const [],
    this.recentParcels = const [],
    this.riderName = '',
    this.statusMessage,
    this.onViewParcel,
    this.onViewAllShipments,
    this.onOpenPickups,
    this.onOpenEarnings,
    this.onOpenScanner,
    this.onOpenMessages,
    this.onOpenNotifications,
    this.onRefresh,
  });

  static const _background = Color(0xFFFBF7F2);
  static const _surface = Color(0xFFFFFDF9);
  static const _border = Color(0xFFEADCCC);
  static const _maroon = Color(0xFF561C17);
  static const _text = Color(0xFF3B211B);
  static const _muted = Color(0xFF987865);

  int _count(String label) {
    for (final stat in stats) {
      if (stat.label.toLowerCase().contains(label)) return stat.value;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: _maroon,
          onRefresh: () async {
            await onRefresh?.call();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 960),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _topBar(),
                      const SizedBox(height: 22),
                      if (statusMessage?.trim().isNotEmpty == true) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF1F0),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            statusMessage!,
                            style: const TextStyle(
                              color: Color(0xFFB42318),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _welcomeCard(),
                      const SizedBox(height: 14),
                      _pickupCard(),
                      const SizedBox(height: 28),
                      const Text(
                        'Delivery overview',
                        style: TextStyle(
                          color: _text,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'A quick look at your assigned deliveries.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _statistics(),
                      const SizedBox(height: 14),
                      _earningsShortcut(),
                      const SizedBox(height: 28),
                      _recentParcels(),
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

  Widget _topBar() {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: _maroon,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.two_wheeler_rounded,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'LIKHAE',
                style: TextStyle(
                  color: _text,
                  fontSize: 17,
                  letterSpacing: 2,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Rider dashboard',
                style: TextStyle(color: _muted, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Messages',
          onPressed: onOpenMessages,
          icon: const Icon(
            Icons.chat_bubble_outline_rounded,
            color: _maroon,
            size: 22,
          ),
        ),
        IconButton(
          tooltip: 'Notifications',
          onPressed: onOpenNotifications,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: _maroon,
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _welcomeCard() {
    final name = riderName.trim();
    final firstName = name.isEmpty ? '' : name.split(RegExp(r'\s+')).first;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [_maroon, Color(0xFF793D2F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            firstName.isEmpty
                ? 'YOUR DAY AT A GLANCE'
                : 'HELLO, ${firstName.toUpperCase()}',
            style: const TextStyle(
              color: Color(0xFFEBD5BF),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Every stop\ncounts.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Your pickups, deliveries, and progress\nin one place.',
            style: TextStyle(
              color: Color(0xFFEBD5BF),
              fontSize: 12.5,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onOpenScanner,
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 19),
            label: const Text('Scan a parcel'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFF7E8D8),
              foregroundColor: _maroon,
              disabledBackgroundColor: const Color(0xFFF7E8D8),
              disabledForegroundColor: _muted,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pickupCard() {
    final count = _count('pickup');
    return Material(
      color: const Color(0xFFF3E8DB),
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenPickups,
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: _surface,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: _maroon,
                  size: 23,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count pickup ${count == 1 ? 'batch' : 'batches'}',
                      style: const TextStyle(
                        color: _text,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'New seller pickups will appear here'
                          : 'View your seller pickup tasks',
                      style: const TextStyle(
                        color: _muted,
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _maroon, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statistics() {
    final cards = <({String label, int count, IconData icon, Color color})>[
      (
        label: 'Assigned',
        count: _count('assigned parcels'),
        icon: Icons.assignment_outlined,
        color: _maroon,
      ),
      (
        label: 'In transit',
        count: _count('in transit'),
        icon: Icons.local_shipping_outlined,
        color: const Color(0xFF946514),
      ),
      (
        label: 'Out for delivery',
        count: _count('out for delivery'),
        icon: Icons.near_me_outlined,
        color: const Color(0xFF38658C),
      ),
      (
        label: 'Completed today',
        count: _count('completed today'),
        icon: Icons.task_alt_rounded,
        color: const Color(0xFF28724D),
      ),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final largeText = MediaQuery.textScalerOf(context).scale(13) > 23;
        final columns = constraints.maxWidth >= 700
            ? 4
            : largeText
            ? 1
            : 2;
        final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final card in cards)
              SizedBox(
                width: width,
                child: Material(
                  color: _surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                    side: const BorderSide(color: _border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: onViewAllShipments,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: card.color.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  card.icon,
                                  color: card.color,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  '${card.count}',
                                  textAlign: TextAlign.right,
                                  style: const TextStyle(
                                    color: _text,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            card.label,
                            style: const TextStyle(
                              color: _muted,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _earningsShortcut() {
    return Material(
      color: _surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: const BorderSide(color: _border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenEarnings,
        child: const Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: _maroon,
                size: 22,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View my earnings',
                  style: TextStyle(
                    color: _text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: _muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentParcels() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent parcels',
                style: TextStyle(
                  color: _text,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAllShipments,
              style: TextButton.styleFrom(foregroundColor: _maroon),
              child: const Text(
                'View all',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _border),
          ),
          child: recentParcels.isEmpty
              ? const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 26, vertical: 34),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: _muted, size: 36),
                      SizedBox(height: 14),
                      Text(
                        'All clear for now',
                        style: TextStyle(
                          color: _text,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Your recent parcels will appear here\nwhen deliveries are assigned to you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12,
                          height: 1.6,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (int i = 0; i < recentParcels.length; i++) ...[
                      if (i > 0) const Divider(height: 1, color: _border),
                      _parcelCard(recentParcels[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _parcelCard(RiderDashboardParcelData parcel) {
    final status = parcel.status.toLowerCase();
    final color = status == 'delivered'
        ? const Color(0xFF28724D)
        : status.contains('fail')
        ? const Color(0xFFB42318)
        : _maroon;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewParcel == null ? null : () => onViewParcel!(parcel),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RiderProductImage(imageUrl: parcel.imageUrl, size: 68),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          parcel.trackingCode,
                          style: const TextStyle(
                            color: _text,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          parcel.buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: _text, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parcel.address.isEmpty
                              ? 'Address unavailable'
                              : parcel.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: _muted,
                            fontSize: 11.5,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        parcel.statusLabel,
                        style: TextStyle(
                          color: color,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: _muted,
                    size: 17,
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

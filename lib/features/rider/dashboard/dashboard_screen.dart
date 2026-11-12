import 'package:likhae/core/theme/app_theme.dart';

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/config/app_config.dart';
import '../../../services/rider_mobile_service.dart';
import '../deliveries/rider_delivery_models.dart';
import '../profile/rider_profile_screen.dart';
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
  final RiderProfileData? availabilityProfile;
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
    this.availabilityProfile,
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
      backgroundColor: AppTheme.resolve(context, _background, fill: true),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: AppTheme.resolve(context, _maroon),
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
                      _topBar(context),
                      const SizedBox(height: 22),
                      if (statusMessage?.trim().isNotEmpty == true) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: AppTheme.resolve(context, const Color(0xFFFFF1F0), fill: true),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Text(
                            statusMessage!,
                            style:  TextStyle(
                              color: AppTheme.resolve(context, Color(0xFFB42318)),
                              fontSize: 12,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      _welcomeCard(context),
                      const SizedBox(height: 14),
                      _pickupCard(context),
                      const SizedBox(height: 28),
                       Text(
                        'Delivery overview',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _text),
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 5),
                       Text(
                        'A quick look at your assigned deliveries.',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
                          fontSize: 12,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 14),
                      _statistics(context),
                      const SizedBox(height: 14),
                      _earningsShortcut(context),
                      const SizedBox(height: 28),
                      _recentParcels(context),
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

  Widget _topBar(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              Theme.of(context).brightness == Brightness.dark
                  ? 'assets/logistics/logistics-dark.png'
                  : 'assets/logistics/logistics-light.png',
              width: 130,
              height: 46,
              fit: BoxFit.contain,
              alignment: Alignment.centerLeft,
              semanticLabel: 'LIKHAE Logistics',
            ),
          ),
        ),
        _RiderAvailabilityStatus(initialProfile: availabilityProfile),
        const SizedBox(width: 5),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          tooltip: 'Messages',
          onPressed: onOpenMessages,
          icon:  Icon(
            Icons.chat_bubble_outline_rounded,
            color: AppTheme.resolve(context, _maroon),
            size: 22,
          ),
        ),
        IconButton(
          constraints: const BoxConstraints.tightFor(width: 38, height: 38),
          padding: EdgeInsets.zero,
          tooltip: 'Notifications',
          onPressed: onOpenNotifications,
          icon:  Icon(
            Icons.notifications_none_rounded,
            color: AppTheme.resolve(context, _maroon),
            size: 24,
          ),
        ),
      ],
    );
  }

  Widget _welcomeCard(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient:  LinearGradient(
          colors: [AppTheme.resolve(context, _maroon, fill: true), AppTheme.resolve(context, Color(0xFF793D2F), fill: true)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.resolve(context, _maroon).withValues(alpha: 0.13),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RIDER WORKSPACE',
            style:  TextStyle(
              color: AppTheme.resolve(context, Color(0xFFEBD5BF)),
              fontSize: 11,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Rider Operations',
            style: TextStyle(
              color: Colors.white,
              fontSize: 34,
              height: 1.08,
              letterSpacing: -0.8,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
           Text(
            'Real pickup and delivery work assigned to your active rider account.',
            style: TextStyle(
              color: AppTheme.resolve(context, Color(0xFFEBD5BF)),
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
              backgroundColor: AppTheme.resolve(context, const Color(0xFFF7E8D8), fill: true),
              foregroundColor: AppTheme.resolve(context, _maroon),
              disabledBackgroundColor: AppTheme.resolve(context, const Color(0xFFF7E8D8), fill: true),
              disabledForegroundColor: AppTheme.resolve(context, _muted),
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

  Widget _pickupCard(BuildContext context) {
    final count = _count('pickup');
    return Material(
      color: AppTheme.resolve(context, const Color(0xFFF3E8DB), fill: true),
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
                  color: AppTheme.resolve(context, _surface, fill: true),
                  borderRadius: BorderRadius.circular(13),
                ),
                child:  Icon(
                  Icons.storefront_outlined,
                  color: AppTheme.resolve(context, _maroon),
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
                      style:  TextStyle(
                        color: AppTheme.resolve(context, _text),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      count == 0
                          ? 'New seller pickups will appear here'
                          : 'View your seller pickup tasks',
                      style:  TextStyle(
                        color: AppTheme.resolve(context, _muted),
                        fontSize: 11.5,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
               Icon(Icons.arrow_forward_rounded, color: AppTheme.resolve(context, _maroon), size: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statistics(BuildContext context) {
    final cards = <({String label, int count, IconData icon, Color color})>[
      (
        label: 'Assigned',
        count: _count('assigned parcels'),
        icon: Icons.assignment_outlined,
        color: AppTheme.resolve(context, _maroon),
      ),
      (
        label: 'In transit',
        count: _count('in transit'),
        icon: Icons.local_shipping_outlined,
        color: AppTheme.resolve(context, const Color(0xFF946514)),
      ),
      (
        label: 'Out for delivery',
        count: _count('out for delivery'),
        icon: Icons.near_me_outlined,
        color: AppTheme.resolve(context, const Color(0xFF38658C)),
      ),
      (
        label: 'Completed today',
        count: _count('completed today'),
        icon: Icons.task_alt_rounded,
        color: AppTheme.resolve(context, const Color(0xFF28724D)),
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
                  color: AppTheme.resolve(context, _surface, fill: true),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(19),
                    side:  BorderSide(color: AppTheme.resolve(context, _border)),
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
                                  style:  TextStyle(
                                    color: AppTheme.resolve(context, _text),
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
                            style:  TextStyle(
                              color: AppTheme.resolve(context, _muted),
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

  Widget _earningsShortcut(BuildContext context) {
    return Material(
      color: AppTheme.resolve(context, _surface, fill: true),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side:  BorderSide(color: AppTheme.resolve(context, _border)),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenEarnings,
        child:  Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: AppTheme.resolve(context, _maroon),
                size: 22,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'View my earnings',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_rounded, color: AppTheme.resolve(context, _muted), size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _recentParcels(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
             Expanded(
              child: Text(
                'Recent parcels',
                style: TextStyle(
                  color: AppTheme.resolve(context, _text),
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            TextButton(
              onPressed: onViewAllShipments,
              style: TextButton.styleFrom(foregroundColor: AppTheme.resolve(context, _maroon)),
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
            color: AppTheme.resolve(context, _surface, fill: true),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.resolve(context, _border)),
          ),
          child: recentParcels.isEmpty
              ?  Padding(
                  padding: EdgeInsets.symmetric(horizontal: 26, vertical: 34),
                  child: Column(
                    children: [
                      Icon(Icons.inventory_2_outlined, color: AppTheme.resolve(context, _muted), size: 36),
                      SizedBox(height: 14),
                      Text(
                        'All clear for now',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _text),
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 7),
                      Text(
                        'Your recent parcels will appear here\nwhen deliveries are assigned to you.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
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
                      if (i > 0)  Divider(height: 1, color: AppTheme.resolve(context, _border)),
                      _parcelCard(context, recentParcels[i]),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _parcelCard(BuildContext context, RiderDashboardParcelData parcel) {
    final status = parcel.status.toLowerCase();
    final color = status == 'delivered'
        ? AppTheme.resolve(context, const Color(0xFF28724D))
        : status.contains('fail')
        ? AppTheme.resolve(context, const Color(0xFFB42318))
        : AppTheme.resolve(context, _maroon);
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
                          style:  TextStyle(
                            color: AppTheme.resolve(context, _text),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          parcel.buyerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(color: AppTheme.resolve(context, _text), fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          parcel.address.isEmpty
                              ? 'Address unavailable'
                              : parcel.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:  TextStyle(
                            color: AppTheme.resolve(context, _muted),
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
                   Icon(
                    Icons.arrow_forward_rounded,
                    color: AppTheme.resolve(context, _muted),
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

class _RiderAvailabilityStatus extends StatefulWidget {
  final RiderProfileData? initialProfile;

  const _RiderAvailabilityStatus({this.initialProfile});

  @override
  State<_RiderAvailabilityStatus> createState() =>
      _RiderAvailabilityStatusState();
}

class _RiderAvailabilityStatusState
    extends State<_RiderAvailabilityStatus> {
  late RiderProfileData? _profile;
  late bool _loading;

  @override
  void initState() {
    super.initState();
    _profile = widget.initialProfile;
    _loading = AppConfig.apiEnabled && _profile == null;
    if (_loading) {
      unawaited(_loadProfile());
    }
  }

  @override
  void didUpdateWidget(covariant _RiderAvailabilityStatus oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialProfile != widget.initialProfile &&
        widget.initialProfile != null) {
      _profile = widget.initialProfile;
      _loading = false;
    }
  }

  Future<void> _loadProfile() async {
    if (_loading && _profile != null) return;
    setState(() {
      _loading = true;
    });
    try {
      final RiderProfileData profile =
          await RiderMobileService.fetchProfile();
      if (!mounted) return;
      setState(() {
        _profile = profile;
      });
    } catch (_) {
      // Show an unknown status when the profile cannot be loaded.
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!AppConfig.apiEnabled) {
      return const SizedBox.shrink();
    }
    if (_loading) {
      return const SizedBox(
        width: 24,
        height: 30,
        child: Center(
          child: SizedBox.square(
            dimension: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    final bool? isOnline = _profile?.isOnline;
    final Color statusColor = isOnline == null
        ? AppTheme.resolve(context, const Color(0xFF987865))
        : isOnline
        ? const Color(0xFF27856E)
        : AppTheme.resolve(context, const Color(0xFF765A50));
    final String statusLabel = isOnline == null
        ? 'Unknown'
        : isOnline
        ? 'Online'
        : 'Offline';

    return Semantics(
      label: 'Rider status: $statusLabel',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.circle, size: 7, color: statusColor),
            const SizedBox(width: 6),
            Text(
              statusLabel,
              style: TextStyle(
                color: statusColor,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

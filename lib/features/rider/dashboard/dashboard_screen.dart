import 'package:flutter/material.dart';

import '../deliveries/rider_delivery_models.dart';

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

class RiderDashboardScreen extends StatefulWidget {
  final List<RiderDashboardStatData> stats;

  final List<RiderDashboardParcelData> recentParcels;

  final String? statusMessage;

  /// Shows sample Rider dashboard data only
  /// while no real Laravel/API data exists.
  final bool showPreviewWhenEmpty;

  final RiderDashboardParcelCallback? onViewParcel;

  final VoidCallback? onViewAllShipments;
  final VoidCallback? onOpenScanner;
  final VoidCallback? onOpenMessages;

  final VoidCallback? onOpenNotifications;

  final RiderDashboardRefreshCallback? onRefresh;

  const RiderDashboardScreen({
    super.key,
    this.stats = const <RiderDashboardStatData>[],
    this.recentParcels = const <RiderDashboardParcelData>[],
    this.statusMessage,
    this.showPreviewWhenEmpty = true,
    this.onViewParcel,
    this.onViewAllShipments,
    this.onOpenScanner,
    this.onOpenMessages,
    this.onOpenNotifications,
    this.onRefresh,
  });

  @override
  State<RiderDashboardScreen> createState() => _RiderDashboardScreenState();
}

class _RiderDashboardScreenState extends State<RiderDashboardScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _soft = Color(0xFFF6EFE7);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _tan = Color(0xFFC19771);

  static const Color _success = Color(0xFF1B7A46);

  static const Color _successSoft = Color(0xFFEAF6EE);

  static const List<RiderDashboardStatData> _sampleStats =
      <RiderDashboardStatData>[
        RiderDashboardStatData(label: 'Assigned Parcels', value: 4),
        RiderDashboardStatData(label: 'In Transit', value: 2),
        RiderDashboardStatData(label: 'Out for Delivery', value: 1),
        RiderDashboardStatData(label: 'Completed Today', value: 3),
      ];

  static const List<RiderDashboardParcelData>
  _sampleParcels = <RiderDashboardParcelData>[
    RiderDashboardParcelData(
      id: 105,
      trackingCode: 'LKH-PCL-2026-0105',
      buyerName: 'Sample Buyer',
      contact: '0917 123 4567',
      address: 'Masico, Pila, Laguna',
      amount: 965,
      status: 'assigned',
      statusLabel: 'Assigned',
      imageUrl:
          'https://images.unsplash.com/photo-1599643478518-a784e5dc4c8f?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
    RiderDashboardParcelData(
      id: 104,
      trackingCode: 'LKH-PCL-2026-0104',
      buyerName: 'Maria Santos',
      contact: '0918 555 0112',
      address: 'Santa Cruz, Laguna',
      amount: 495,
      status: 'picked_up',
      statusLabel: 'Picked Up',
      imageUrl:
          'https://images.unsplash.com/photo-1512820790803-83ca734da794?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
    RiderDashboardParcelData(
      id: 103,
      trackingCode: 'LKH-PCL-2026-0103',
      buyerName: 'Juan Dela Cruz',
      contact: '0919 765 4321',
      address: 'Calamba, Laguna',
      amount: 365,
      status: 'out_for_delivery',
      statusLabel: 'Out for Delivery',
      imageUrl:
          'https://images.unsplash.com/photo-1586023492125-27b2c045efd7?w=600&q=85&auto=format&fit=crop',
      isPreview: true,
    ),
  ];

  bool get _usingPreview {
    return widget.showPreviewWhenEmpty &&
        widget.stats.isEmpty &&
        widget.recentParcels.isEmpty;
  }

  List<RiderDashboardStatData> get _displayStats {
    if (widget.stats.isNotEmpty) {
      return widget.stats;
    }

    if (_usingPreview) {
      return _sampleStats;
    }

    return const <RiderDashboardStatData>[];
  }

  List<RiderDashboardParcelData> get _displayParcels {
    if (widget.recentParcels.isNotEmpty) {
      return widget.recentParcels;
    }

    if (_usingPreview) {
      return _sampleParcels;
    }

    return const <RiderDashboardParcelData>[];
  }

  Future<void> _refresh() async {
    final RiderDashboardRefreshCallback? callback = widget.onRefresh;

    if (callback == null) {
      return;
    }

    await callback();
  }

  @override
  Widget build(BuildContext context) {
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
              SliverToBoxAdapter(child: _buildTopBar()),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate(<Widget>[
                    if (widget.statusMessage?.trim().isNotEmpty ==
                        true) ...<Widget>[
                      _buildStatusMessage(widget.statusMessage!),

                      const SizedBox(height: 16),
                    ],

                    if (_usingPreview) ...<Widget>[
                      _buildPreviewNotice(),

                      const SizedBox(height: 18),
                    ],

                    _buildIntro(),

                    const SizedBox(height: 24),

                    _buildStatistics(),

                    const SizedBox(height: 26),

                    _buildRecentParcels(),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 10),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(bottom: BorderSide(color: Color(0xFFF0E8DF))),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _maroon,
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.two_wheeler_rounded,
              color: Colors.white,
              size: 23,
            ),
          ),

          const SizedBox(width: 11),

          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'LIKHAE Rider',
                  style: TextStyle(
                    color: _text,
                    fontSize: 18,
                    height: 1.1,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 3),

                Text(
                  'Pickup & delivery operations',
                  style: TextStyle(color: _muted, fontSize: 12),
                ),
              ],
            ),
          ),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                tooltip: 'Scan parcels',
                onPressed: widget.onOpenScanner,
                icon: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: _maroon,
                  size: 24,
                ),
              ),
              IconButton(
                tooltip: 'Notifications',
                onPressed: widget.onOpenNotifications,
                icon: const Icon(
                  Icons.notifications_none_rounded,
                  color: _maroon,
                  size: 24,
                ),
              ),
              IconButton(
                tooltip: 'Messages',
                onPressed: widget.onOpenMessages,
                icon: const Icon(
                  Icons.forum_outlined,
                  color: _maroon,
                  size: 24,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntro() {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'RIDER OPERATIONS',
          style: TextStyle(
            color: _maroon,
            fontSize: 12,
            letterSpacing: 1.7,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(height: 7),

        Text(
          'Dashboard',
          style: TextStyle(
            color: _text,
            fontSize: 30,
            height: 1.05,
            letterSpacing: -0.7,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Real pickup and delivery work assigned to your active rider account.',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  Widget _buildStatistics() {
    final List<RiderDashboardStatData> stats = _displayStats;

    if (stats.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: _surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _border),
        ),
        child: const Text(
          'No rider statistics available yet.',
          style: TextStyle(color: _muted, fontSize: 13),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final bool wide = constraints.maxWidth >= 700;

        final int columns = wide ? 4 : 2;

        const double gap = 12;

        final double itemWidth =
            (constraints.maxWidth - ((columns - 1) * gap)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: stats
              .map((RiderDashboardStatData stat) {
                return SizedBox(
                  width: itemWidth,
                  child: _RiderStatCard(data: stat),
                );
              })
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildRecentParcels() {
    final List<RiderDashboardParcelData> parcels = _displayParcels;

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
          Padding(
            padding: const EdgeInsets.fromLTRB(17, 17, 12, 15),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: <Widget>[
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Recent Parcels',
                        style: TextStyle(
                          color: _text,
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),

                      SizedBox(height: 5),

                      Text(
                        'Latest parcels assigned to your rider account.',
                        style: TextStyle(
                          color: _muted,
                          fontSize: 12.5,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),

                if (widget.onViewAllShipments != null)
                  TextButton(
                    onPressed: widget.onViewAllShipments,
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: _maroon,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: _border),

          if (parcels.isEmpty)
            _buildEmptyParcels()
          else
            ...List<Widget>.generate(parcels.length, (int index) {
              final RiderDashboardParcelData parcel = parcels[index];

              return Column(
                children: <Widget>[
                  _RiderParcelCard(
                    parcel: parcel,
                    onTap: widget.onViewParcel == null
                        ? null
                        : () {
                            widget.onViewParcel!(parcel);
                          },
                  ),

                  if (index != parcels.length - 1)
                    const Divider(height: 1, color: _border),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildPreviewNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.visibility_outlined, color: _maroon, size: 20),

          SizedBox(width: 9),

          Expanded(
            child: Text(
              'Sample dashboard preview only. These parcels are not stored in Laravel. Real rider assignments will replace them when API data is provided.',
              style: TextStyle(
                color: _muted,
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

  Widget _buildEmptyParcels() {
    return const Padding(
      padding: EdgeInsets.all(30),
      child: Column(
        children: <Widget>[
          Icon(Icons.inventory_2_outlined, color: _tan, size: 44),

          SizedBox(height: 13),

          Text(
            'No rider parcels found yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),

          SizedBox(height: 6),

          Text(
            'Parcels assigned to your rider account will appear here.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}

class _RiderStatCard extends StatelessWidget {
  final RiderDashboardStatData data;

  const _RiderStatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final IconData icon = _iconForLabel(data.label);

    return Container(
      constraints: const BoxConstraints(minHeight: 135),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF9),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: const Color(0xFFEADCCC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 39,
            height: 39,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFF1E4D7),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, color: const Color(0xFF561C17), size: 20),
          ),

          const SizedBox(height: 18),

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

          const SizedBox(height: 7),

          Text(
            '${data.value}',
            style: const TextStyle(
              color: Color(0xFF3B211B),
              fontSize: 30,
              height: 1,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconForLabel(String label) {
    final String normalized = label.toLowerCase();

    if (normalized.contains('assigned')) {
      return Icons.assignment_outlined;
    }

    if (normalized.contains('out for delivery')) {
      return Icons.near_me_outlined;
    }

    if (normalized.contains('transit')) {
      return Icons.local_shipping_outlined;
    }

    if (normalized.contains('completed')) {
      return Icons.task_alt_rounded;
    }

    return Icons.inventory_2_outlined;
  }
}

class _RiderParcelCard extends StatelessWidget {
  final RiderDashboardParcelData parcel;

  final VoidCallback? onTap;

  const _RiderParcelCard({required this.parcel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3ECE4),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(color: const Color(0xFFEADCCC)),
                    ),
                    child: _RiderParcelImage(imageUrl: parcel.imageUrl),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          parcel.trackingCode,
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
                          'Buyer: ${parcel.buyerName}',
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
                          parcel.address.trim().isEmpty
                              ? 'Address not available'
                              : parcel.address,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF987865),
                            fontSize: 12,
                            height: 1.45,
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
                  _RiderStatusBadge(
                    status: parcel.status,
                    label: parcel.statusLabel,
                  ),

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

class _RiderStatusBadge extends StatelessWidget {
  final String status;
  final String label;

  const _RiderStatusBadge({required this.status, required this.label});

  @override
  Widget build(BuildContext context) {
    final String normalized = status.trim().toLowerCase().replaceAll('-', '_');

    final Color background;
    final Color foreground;

    switch (normalized) {
      case 'delivered':
        background = const Color(0xFFEAF6EE);

        foreground = const Color(0xFF237A44);

        break;

      case 'failed':
        background = const Color(0xFFFCEBE8);

        foreground = const Color(0xFFB42318);

        break;

      case 'out_for_delivery':
        background = const Color(0xFFEAF1FF);

        foreground = const Color(0xFF315B9A);

        break;

      case 'picked_up':
      case 'in_transit':
        background = const Color(0xFFFFF3DC);

        foreground = const Color(0xFF906010);

        break;

      case 'assigned':
      default:
        background = const Color(0xFFF1E4D7);

        foreground = const Color(0xFF561C17);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11.5,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _RiderParcelImage extends StatelessWidget {
  final String? imageUrl;

  const _RiderParcelImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    if (url == null || url.isEmpty) {
      return const Center(
        child: Icon(
          Icons.inventory_2_outlined,
          color: Color(0xFFA99386),
          size: 29,
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      loadingBuilder:
          (BuildContext context, Widget child, ImageChunkEvent? progress) {
            if (progress == null) {
              return child;
            }

            return const Center(
              child: SizedBox(
                width: 19,
                height: 19,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF561C17),
                ),
              ),
            );
          },
      errorBuilder:
          (BuildContext context, Object error, StackTrace? stackTrace) {
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

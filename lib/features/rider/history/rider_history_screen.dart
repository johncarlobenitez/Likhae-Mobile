import 'package:likhae/core/theme/app_theme.dart';

import 'package:flutter/material.dart';

import '../../../shared/widgets/sized_network_image.dart';
import '../rider_product_image.dart';

class RiderHistoryData {
  final int? id;
  final String assignmentType;
  final String trackingCode;
  final String buyerName;
  final String statusLabel;
  final String updatedLabel;
  final String? failureReason;
  final String? imageUrl;

  const RiderHistoryData({
    this.id,
    this.assignmentType = '',
    required this.trackingCode,
    required this.buyerName,
    required this.statusLabel,
    required this.updatedLabel,
    this.failureReason,
    this.imageUrl,
  });

  factory RiderHistoryData.fromApi(Map<String, dynamic> json) {
    final dynamic updatedValue = json['updated'] ?? json['updated_at'];
    return RiderHistoryData(
      id: _parseInt(json['id']),
      assignmentType: _assignmentType(json),
      trackingCode: (json['tracking'] ?? json['tracking_code'] ?? '')
          .toString(),
      buyerName: (json['buyer'] ?? json['buyer_name'] ?? '').toString(),
      statusLabel: _formatStatusLabel(
        json['status_label'] ?? json['status'],
      ),
      updatedLabel: _formatUpdatedLabel(updatedValue),
      failureReason: _nullableString(json['failure_reason']),
      imageUrl: riderProductImageUrl(json),
    );
  }

  static String _formatUpdatedLabel(dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Date unavailable';

    final DateTime? parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;

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
    final String date = '${months[local.month - 1]} ${local.day}, ${local.year}';
    return '$date, $hour:$minute $period';
  }

  static String _formatStatusLabel(dynamic value) {
    final String raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return 'Unknown';

    final String normalized = raw.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    final String compact = normalized.toUpperCase().replaceAll(' ', '');
    const Map<String, String> knownLabels = <String, String>{
      'ATSORTINGCENTER': 'At Sorting Center',
      'READYFORPICKUP': 'Ready for Pickup',
      'PICKEDUP': 'Picked Up',
      'OUTFORDELIVERY': 'Out for Delivery',
      'DELIVERYFAILED': 'Delivery Failed',
      'DELIVERED': 'Delivered',
      'RETURNED': 'Returned',
      'FAILED': 'Failed',
      'COMPLETED': 'Completed',
      'REJECTED': 'Rejected',
      'CANCELLED': 'Cancelled',
    };
    final String? knownLabel = knownLabels[compact];
    if (knownLabel != null) return knownLabel;

    return normalized
        .split(RegExp(r'\s+'))
        .where((String word) => word.isNotEmpty)
        .map(
          (String word) =>
              '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}',
        )
        .join(' ');
  }

  static String _assignmentType(Map<String, dynamic> json) {
    final dynamic rawType =
        json['assignment_type'] ??
        json['assignmentType'] ??
        json['job_type'] ??
        json['jobType'] ??
        json['type'];
    final String type = rawType?.toString().trim().toUpperCase() ?? '';
    if (type.contains('PICKUP')) return 'PICKUP';
    if (type.contains('DELIVERY')) return 'DELIVERY';

    final String status = (json['status_label'] ?? json['status'] ?? '')
        .toString()
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
    if (status.contains('PICKUP') ||
        status == 'PICKED_UP' ||
        status.contains('SORTING_CENTER')) {
      return 'PICKUP';
    }
    if (status.contains('DELIVERY') || status == 'DELIVERED') {
      return 'DELIVERY';
    }
    return '';
  }

  bool get isPickup => assignmentType == 'PICKUP';

  bool get isDelivery => assignmentType == 'DELIVERY';

  bool get hasFailureReason {
    return failureReason?.trim().isNotEmpty == true;
  }

  static int? _parseInt(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is int) {
      return value;
    }

    return int.tryParse(value.toString());
  }

  static String? _nullableString(dynamic value) {
    if (value == null) {
      return null;
    }

    final String result = value.toString().trim();

    if (result.isEmpty) {
      return null;
    }

    return result;
  }
}

typedef RiderHistoryRefreshCallback = Future<void> Function();

typedef RiderHistoryItemCallback = void Function(RiderHistoryData history);

enum _RiderHistoryFilter { all, pickup, delivery }

class RiderHistoryScreen extends StatefulWidget {
  final List<RiderHistoryData> history;

  final String? statusMessage;

  final RiderHistoryRefreshCallback? onRefresh;

  final RiderHistoryItemCallback? onOpenHistory;

  const RiderHistoryScreen({
    super.key,
    this.history = const <RiderHistoryData>[],
    this.statusMessage,
    this.onRefresh,
    this.onOpenHistory,
  });

  @override
  State<RiderHistoryScreen> createState() => _RiderHistoryScreenState();
}

class _RiderHistoryScreenState extends State<RiderHistoryScreen> {
  _RiderHistoryFilter _selectedFilter = _RiderHistoryFilter.all;

  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonSoft = Color(0xFFF1E4D7);

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _success = Color(0xFF237A44);

  static const Color _successSoft = Color(0xFFEAF6EE);

  Future<void> _refresh() async {
    final RiderHistoryRefreshCallback? callback = widget.onRefresh;

    if (callback == null) {
      return;
    }

    await callback();
  }

  List<RiderHistoryData> get _visibleHistory {
    return switch (_selectedFilter) {
      _RiderHistoryFilter.all => widget.history,
      _RiderHistoryFilter.pickup =>
        widget.history.where((RiderHistoryData row) => row.isPickup).toList(),
      _RiderHistoryFilter.delivery => widget.history
          .where((RiderHistoryData row) => row.isDelivery)
          .toList(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.resolve(context, _background, fill: true),
      body: SafeArea(
        top: true,
        child: RefreshIndicator(
          color: AppTheme.resolve(context, _maroon),
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

              const SizedBox(height: 24),

              _buildHistorySection(),
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
        Text(
          'RIDER HISTORY',
          style: TextStyle(
            color: AppTheme.resolve(context, _maroon),
            fontSize: 11.5,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(height: 8),

        Text(
          'Pickup and Delivery History',
          style: TextStyle(
            color: AppTheme.resolve(context, _text),
            fontSize: 27,
            height: 1.12,
            letterSpacing: -0.45,
            fontWeight: FontWeight.w900,
          ),
        ),

        SizedBox(height: 9),

        Text(
          'Completed, failed, returned, and sorting-center handoff records for your pickup and delivery assignments.',
          style: TextStyle(
            color: AppTheme.resolve(context, _muted),
            fontSize: 13.5,
            height: 1.55,
          ),
        ),
      ],
    );
  }

  Widget _buildHistorySection() {
    final List<RiderHistoryData> visibleHistory = _visibleHistory;
    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _surface, fill: true),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.resolve(context, _border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'History',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _text),
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),

                SizedBox(height: 5),

                Text(
                  'This list uses your real rider assignments only.',
                  style: TextStyle(
                    color: AppTheme.resolve(context, _muted),
                    fontSize: 12.5,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 13),
                DropdownButtonFormField<_RiderHistoryFilter>(
                  initialValue: _selectedFilter,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Filter history',
                    prefixIcon: Icon(
                      Icons.filter_list_rounded,
                      color: AppTheme.resolve(context, _maroon),
                    ),
                    filled: true,
                    fillColor: AppTheme.resolve(context, _background, fill: true),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.resolve(context, _border),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.resolve(context, _border),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppTheme.resolve(context, _maroon),
                      ),
                    ),
                  ),
                  dropdownColor: AppTheme.resolve(context, _surface, fill: true),
                  items: const <DropdownMenuItem<_RiderHistoryFilter>>[
                    DropdownMenuItem(
                      value: _RiderHistoryFilter.all,
                      child: Text('All'),
                    ),
                    DropdownMenuItem(
                      value: _RiderHistoryFilter.pickup,
                      child: Text('Pickup'),
                    ),
                    DropdownMenuItem(
                      value: _RiderHistoryFilter.delivery,
                      child: Text('Delivery'),
                    ),
                  ],
                  onChanged: (_RiderHistoryFilter? filter) {
                    if (filter != null) {
                      setState(() => _selectedFilter = filter);
                    }
                  },
                ),
              ],
            ),
          ),

          Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.resolve(context, _border),
          ),

          if (visibleHistory.isEmpty)
            _buildEmptyState()
          else
            ...List<Widget>.generate(visibleHistory.length, (int index) {
              final RiderHistoryData parcel = visibleHistory[index];

              return Column(
                children: <Widget>[
                  _HistoryItem(
                    parcel: parcel,
                    onTap: widget.onOpenHistory == null
                        ? null
                        : () {
                            widget.onOpenHistory!(parcel);
                          },
                  ),

                  if (index != visibleHistory.length - 1)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppTheme.resolve(context, _border),
                    ),
                ],
              );
            }),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      child: Center(
        child: Column(
          children: <Widget>[
            Container(
              width: 58,
              height: 58,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.resolve(context, _maroonSoft, fill: true),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.history_rounded,
                color: AppTheme.resolve(context, _maroon),
                size: 28,
              ),
            ),

            SizedBox(height: 14),

            Text(
              _emptyStateTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.resolve(context, _text),
                fontSize: 16,
                fontWeight: FontWeight.w900,
              ),
            ),

            SizedBox(height: 6),

            Text(
              _emptyStateMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.resolve(context, _muted),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _emptyStateTitle => switch (_selectedFilter) {
    _RiderHistoryFilter.all => 'No rider history found yet.',
    _RiderHistoryFilter.pickup => 'No pickup history found yet.',
    _RiderHistoryFilter.delivery => 'No delivery history found yet.',
  };

  String get _emptyStateMessage => switch (_selectedFilter) {
    _RiderHistoryFilter.all =>
      'Your completed and previous pickup or delivery assignments will appear here.',
    _RiderHistoryFilter.pickup =>
      'Your completed and previous pickup assignments will appear here.',
    _RiderHistoryFilter.delivery =>
      'Your completed and previous delivery assignments will appear here.',
  };

  Widget _buildStatusMessage(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, _successSoft, fill: true),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppTheme.resolve(context, const Color(0xFFB7DFC5)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.check_circle_outline_rounded,
            color: AppTheme.resolve(context, _success),
            size: 20,
          ),

          const SizedBox(width: 9),

          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: AppTheme.resolve(context, _success),
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

class _HistoryItem extends StatelessWidget {
  final RiderHistoryData parcel;

  final VoidCallback? onTap;

  const _HistoryItem({required this.parcel, this.onTap});

  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonSoft = Color(0xFFF1E4D7);

  static const Color _danger = Color(0xFFB42318);

  static const Color _dangerSoft = Color(0xFFFFF1F0);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _HistoryImage(imageUrl: parcel.imageUrl),

                  const SizedBox(width: 12),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          parcel.trackingCode.trim().isEmpty
                              ? 'No tracking code'
                              : parcel.trackingCode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.resolve(context, _text),
                            fontSize: 15,
                            height: 1.25,
                            fontWeight: FontWeight.w900,
                          ),
                        ),

                        const SizedBox(height: 5),

                        Text(
                          'Buyer: ${parcel.buyerName}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: AppTheme.resolve(context, _muted),
                            fontSize: 12.5,
                            height: 1.4,
                          ),
                        ),

                        const SizedBox(height: 4),

                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.schedule_rounded,
                              size: 13,
                              color: AppTheme.resolve(context, _muted),
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                parcel.updatedLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AppTheme.resolve(context, _muted),
                                  fontSize: 11.5,
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (parcel.hasFailureReason) ...<Widget>[
                const SizedBox(height: 12),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: AppTheme.resolve(context, _dangerSoft, fill: true),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: AppTheme.resolve(context, const Color(0xFFF5C5C1)),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        color: AppTheme.resolve(context, _danger),
                        size: 18,
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        child: Text(
                          'Reason: ${parcel.failureReason}',
                          style: TextStyle(
                            color: AppTheme.resolve(context, _danger),
                            fontSize: 12,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 13),

              Row(
                children: <Widget>[
                  if (parcel.assignmentType.isNotEmpty) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.resolve(
                          context,
                          const Color(0xFFF5EEE7),
                          fill: true,
                        ),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Text(
                        parcel.isPickup ? 'Pickup' : 'Delivery',
                        style: TextStyle(
                          color: AppTheme.resolve(context, _muted),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.resolve(context, _maroonSoft, fill: true),
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      parcel.statusLabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppTheme.resolve(context, _maroon),
                        fontSize: 11.5,
                        letterSpacing: 0,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),

                  const Spacer(),

                  if (onTap != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppTheme.resolve(context, Color(0xFFA99386)),
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

class _HistoryImage extends StatelessWidget {
  final String? imageUrl;

  const _HistoryImage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final String? url = imageUrl?.trim();

    return Container(
      width: 58,
      height: 58,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppTheme.resolve(context, const Color(0xFFF3ECE4), fill: true),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.resolve(context, const Color(0xFFEADCCC)),
        ),
      ),
      child: url == null || url.isEmpty
          ? Center(
              child: Icon(
                Icons.inventory_2_outlined,
                color: AppTheme.resolve(context, Color(0xFFA99386)),
                size: 25,
              ),
            )
          : SizedNetworkImage(
              url: url,
              fit: BoxFit.cover,
              placeholder: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.resolve(context, Color(0xFF561C17)),
                  ),
                ),
              ),
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.resolve(context, Color(0xFFA99386)),
                        size: 25,
                      ),
                    );
                  },
            ),
    );
  }
}

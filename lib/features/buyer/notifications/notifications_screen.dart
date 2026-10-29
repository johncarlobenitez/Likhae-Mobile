import 'dart:async';

import 'package:flutter/material.dart';

import '../../../shared/widgets/shop_ui.dart';

enum BuyerNotificationType {
  orders,
  deliveries,
  messages,
  rewards,
  account,
  stores,
  announcements,
  general,
}

extension BuyerNotificationTypeInfo on BuyerNotificationType {
  String get key {
    switch (this) {
      case BuyerNotificationType.orders:
        return 'orders';

      case BuyerNotificationType.deliveries:
        return 'deliveries';

      case BuyerNotificationType.messages:
        return 'messages';

      case BuyerNotificationType.rewards:
        return 'rewards';

      case BuyerNotificationType.account:
        return 'account';

      case BuyerNotificationType.stores:
        return 'stores';

      case BuyerNotificationType.announcements:
        return 'announcements';

      case BuyerNotificationType.general:
        return 'general';
    }
  }

  String get label {
    switch (this) {
      case BuyerNotificationType.orders:
        return 'Orders';

      case BuyerNotificationType.deliveries:
        return 'Delivery';

      case BuyerNotificationType.messages:
        return 'Messages';

      case BuyerNotificationType.rewards:
        return 'Rewards';

      case BuyerNotificationType.account:
        return 'Account';

      case BuyerNotificationType.stores:
        return 'Stores';

      case BuyerNotificationType.announcements:
        return 'Announcements';

      case BuyerNotificationType.general:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case BuyerNotificationType.orders:
        return Icons.description_outlined;

      case BuyerNotificationType.deliveries:
        return Icons.inventory_2_outlined;

      case BuyerNotificationType.messages:
        return Icons.mail_outline_rounded;

      case BuyerNotificationType.rewards:
        return Icons.confirmation_number_outlined;

      case BuyerNotificationType.account:
        return Icons.person_outline_rounded;

      case BuyerNotificationType.stores:
        return Icons.storefront_outlined;

      case BuyerNotificationType.announcements:
        return Icons.campaign_outlined;

      case BuyerNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }

  Color get iconBackgroundColor {
    switch (this) {
      case BuyerNotificationType.orders:
        return const Color(0xFFF6F0DE);
      case BuyerNotificationType.deliveries:
        return const Color(0xFFE7F2EC);
      case BuyerNotificationType.messages:
        return const Color(0xFFEAF0F5);
      case BuyerNotificationType.rewards:
        return const Color(0xFFF6EDE2);
      case BuyerNotificationType.account:
        return const Color(0xFFF3E9E6);
      case BuyerNotificationType.stores:
        return const Color(0xFFEAF2EA);
      case BuyerNotificationType.announcements:
        return const Color(0xFFF5ECDE);
      case BuyerNotificationType.general:
        return const Color(0xFFF1ECE7);
    }
  }

  Color get iconColor {
    switch (this) {
      case BuyerNotificationType.orders:
        return const Color(0xFF795A2D);
      case BuyerNotificationType.deliveries:
        return const Color(0xFF2D705C);
      case BuyerNotificationType.messages:
        return const Color(0xFF536D83);
      case BuyerNotificationType.rewards:
        return const Color(0xFF91622B);
      case BuyerNotificationType.account:
        return const Color(0xFF83504B);
      case BuyerNotificationType.stores:
        return const Color(0xFF3F7251);
      case BuyerNotificationType.announcements:
        return const Color(0xFF8A642B);
      case BuyerNotificationType.general:
        return ShopColors.secondaryText;
    }
  }
}

enum NotificationFilter {
  all,
  orders,
  deliveries,
  messages,
  rewards,
  account,
  stores,
  announcements,
  general,
}

extension NotificationFilterInfo on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';

      case NotificationFilter.orders:
        return 'Orders';

      case NotificationFilter.deliveries:
        return 'Delivery';

      case NotificationFilter.messages:
        return 'Messages';

      case NotificationFilter.rewards:
        return 'Rewards';

      case NotificationFilter.account:
        return 'Account';

      case NotificationFilter.stores:
        return 'Stores';

      case NotificationFilter.announcements:
        return 'Announcements';

      case NotificationFilter.general:
        return 'General';
    }
  }

  BuyerNotificationType? get notificationType {
    switch (this) {
      case NotificationFilter.all:
        return null;

      case NotificationFilter.orders:
        return BuyerNotificationType.orders;

      case NotificationFilter.deliveries:
        return BuyerNotificationType.deliveries;

      case NotificationFilter.messages:
        return BuyerNotificationType.messages;

      case NotificationFilter.rewards:
        return BuyerNotificationType.rewards;

      case NotificationFilter.account:
        return BuyerNotificationType.account;

      case NotificationFilter.stores:
        return BuyerNotificationType.stores;

      case NotificationFilter.announcements:
        return BuyerNotificationType.announcements;

      case NotificationFilter.general:
        return BuyerNotificationType.general;
    }
  }
}

class BuyerNotificationData {
  final String id;

  final BuyerNotificationType type;

  /// Original Laravel notification type for sound-pattern matching.
  final String? soundType;

  final String title;
  final String message;

  /// Display-ready time from Laravel.
  ///
  /// Examples:
  /// "Just now"
  /// "5 minutes ago"
  /// "Sep 22, 2026"
  final String time;

  final bool unread;

  /// Optional actual creation time.
  ///
  /// The Flutter screen intentionally preserves the ordering
  /// supplied by Laravel instead of silently re-sorting it.
  final DateTime? createdAt;

  /// Optional Laravel destination.
  ///
  /// Examples:
  /// /buyer/orders
  /// /buyer/orders/123
  /// /buyer/messages?seller=shop-slug
  /// /buyer/rewards
  ///
  /// The navigation layer should translate this into an
  /// equivalent Flutter route later.
  final String? actionUrl;

  /// Order associated with this notification, when the API
  /// includes one. Used to open the exact order from parcel updates.
  final String? relatedOrderId;

  const BuyerNotificationData({
    required this.id,
    required this.type,
    this.soundType,
    required this.title,
    required this.message,
    required this.time,
    required this.unread,
    this.createdAt,
    this.actionUrl,
    this.relatedOrderId,
  });

  BuyerNotificationData copyWith({bool? unread}) {
    return BuyerNotificationData(
      id: id,
      type: type,
      soundType: soundType,
      title: title,
      message: message,
      time: time,
      unread: unread ?? this.unread,
      createdAt: createdAt,
      actionUrl: actionUrl,
      relatedOrderId: relatedOrderId,
    );
  }

  static String? resolveOrderReference(Map<String, dynamic> source) {
    final dynamic rawPayload = source['data'];
    final Map<String, dynamic>? payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : null;
    final dynamic rawOrder = source['order'] ?? payload?['order'];
    final Map<String, dynamic>? order = rawOrder is Map
        ? Map<String, dynamic>.from(rawOrder)
        : null;
    final dynamic rawSellerOrder =
        source['seller_order'] ??
        source['sellerOrder'] ??
        payload?['seller_order'] ??
        payload?['sellerOrder'];
    final Map<String, dynamic>? sellerOrder = rawSellerOrder is Map
        ? Map<String, dynamic>.from(rawSellerOrder)
        : null;
    final dynamic rawShipment =
        source['shipment'] ??
        source['parcel'] ??
        payload?['shipment'] ??
        payload?['parcel'];
    final dynamic shipmentValue = rawShipment is List && rawShipment.isNotEmpty
        ? rawShipment.first
        : rawShipment;
    final Map<String, dynamic>? shipment = shipmentValue is Map
        ? Map<String, dynamic>.from(shipmentValue)
        : null;

    String? firstReference(Iterable<dynamic> candidates) {
      for (final dynamic candidate in candidates) {
        final String value = candidate?.toString().trim() ?? '';
        if (value.isNotEmpty) return value;
      }
      return null;
    }

    final String notificationText = <dynamic>[
      source['title'],
      source['message'],
      payload?['title'],
      payload?['subject'],
      payload?['message'],
      payload?['body'],
    ].whereType<String>().join(' ');
    final RegExpMatch? textualReference = RegExp(
      r'\b(?:LK|TRK|SO)-[A-Z0-9]+(?:-[A-Z0-9]+)*\b',
      caseSensitive: false,
    ).firstMatch(notificationText);
    if (textualReference != null) return textualReference.group(0);

    final String? structuredReference = firstReference(<dynamic>[
      source['order_id'],
      source['orderId'],
      source['order_number'],
      source['related_order_id'],
      source['relatedOrderId'],
      source['seller_order_number'],
      source['sellerOrderNumber'],
      source['seller_order_id'],
      source['sellerOrderId'],
      source['seller_order'] is Map ? null : source['seller_order'],
      payload?['order_id'],
      payload?['orderId'],
      payload?['order_number'],
      payload?['related_order_id'],
      payload?['relatedOrderId'],
      payload?['seller_order_number'],
      payload?['sellerOrderNumber'],
      payload?['seller_order_id'],
      payload?['sellerOrderId'],
      payload?['seller_order'] is Map ? null : payload?['seller_order'],
      order?['id'],
      order?['order_id'],
      order?['order_number'],
      sellerOrder?['seller_order_number'],
      sellerOrder?['order_number'],
      sellerOrder?['id'],
      source['shipment_order_id'],
      payload?['shipment_order_id'],
      source['tracking_number'],
      payload?['tracking_number'],
      source['shipment_id'],
      payload?['shipment_id'],
      shipment?['tracking_number'],
      shipment?['tracking_code'],
      shipment?['tracking'],
      shipment?['shipment_id'],
      shipment?['id'],
    ]);
    return structuredReference;
  }

  static BuyerNotificationType resolveType(String? value) {
    final String normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      case 'order':
      case 'orders':
      case 'assignment':
      case 'assignments':
      case 'rider_assignment_updates':
        return BuyerNotificationType.orders;

      case 'shipment':
      case 'shipments':
      case 'shipping':
      case 'delivery':
      case 'deliveries':
      case 'parcel':
      case 'parcels':
      case 'route':
      case 'routes':
      case 'rider_route_updates':
        return BuyerNotificationType.deliveries;

      case 'message':
      case 'messages':
      case 'chat':
      case 'conversation':
        return BuyerNotificationType.messages;

      case 'reward':
      case 'rewards':
      case 'voucher':
      case 'vouchers':
      case 'points':
      case 'cashback':
      case 'earning':
      case 'earnings':
      case 'rider_earnings_updates':
        return BuyerNotificationType.rewards;

      case 'account':
      case 'profile':
      case 'security':
      case 'password':
      case 'safety':
      case 'exception':
      case 'exceptions':
      case 'rider_safety_updates':
        return BuyerNotificationType.account;

      case 'stores':
      case 'store':
      case 'store_follow':
      case 'store_update':
        return BuyerNotificationType.stores;

      case 'announcement':
      case 'announcements':
        return BuyerNotificationType.announcements;

      case 'general':
      case 'system':
        return BuyerNotificationType.general;
    }

    if (normalized.contains('shipment') ||
        normalized.contains('deliver') ||
        normalized.contains('parcel') ||
        normalized.contains('shipping') ||
        normalized.contains('shipped') ||
        normalized.contains('pickup') ||
        normalized.contains('pick_up') ||
        normalized.contains('sort')) {
      return BuyerNotificationType.deliveries;
    }

    if (normalized.contains('order')) {
      return BuyerNotificationType.orders;
    }

    if (normalized.contains('message') || normalized.contains('chat')) {
      return BuyerNotificationType.messages;
    }

    if (normalized.contains('reward') ||
        normalized.contains('voucher') ||
        normalized.contains('point') ||
        normalized.contains('cashback') ||
        normalized.contains('promotion') ||
        normalized.contains('promo') ||
        normalized.contains('discount') ||
        normalized.contains('coupon')) {
      return BuyerNotificationType.rewards;
    }

    if (normalized.contains('account') ||
        normalized.contains('profile') ||
        normalized.contains('password') ||
        normalized.contains('security')) {
      return BuyerNotificationType.account;
    }

    /*
     * Important:
     *
     * Unknown notification types must NOT silently become
     * Order notifications.
     */
    return BuyerNotificationType.general;
  }
}

typedef NotificationTapCallback =
    Future<void> Function(BuyerNotificationData notification);

typedef MarkAllNotificationsReadCallback = Future<void> Function();
typedef MarkNotificationReadCallback = Future<void> Function(String id);
typedef DismissAnnouncementCallback = Future<void> Function(String id);

typedef RefreshNotificationsCallback =
    Future<List<BuyerNotificationData>> Function();

typedef NotificationStreamBuilder = Stream<BuyerNotificationData> Function();

class NotificationsScreen extends StatefulWidget {
  final List<BuyerNotificationData> notifications;

  final NotificationFilter initialFilter;

  final VoidCallback? onBack;

  /// Handles notification navigation.
  ///
  /// Example:
  /// Order notification   -> Orders
  /// Message notification -> Messages
  /// Reward notification  -> Rewards
  ///
  /// The screen marks unread notifications as read before
  /// invoking this callback when [onMarkAsRead] is provided.
  final NotificationTapCallback? onNotificationTap;

  /// Corresponds to the Laravel buyer notification
  /// mark-all-read operation.
  final MarkAllNotificationsReadCallback? onMarkAllAsRead;

  final MarkNotificationReadCallback? onMarkAsRead;

  final DismissAnnouncementCallback? onDismissAnnouncement;

  /// Reload the authoritative notification list from Laravel.
  final RefreshNotificationsCallback? onRefresh;

  final NotificationStreamBuilder? realtimeStreamBuilder;

  /// Lets Home/navigation update its notification badge after
  /// this screen receives new server state or marks all read.
  final ValueChanged<int>? onUnreadCountChanged;

  const NotificationsScreen({
    super.key,
    this.notifications = const <BuyerNotificationData>[],
    this.initialFilter = NotificationFilter.all,
    this.onBack,
    this.onNotificationTap,
    this.onMarkAllAsRead,
    this.onMarkAsRead,
    this.onDismissAnnouncement,
    this.onRefresh,
    this.realtimeStreamBuilder,
    this.onUnreadCountChanged,
  });

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _background = ShopColors.canvas;

  static const Color _surface = ShopColors.surface;

  static const Color _border = ShopColors.border;

  static const Color _maroon = ShopColors.accent;

  static const Color _maroonDark = ShopColors.accentDark;

  static const Color _text = ShopColors.text;

  static const Color _brown = ShopColors.secondaryText;

  static const Color _muted = ShopColors.muted;

  static const Color _muted2 = ShopColors.faint;

  static const Color _danger = Color(0xFFB42318);

  late List<BuyerNotificationData> _notifications;

  late NotificationFilter _activeFilter;

  bool _markingAllRead = false;

  bool _refreshing = false;

  final Set<String> _openingNotificationIds = <String>{};
  StreamSubscription<BuyerNotificationData>? _notificationStream;

  @override
  void initState() {
    super.initState();

    _notifications = List<BuyerNotificationData>.from(widget.notifications);

    _activeFilter = widget.initialFilter;

    if (widget.realtimeStreamBuilder != null) {
      unawaited(_connectRealtime());
    }
  }

  @override
  void dispose() {
    unawaited(_notificationStream?.cancel());
    super.dispose();
  }

  Future<void> _connectRealtime() async {
    try {
      final NotificationStreamBuilder? builder = widget.realtimeStreamBuilder;
      if (builder == null) return;

      _notificationStream = builder().listen((
        BuyerNotificationData notification,
      ) {
        if (!mounted ||
            _notifications.any(
              (BuyerNotificationData item) => item.id == notification.id,
            )) {
          return;
        }
        setState(() => _notifications.insert(0, notification));
        widget.onUnreadCountChanged?.call(_unreadCount);
      }, onError: (_) {});
    } catch (_) {
      // The initial API list and manual refresh remain available offline.
    }
  }

  @override
  void didUpdateWidget(covariant NotificationsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.notifications != widget.notifications) {
      _notifications = List<BuyerNotificationData>.from(widget.notifications);

      final Set<String> currentIds = _notifications
          .map((BuyerNotificationData notification) => notification.id)
          .toSet();

      _openingNotificationIds.removeWhere(
        (String id) => !currentIds.contains(id),
      );
    }

    if (oldWidget.initialFilter != widget.initialFilter) {
      _activeFilter = widget.initialFilter;
    }
  }

  int get _unreadCount {
    return _notifications.where((BuyerNotificationData notification) {
      return notification.unread;
    }).length;
  }

  List<BuyerNotificationData> get _visibleNotifications {
    final BuyerNotificationType? type = _activeFilter.notificationType;

    if (type == null) {
      return _notifications;
    }

    return _notifications.where((BuyerNotificationData notification) {
      return notification.type == type;
    }).toList();
  }

  int _filterCount(NotificationFilter filter) {
    if (filter == NotificationFilter.all) {
      return _notifications.length;
    }

    final BuyerNotificationType? type = filter.notificationType;

    if (type == null) {
      return _notifications.length;
    }

    return _notifications.where((BuyerNotificationData notification) {
      return notification.type == type;
    }).length;
  }

  int _filterUnreadCount(NotificationFilter filter) {
    final BuyerNotificationType? type = filter.notificationType;

    return _notifications.where((BuyerNotificationData notification) {
      if (!notification.unread) {
        return false;
      }

      if (type == null) {
        return true;
      }

      return notification.type == type;
    }).length;
  }

  void _changeFilter(NotificationFilter filter) {
    if (_activeFilter == filter) {
      return;
    }

    setState(() {
      _activeFilter = filter;
    });
  }

  void _notifyUnreadCountChanged() {
    widget.onUnreadCountChanged?.call(_unreadCount);
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty || _unreadCount == 0 || _markingAllRead) {
      return;
    }

    final MarkAllNotificationsReadCallback? callback = widget.onMarkAllAsRead;

    if (callback == null) {
      return;
    }

    setState(() {
      _markingAllRead = true;
    });

    try {
      /*
       * Important:
       *
       * Do not mark anything locally until Laravel accepts
       * the operation.
       */
      await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = _notifications.map((
          BuyerNotificationData notification,
        ) {
          return notification.copyWith(unread: false);
        }).toList();
      });

      _notifyUnreadCountChanged();

      _showMessage('All notifications marked as read.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _markingAllRead = false;
        });
      }
    }
  }

  Future<void> _openNotification(BuyerNotificationData notification) async {
    if (_openingNotificationIds.contains(notification.id)) {
      return;
    }

    final NotificationTapCallback? callback = widget.onNotificationTap;

    if (callback == null) {
      return;
    }

    setState(() {
      _openingNotificationIds.add(notification.id);
    });

    try {
      final MarkNotificationReadCallback? markAsRead = widget.onMarkAsRead;
      if (notification.unread && markAsRead != null) {
        await markAsRead(notification.id);
        if (!mounted) return;
        setState(() {
          final int index = _notifications.indexWhere(
            (BuyerNotificationData item) => item.id == notification.id,
          );
          if (index >= 0) {
            _notifications[index] = _notifications[index].copyWith(
              unread: false,
            );
          }
        });
        _notifyUnreadCountChanged();
      }
      await callback(notification);
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _openingNotificationIds.remove(notification.id);
        });
      }
    }
  }

  Future<void> _dismissAnnouncement(BuyerNotificationData notification) async {
    final DismissAnnouncementCallback? callback = widget.onDismissAnnouncement;
    if (callback == null ||
        notification.type != BuyerNotificationType.announcements) {
      return;
    }
    try {
      await callback(notification.id);
      if (!mounted) return;
      setState(() {
        _notifications.removeWhere(
          (BuyerNotificationData item) => item.id == notification.id,
        );
      });
      _notifyUnreadCountChanged();
      _showMessage('Announcement dismissed.');
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    }
  }

  Future<void> _refresh() async {
    final RefreshNotificationsCallback? callback = widget.onRefresh;

    if (callback == null || _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      final List<BuyerNotificationData> refreshed = await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications = List<BuyerNotificationData>.from(refreshed);

        final Set<String> currentIds = _notifications
            .map((BuyerNotificationData notification) => notification.id)
            .toSet();

        _openingNotificationIds.removeWhere(
          (String id) => !currentIds.contains(id),
        );
      });

      _notifyUnreadCountChanged();
    } catch (error) {
      _showMessage(_errorText(error), error: true);
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
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
    final List<BuyerNotificationData> visibleNotifications =
        _visibleNotifications;

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildTopBar(),

            Expanded(
              child: RefreshIndicator(
                color: _maroon,
                onRefresh: _refresh,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(14, 15, 14, 100),
                  children: [
                    _buildHeading(),

                    const SizedBox(height: 17),

                    _buildFilters(),

                    const SizedBox(height: 16),

                    if (visibleNotifications.isEmpty)
                      _buildEmptyState()
                    else
                      _buildNotificationList(visibleNotifications),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() => ColoredBox(
    color: _surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GlassIconButton(
            icon: Icons.arrow_back_rounded,
            label: 'Back',
            onPressed: widget.onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Updates',
                  style: TextStyle(
                    color: _text,
                    fontSize: 22,
                    height: 1.15,
                    letterSpacing: -.4,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Everything you need to know.',
                  style: TextStyle(color: _muted, fontSize: 12, height: 1.35),
                ),
              ],
            ),
          ),
          if (_refreshing) ...[
            const SizedBox(width: 10),
            const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _buildHeading() {
    final canMarkAll =
        widget.onMarkAllAsRead != null && _unreadCount > 0 && !_markingAllRead;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: ShopColors.accentSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(
                  _unreadCount == 0
                      ? Icons.done_all_rounded
                      : Icons.notifications_active_outlined,
                  color: _maroon,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _unreadCount == 0
                      ? 'You’re all caught up'
                      : '$_unreadCount unread updates',
                  style: const TextStyle(
                    color: _text,
                    fontSize: 17,
                    letterSpacing: -.35,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Your orders, conversations, and rewards, all in one place.',
            style: TextStyle(color: _muted, fontSize: 12.5, height: 1.5),
          ),
          if (_unreadCount > 0) ...[
            const SizedBox(height: 7),
            TextButton.icon(
              onPressed: canMarkAll ? _markAllAsRead : null,
              icon: _markingAllRead
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.done_all_rounded, size: 18),
              label: const Text('Mark all as read'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(44, 40),
                alignment: Alignment.centerLeft,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 50,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: NotificationFilter.values.length,
        separatorBuilder: (BuildContext context, int index) {
          return const SizedBox(width: 6);
        },
        itemBuilder: (BuildContext context, int index) {
          final NotificationFilter filter = NotificationFilter.values[index];

          final bool selected = filter == _activeFilter;

          final int totalCount = _filterCount(filter);

          final int unreadCount = _filterUnreadCount(filter);

          return Material(
            color: selected ? _maroon : _surface,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              onTap: () {
                _changeFilter(filter);
              },
              borderRadius: BorderRadius.circular(11),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 13),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: selected ? _maroon : _border),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        color: selected ? Colors.white : _brown,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),

                    const SizedBox(width: 5),

                    Text(
                      '$totalCount',
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(alpha: 0.72)
                            : _muted2,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    if (unreadCount > 0) ...[
                      const SizedBox(width: 5),

                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : _maroon,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNotificationList(List<BuyerNotificationData> notifications) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: List<Widget>.generate(notifications.length, (int index) {
          final BuyerNotificationData notification = notifications[index];

          final bool last = index == notifications.length - 1;

          final bool actionable = widget.onNotificationTap != null;

          return _NotificationTile(
            notification: notification,
            opening: _openingNotificationIds.contains(notification.id),
            enabled: actionable,
            showDivider: !last,
            onTap: () {
              _openNotification(notification);
            },
            onDismiss:
                notification.type == BuyerNotificationType.announcements &&
                    widget.onDismissAnnouncement != null
                ? () => _dismissAnnouncement(notification)
                : null,
          );
        }),
      ),
    );
  }

  Widget _buildEmptyState() {
    final String categoryName = _activeFilter.label.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 55, 24, 55),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: ShopColors.accentSoft,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _maroon,
              size: 30,
            ),
          ),

          const SizedBox(height: 17),

          const Text(
            'No notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 7),

          Text(
            _activeFilter == NotificationFilter.all
                ? 'There are no account updates yet.'
                : 'There are no $categoryName updates in this section.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: _muted, fontSize: 13.5, height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final BuyerNotificationData notification;

  final bool opening;
  final bool enabled;
  final bool showDivider;

  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _NotificationTile({
    required this.notification,
    required this.opening,
    required this.enabled,
    required this.showDivider,
    required this.onTap,
    this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final bool unread = notification.unread;

    final bool canOpen = enabled && !opening;

    return Material(
      color: unread ? const Color(0xFFFFF4F0) : ShopColors.surface,
      child: InkWell(
        onTap: canOpen ? onTap : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(13, 14, 13, 14),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(bottom: BorderSide(color: ShopColors.border))
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: notification.type.iconBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  notification.type.icon,
                  color: notification.type.iconColor,
                  size: 19,
                ),
              ),

              const SizedBox(width: 11),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: ShopColors.text,
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: unread
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                            ),
                          ),
                        ),

                        if (notification.time.trim().isNotEmpty) ...[
                          const SizedBox(width: 8),

                          Text(
                            notification.time,
                            style: const TextStyle(
                              color: ShopColors.faint,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (notification.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 5),

                      Text(
                        notification.message,
                        style: const TextStyle(
                          color: ShopColors.muted,
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: ShopColors.soft,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Text(
                            notification.type.label,
                            style: const TextStyle(
                              color: ShopColors.secondaryText,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),

                        if (unread) ...[
                          const SizedBox(width: 6),

                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFCE9E5),
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: const Text(
                              'UNREAD',
                              style: TextStyle(
                                color: ShopColors.accent,
                                fontSize: 11,
                                letterSpacing: 0.4,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        if (opening)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: ShopColors.accent,
                            ),
                          )
                        else if (enabled)
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: ShopColors.faint,
                            size: 18,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (unread) ...[
                const SizedBox(width: 7),

                Container(
                  margin: const EdgeInsets.only(top: 7),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: ShopColors.accent,
                    shape: BoxShape.circle,
                  ),
                ),
              ],

              if (onDismiss != null) ...[
                const SizedBox(width: 4),
                IconButton(
                  onPressed: onDismiss,
                  tooltip: 'Dismiss announcement',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

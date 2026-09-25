import 'package:flutter/material.dart';

enum BuyerNotificationType {
  orders,
  messages,
  rewards,
  account,
  general,
}

extension BuyerNotificationTypeInfo on BuyerNotificationType {
  String get key {
    switch (this) {
      case BuyerNotificationType.orders:
        return 'orders';

      case BuyerNotificationType.messages:
        return 'messages';

      case BuyerNotificationType.rewards:
        return 'rewards';

      case BuyerNotificationType.account:
        return 'account';

      case BuyerNotificationType.general:
        return 'general';
    }
  }

  String get label {
    switch (this) {
      case BuyerNotificationType.orders:
        return 'Orders';

      case BuyerNotificationType.messages:
        return 'Messages';

      case BuyerNotificationType.rewards:
        return 'Rewards';

      case BuyerNotificationType.account:
        return 'Account';

      case BuyerNotificationType.general:
        return 'General';
    }
  }

  IconData get icon {
    switch (this) {
      case BuyerNotificationType.orders:
        return Icons.inventory_2_outlined;

      case BuyerNotificationType.messages:
        return Icons.mail_outline_rounded;

      case BuyerNotificationType.rewards:
        return Icons.confirmation_number_outlined;

      case BuyerNotificationType.account:
        return Icons.person_outline_rounded;

      case BuyerNotificationType.general:
        return Icons.notifications_none_rounded;
    }
  }
}

enum NotificationFilter {
  all,
  orders,
  messages,
  rewards,
  account,
  general,
}

extension NotificationFilterInfo on NotificationFilter {
  String get label {
    switch (this) {
      case NotificationFilter.all:
        return 'All';

      case NotificationFilter.orders:
        return 'Orders';

      case NotificationFilter.messages:
        return 'Messages';

      case NotificationFilter.rewards:
        return 'Rewards';

      case NotificationFilter.account:
        return 'Account';

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

      case NotificationFilter.messages:
        return BuyerNotificationType.messages;

      case NotificationFilter.rewards:
        return BuyerNotificationType.rewards;

      case NotificationFilter.account:
        return BuyerNotificationType.account;

      case NotificationFilter.general:
        return BuyerNotificationType.general;
    }
  }
}

class BuyerNotificationData {
  final String id;

  final BuyerNotificationType type;

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

  const BuyerNotificationData({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.unread,
    this.createdAt,
    this.actionUrl,
  });

  BuyerNotificationData copyWith({
    bool? unread,
  }) {
    return BuyerNotificationData(
      id: id,
      type: type,
      title: title,
      message: message,
      time: time,
      unread: unread ?? this.unread,
      createdAt: createdAt,
      actionUrl: actionUrl,
    );
  }

  static BuyerNotificationType resolveType(
    String? value,
  ) {
    final String normalized = (value ?? '')
        .trim()
        .toLowerCase()
        .replaceAll('-', '_')
        .replaceAll(' ', '_');

    switch (normalized) {
      case 'order':
      case 'orders':
      case 'shipment':
      case 'shipping':
      case 'delivery':
      case 'deliveries':
      case 'parcel':
      case 'parcels':
        return BuyerNotificationType.orders;

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
        return BuyerNotificationType.rewards;

      case 'account':
      case 'profile':
      case 'security':
      case 'password':
        return BuyerNotificationType.account;

      case 'general':
      case 'system':
      case 'announcement':
        return BuyerNotificationType.general;
    }

    if (normalized.contains('order') ||
        normalized.contains('shipment') ||
        normalized.contains('delivery') ||
        normalized.contains('parcel')) {
      return BuyerNotificationType.orders;
    }

    if (normalized.contains('message') ||
        normalized.contains('chat')) {
      return BuyerNotificationType.messages;
    }

    if (normalized.contains('reward') ||
        normalized.contains('voucher') ||
        normalized.contains('point') ||
        normalized.contains('cashback')) {
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

typedef NotificationTapCallback = Future<void> Function(
  BuyerNotificationData notification,
);

typedef MarkAllNotificationsReadCallback = Future<void> Function();

typedef RefreshNotificationsCallback =
    Future<List<BuyerNotificationData>> Function();

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
  /// This callback does NOT automatically mark the
  /// notification as read because the current Buyer flow
  /// only guarantees a "mark all read" operation.
  final NotificationTapCallback? onNotificationTap;

  /// Corresponds to the Laravel buyer notification
  /// mark-all-read operation.
  final MarkAllNotificationsReadCallback? onMarkAllAsRead;

  /// Reload the authoritative notification list from Laravel.
  final RefreshNotificationsCallback? onRefresh;

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
    this.onRefresh,
    this.onUnreadCountChanged,
  });

  @override
  State<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const Color _background = Color(0xFFFBF7F2);

  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _border = Color(0xFFEADCCC);

  static const Color _maroon = Color(0xFF561C17);

  static const Color _maroonDark = Color(0xFF3E130F);

  static const Color _text = Color(0xFF3B211B);

  static const Color _brown = Color(0xFF6C4936);

  static const Color _muted = Color(0xFF987865);

  static const Color _muted2 = Color(0xFFA99386);

  static const Color _tan = Color(0xFFC19771);

  static const Color _danger = Color(0xFFB42318);

  late List<BuyerNotificationData> _notifications;

  late NotificationFilter _activeFilter;

  bool _markingAllRead = false;

  bool _refreshing = false;

  final Set<String> _openingNotificationIds = <String>{};

  @override
  void initState() {
    super.initState();

    _notifications = List<BuyerNotificationData>.from(
      widget.notifications,
    );

    _activeFilter = widget.initialFilter;
  }

  @override
  void didUpdateWidget(
    covariant NotificationsScreen oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.notifications != widget.notifications) {
      _notifications = List<BuyerNotificationData>.from(
        widget.notifications,
      );

      final Set<String> currentIds = _notifications
          .map(
            (
              BuyerNotificationData notification,
            ) =>
                notification.id,
          )
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
    return _notifications.where(
      (
        BuyerNotificationData notification,
      ) {
        return notification.unread;
      },
    ).length;
  }

  List<BuyerNotificationData> get _visibleNotifications {
    final BuyerNotificationType? type =
        _activeFilter.notificationType;

    if (type == null) {
      return _notifications;
    }

    return _notifications.where(
      (
        BuyerNotificationData notification,
      ) {
        return notification.type == type;
      },
    ).toList();
  }

  int _filterCount(
    NotificationFilter filter,
  ) {
    if (filter == NotificationFilter.all) {
      return _notifications.length;
    }

    final BuyerNotificationType? type =
        filter.notificationType;

    if (type == null) {
      return _notifications.length;
    }

    return _notifications.where(
      (
        BuyerNotificationData notification,
      ) {
        return notification.type == type;
      },
    ).length;
  }

  int _filterUnreadCount(
    NotificationFilter filter,
  ) {
    final BuyerNotificationType? type =
        filter.notificationType;

    return _notifications.where(
      (
        BuyerNotificationData notification,
      ) {
        if (!notification.unread) {
          return false;
        }

        if (type == null) {
          return true;
        }

        return notification.type == type;
      },
    ).length;
  }

  void _changeFilter(
    NotificationFilter filter,
  ) {
    if (_activeFilter == filter) {
      return;
    }

    setState(() {
      _activeFilter = filter;
    });
  }

  void _notifyUnreadCountChanged() {
    widget.onUnreadCountChanged?.call(
      _unreadCount,
    );
  }

  Future<void> _markAllAsRead() async {
    if (_notifications.isEmpty ||
        _unreadCount == 0 ||
        _markingAllRead) {
      return;
    }

    final MarkAllNotificationsReadCallback? callback =
        widget.onMarkAllAsRead;

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
        _notifications = _notifications
            .map(
              (
                BuyerNotificationData notification,
              ) {
                return notification.copyWith(
                  unread: false,
                );
              },
            )
            .toList();
      });

      _notifyUnreadCountChanged();

      _showMessage(
        'All notifications marked as read.',
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _markingAllRead = false;
        });
      }
    }
  }

  Future<void> _openNotification(
    BuyerNotificationData notification,
  ) async {
    if (_openingNotificationIds.contains(
      notification.id,
    )) {
      return;
    }

    final NotificationTapCallback? callback =
        widget.onNotificationTap;

    if (callback == null) {
      return;
    }

    setState(() {
      _openingNotificationIds.add(
        notification.id,
      );
    });

    try {
      /*
       * Opening a notification and marking a notification
       * as read are intentionally separate concerns.
       *
       * We do NOT locally flip unread=false here because the
       * known Laravel Buyer notification flow guarantees
       * mark-all-read, not a per-notification read endpoint.
       */
      await callback(
        notification,
      );
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _openingNotificationIds.remove(
            notification.id,
          );
        });
      }
    }
  }

  Future<void> _refresh() async {
    final RefreshNotificationsCallback? callback =
        widget.onRefresh;

    if (callback == null || _refreshing) {
      return;
    }

    setState(() {
      _refreshing = true;
    });

    try {
      final List<BuyerNotificationData> refreshed =
          await callback();

      if (!mounted) {
        return;
      }

      setState(() {
        _notifications =
            List<BuyerNotificationData>.from(
          refreshed,
        );

        final Set<String> currentIds = _notifications
            .map(
              (
                BuyerNotificationData notification,
              ) =>
                  notification.id,
            )
            .toSet();

        _openingNotificationIds.removeWhere(
          (String id) => !currentIds.contains(id),
        );
      });

      _notifyUnreadCountChanged();
    } catch (error) {
      _showMessage(
        _errorText(
          error,
        ),
        error: true,
      );
    } finally {
      if (mounted) {
        setState(() {
          _refreshing = false;
        });
      }
    }
  }

  void _showMessage(
    String message, {
    bool error = false,
  }) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    )
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor:
              error ? _danger : _maroonDark,
          margin: const EdgeInsets.all(
            16,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              14,
            ),
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

  String _errorText(
    Object error,
  ) {
    return error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
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
                  physics:
                      const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    14,
                    15,
                    14,
                    100,
                  ),
                  children: [
                    _buildHeading(),

                    const SizedBox(
                      height: 17,
                    ),

                    _buildFilters(),

                    const SizedBox(
                      height: 16,
                    ),

                    if (visibleNotifications.isEmpty)
                      _buildEmptyState()
                    else
                      _buildNotificationList(
                        visibleNotifications,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        7,
        5,
        12,
        7,
      ),
      decoration: const BoxDecoration(
        color: _background,
        border: Border(
          bottom: BorderSide(
            color: Color(
              0xFFF0E8DF,
            ),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back',
            onPressed: widget.onBack ??
                () {
                  Navigator.of(
                    context,
                  ).maybePop();
                },
            icon: const Icon(
              Icons.arrow_back_rounded,
              color: _text,
            ),
          ),

          const SizedBox(
            width: 2,
          ),

          const Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Notifications',
                  style: TextStyle(
                    color: _text,
                    fontSize: 22,
                    height: 1.1,
                    letterSpacing: -0.4,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),

                SizedBox(
                  height: 2,
                ),

                Text(
                  'Orders, messages, rewards and account updates',
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: _muted,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),

          if (_refreshing) ...[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _maroon,
              ),
            ),

            const SizedBox(
              width: 9,
            ),
          ],

          if (_unreadCount > 0)
            Container(
              constraints: const BoxConstraints(
                minWidth: 28,
                minHeight: 28,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
              ),
              decoration: const BoxDecoration(
                color: _maroon,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                _unreadCount > 99
                    ? '99+'
                    : '$_unreadCount',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    final bool canMarkAll =
        widget.onMarkAllAsRead != null &&
        _unreadCount > 0 &&
        !_markingAllRead;

    return Container(
      padding: const EdgeInsets.all(
        19,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(
          20,
        ),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(
              alpha: 0.045,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.notifications_none_rounded,
                color: _maroon,
                size: 18,
              ),

              SizedBox(
                width: 7,
              ),

              Text(
                'NOTIFICATION CENTER',
                style: TextStyle(
                  color: _maroon,
                  fontSize: 11.5,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 8,
          ),

          const Text(
            'Important activity from your LIKHAE account.',
            style: TextStyle(
              color: _text,
              fontSize: 20,
              height: 1.25,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Text(
            _unreadCount == 0
                ? 'You have no unread notifications.'
                : '$_unreadCount ${_unreadCount == 1 ? 'notification is' : 'notifications are'} waiting for your attention.',
            style: const TextStyle(
              color: _muted,
              fontSize: 13.5,
              height: 1.55,
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed:
                  canMarkAll ? _markAllAsRead : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: _maroon,
                disabledForegroundColor: _muted2,
                side: BorderSide(
                  color: canMarkAll
                      ? _tan
                      : _border,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(
                    12,
                  ),
                ),
              ),
              icon: _markingAllRead
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _maroon,
                      ),
                    )
                  : const Icon(
                      Icons.done_all_rounded,
                      size: 17,
                    ),
              label: Text(
                _unreadCount == 0
                    ? 'All notifications read'
                    : 'Mark all as read',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),

          if (widget.onMarkAllAsRead == null &&
              _unreadCount > 0) ...[
            const SizedBox(
              height: 8,
            ),

            const Text(
              'Mark-all-read will become available when the Laravel notification action is connected.',
              style: TextStyle(
                color: _muted,
                fontSize: 12,
                height: 1.5,
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
        itemCount:
            NotificationFilter.values.length,
        separatorBuilder: (
          BuildContext context,
          int index,
        ) {
          return const SizedBox(
            width: 6,
          );
        },
        itemBuilder: (
          BuildContext context,
          int index,
        ) {
          final NotificationFilter filter =
              NotificationFilter.values[index];

          final bool selected =
              filter == _activeFilter;

          final int totalCount =
              _filterCount(
            filter,
          );

          final int unreadCount =
              _filterUnreadCount(
            filter,
          );

          return Material(
            color: selected
                ? _maroon
                : _surface,
            borderRadius: BorderRadius.circular(
              11,
            ),
            child: InkWell(
              onTap: () {
                _changeFilter(
                  filter,
                );
              },
              borderRadius: BorderRadius.circular(
                11,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 13,
                ),
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    11,
                  ),
                  border: Border.all(
                    color: selected
                        ? _maroon
                        : _border,
                  ),
                ),
                alignment: Alignment.center,
                child: Row(
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : _brown,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      '$totalCount',
                      style: TextStyle(
                        color: selected
                            ? Colors.white.withValues(
                                alpha: 0.72,
                              )
                            : _muted2,
                        fontSize: 12,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    if (unreadCount > 0) ...[
                      const SizedBox(
                        width: 5,
                      ),

                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: selected
                              ? Colors.white
                              : _maroon,
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

  Widget _buildNotificationList(
    List<BuyerNotificationData> notifications,
  ) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _border,
        ),
        boxShadow: [
          BoxShadow(
            color: _maroon.withValues(
              alpha: 0.04,
            ),
            blurRadius: 20,
            offset: const Offset(
              0,
              8,
            ),
          ),
        ],
      ),
      child: Column(
        children: List<Widget>.generate(
          notifications.length,
          (
            int index,
          ) {
            final BuyerNotificationData notification =
                notifications[index];

            final bool last =
                index == notifications.length - 1;

            final bool actionable =
                widget.onNotificationTap != null;

            return _NotificationTile(
              notification: notification,
              opening:
                  _openingNotificationIds.contains(
                notification.id,
              ),
              enabled: actionable,
              showDivider: !last,
              onTap: () {
                _openNotification(
                  notification,
                );
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final String categoryName =
        _activeFilter.label.toLowerCase();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        24,
        55,
        24,
        55,
      ),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color: _border,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(
                0xFFF1E4D7,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.notifications_none_rounded,
              color: _maroon,
              size: 30,
            ),
          ),

          const SizedBox(
            height: 17,
          ),

          const Text(
            'No notifications',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _text,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Text(
            _activeFilter ==
                    NotificationFilter.all
                ? 'There are no account updates yet.'
                : 'There are no $categoryName updates in this section.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _muted,
              fontSize: 13.5,
              height: 1.55,
            ),
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

  const _NotificationTile({
    required this.notification,
    required this.opening,
    required this.enabled,
    required this.showDivider,
    required this.onTap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final bool unread =
        notification.unread;

    final bool canOpen =
        enabled && !opening;

    return Material(
      color: unread
          ? const Color(
              0xFFFFF4F0,
            )
          : const Color(
              0xFFFFFDF9,
            ),
      child: InkWell(
        onTap: canOpen
            ? onTap
            : null,
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            13,
            14,
            13,
            14,
          ),
          decoration: BoxDecoration(
            border: showDivider
                ? const Border(
                    bottom: BorderSide(
                      color: Color(
                        0xFFF0E8DF,
                      ),
                    ),
                  )
                : null,
          ),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 43,
                height: 43,
                decoration: BoxDecoration(
                  color: unread
                      ? const Color(
                          0xFF561C17,
                        )
                      : const Color(
                          0xFFF1ECE7,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    12,
                  ),
                ),
                alignment: Alignment.center,
                child: Icon(
                  notification.type.icon,
                  color: unread
                      ? Colors.white
                      : const Color(
                          0xFF987865,
                        ),
                  size: 19,
                ),
              ),

              const SizedBox(
                width: 11,
              ),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: TextStyle(
                              color: const Color(
                                0xFF3B211B,
                              ),
                              fontSize: 14,
                              height: 1.25,
                              fontWeight: unread
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ),

                        if (notification.time
                            .trim()
                            .isNotEmpty) ...[
                          const SizedBox(
                            width: 8,
                          ),

                          Text(
                            notification.time,
                            style: const TextStyle(
                              color: Color(
                                0xFFA99386,
                              ),
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ],
                    ),

                    if (notification.message
                        .trim()
                        .isNotEmpty) ...[
                      const SizedBox(
                        height: 5,
                      ),

                      Text(
                        notification.message,
                        style: const TextStyle(
                          color: Color(
                            0xFF987865,
                          ),
                          fontSize: 13,
                          height: 1.55,
                        ),
                      ),
                    ],

                    const SizedBox(
                      height: 8,
                    ),

                    Row(
                      children: [
                        Container(
                          padding:
                              const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFF6EFE7,
                            ),
                            borderRadius:
                                BorderRadius.circular(
                              100,
                            ),
                          ),
                          child: Text(
                            notification.type.label,
                            style: const TextStyle(
                              color: Color(
                                0xFF6C4936,
                              ),
                              fontSize: 11.5,
                              fontWeight:
                                  FontWeight.w800,
                            ),
                          ),
                        ),

                        if (unread) ...[
                          const SizedBox(
                            width: 6,
                          ),

                          Container(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFFFCE9E5,
                              ),
                              borderRadius:
                                  BorderRadius.circular(
                                100,
                              ),
                            ),
                            child: const Text(
                              'UNREAD',
                              style: TextStyle(
                                color: Color(
                                  0xFF561C17,
                                ),
                                fontSize: 11,
                                letterSpacing: 0.4,
                                fontWeight:
                                    FontWeight.w900,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        if (opening)
                          const SizedBox(
                            width: 15,
                            height: 15,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 1.8,
                              color: Color(
                                0xFF561C17,
                              ),
                            ),
                          )
                        else if (enabled)
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: Color(
                              0xFFA99386,
                            ),
                            size: 18,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              if (unread) ...[
                const SizedBox(
                  width: 7,
                ),

                Container(
                  margin: const EdgeInsets.only(
                    top: 7,
                  ),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(
                      0xFF561C17,
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
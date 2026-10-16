import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/config/app_config.dart';
import '../../core/storage/token_storage.dart';
import '../../features/buyer/notifications/notifications_screen.dart';
import '../../features/buyer/settings/buyer_system_settings_controller.dart';
import '../../services/app_notification_center.dart';
import '../../services/buyer_mobile_service.dart';
import '../../services/rider_mobile_service.dart';

/// Keeps authenticated notifications visible as an in-app banner on every
/// buyer and rider route.
class AppNotificationHost extends StatefulWidget {
  final GoRouter router;
  final Widget child;

  const AppNotificationHost({
    super.key,
    required this.router,
    required this.child,
  });

  @override
  State<AppNotificationHost> createState() => _AppNotificationHostState();
}

class _AppNotificationHostState extends State<AppNotificationHost> {
  static const Color _surface = Color(0xFFFFFDF9);
  static const Color _border = Color(0xFFEADCCC);
  static const Color _text = Color(0xFF3B211B);
  static const Color _muted = Color(0xFF987865);
  static const Color _maroon = Color(0xFF561C17);

  final Set<String> _seenNotificationIds = <String>{};

  StreamSubscription<BuyerNotificationData>? _notificationSubscription;
  StreamSubscription<BuyerNotificationData>? _localNotificationSubscription;
  Timer? _retryTimer;
  Timer? _pollTimer;
  Timer? _dismissTimer;
  Timer? _clearBannerTimer;

  BuyerNotificationData? _activeNotification;
  String? _activeRole;
  bool _bannerVisible = false;
  bool _notificationBaselineLoaded = false;
  int _generation = 0;
  int _retryAttempt = 0;
  bool _pollInProgress = false;

  @override
  void initState() {
    super.initState();
    _localNotificationSubscription = AppNotificationCenter.notifications.listen(
      _showNotification,
    );
    widget.router.routeInformationProvider.addListener(_onRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _onRouteChanged());
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_onRouteChanged);
    _retryTimer?.cancel();
    _pollTimer?.cancel();
    _dismissTimer?.cancel();
    _clearBannerTimer?.cancel();
    unawaited(_notificationSubscription?.cancel());
    unawaited(_localNotificationSubscription?.cancel());
    super.dispose();
  }

  String _roleForCurrentRoute() {
    final String path = widget.router.routeInformationProvider.value.uri.path;
    if (path.startsWith('/buyer/')) return 'buyer';
    if (path.startsWith('/rider/')) return 'rider';
    return '';
  }

  void _onRouteChanged() {
    final String role = _roleForCurrentRoute();
    if (role == _activeRole) return;
    unawaited(_switchRole(role));
  }

  Future<void> _switchRole(String role) async {
    final int generation = ++_generation;
    _activeRole = role;
    _retryAttempt = 0;
    _notificationBaselineLoaded = false;
    _seenNotificationIds.clear();
    _retryTimer?.cancel();
    _retryTimer = null;
    _pollTimer?.cancel();
    _pollTimer = null;

    final StreamSubscription<BuyerNotificationData>? previousSubscription =
        _notificationSubscription;
    _notificationSubscription = null;
    await previousSubscription?.cancel();

    if (!mounted || generation != _generation) return;

    if (role.isEmpty) {
      _hideBanner(clearImmediately: true);
      return;
    }

    if (!AppConfig.apiEnabled) return;

    final String? token = await TokenStorage.readToken();
    if (!mounted ||
        generation != _generation ||
        token?.trim().isNotEmpty != true) {
      return;
    }

    unawaited(_loadNotificationBaseline(role, generation));

    if (AppConfig.realtimeEnabled) {
      _connectRealtime(role, generation);
    } else {
      _startPolling(role, generation);
    }
  }

  Future<void> _loadNotificationBaseline(String role, int generation) async {
    try {
      final List<BuyerNotificationData> notifications =
          await _fetchNotifications(role);
      if (!_isCurrent(role, generation)) return;
      for (final BuyerNotificationData notification in notifications) {
        _rememberNotification(notification.id);
      }
      _notificationBaselineLoaded = true;
    } catch (_) {
      // Realtime can still deliver notifications if the initial list is down.
    }
  }

  void _connectRealtime(String role, int generation) {
    if (!_isCurrent(role, generation)) return;

    try {
      _notificationSubscription = BuyerMobileService.watchNotifications()
          .listen(
            (BuyerNotificationData notification) {
              if (!_isCurrent(role, generation)) return;
              _retryAttempt = 0;
              _showNotification(notification);
            },
            onError: (Object _) {
              _startPolling(role, generation);
              _scheduleRealtimeRetry(role, generation);
            },
            onDone: () => _scheduleRealtimeRetry(role, generation),
          );
    } catch (_) {
      _startPolling(role, generation);
      _scheduleRealtimeRetry(role, generation);
    }
  }

  void _scheduleRealtimeRetry(String role, int generation) {
    if (!_isCurrent(role, generation) || _retryTimer != null) return;

    final int exponent = _retryAttempt.clamp(0, 5).toInt();
    final int seconds = (1 << exponent).clamp(2, 30).toInt();
    _retryAttempt++;
    _retryTimer = Timer(Duration(seconds: seconds), () {
      _retryTimer = null;
      if (!_isCurrent(role, generation)) return;
      unawaited(_notificationSubscription?.cancel());
      _notificationSubscription = null;
      _connectRealtime(role, generation);
    });
  }

  void _startPolling(String role, int generation) {
    if (!_isCurrent(role, generation) || _pollTimer != null) return;
    unawaited(_pollNotifications(role, generation));
    _pollTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      unawaited(_pollNotifications(role, generation));
    });
  }

  Future<void> _pollNotifications(String role, int generation) async {
    if (_pollInProgress) return;
    _pollInProgress = true;
    try {
      final List<BuyerNotificationData> notifications =
          await _fetchNotifications(role);
      if (!_isCurrent(role, generation)) return;

      if (!_notificationBaselineLoaded) {
        for (final BuyerNotificationData notification in notifications) {
          _rememberNotification(notification.id);
        }
        _notificationBaselineLoaded = true;
        return;
      }

      for (final BuyerNotificationData notification in notifications.reversed) {
        if (notification.unread) _showNotification(notification);
      }
    } catch (_) {
      // Keep the periodic fallback alive while the app remains on this account.
    } finally {
      _pollInProgress = false;
    }
  }

  Future<List<BuyerNotificationData>> _fetchNotifications(String role) {
    return role == 'rider'
        ? RiderMobileService.fetchNotifications()
        : BuyerMobileService.fetchNotifications();
  }

  bool _isCurrent(String role, int generation) {
    return mounted &&
        generation == _generation &&
        _activeRole == role &&
        role.isNotEmpty;
  }

  bool _rememberNotification(String id) {
    final String normalizedId = id.trim();
    if (normalizedId.isEmpty || !_seenNotificationIds.add(normalizedId)) {
      return false;
    }
    if (_seenNotificationIds.length > 300) {
      _seenNotificationIds.remove(_seenNotificationIds.first);
    }
    return true;
  }

  void _showNotification(BuyerNotificationData notification) {
    if (!_rememberNotification(notification.id)) return;
    final BuyerSystemSettingsController settings =
        BuyerSystemSettingsController.instance;
    if (_activeRole == 'buyer' &&
        !settings.allowsNotification(category: notification.type.key)) {
      return;
    }
    _dismissTimer?.cancel();
    _clearBannerTimer?.cancel();
    setState(() {
      _activeNotification = notification;
      _bannerVisible = true;
    });
    if (settings.notificationSounds) {
      unawaited(
        SystemSound.play(SystemSoundType.alert).catchError((Object _) {}),
      );
    }
    _dismissTimer = Timer(const Duration(seconds: 6), _dismissBanner);
  }

  void _dismissBanner() {
    if (!mounted) return;
    _dismissTimer?.cancel();
    setState(() => _bannerVisible = false);
    _clearBannerTimer?.cancel();
    _clearBannerTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted || _bannerVisible) return;
      setState(() => _activeNotification = null);
    });
  }

  void _hideBanner({bool clearImmediately = false}) {
    _dismissTimer?.cancel();
    _clearBannerTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _bannerVisible = false;
      if (clearImmediately) _activeNotification = null;
    });
  }

  void _openNotification() {
    _dismissBanner();
    final BuyerNotificationData? notification = _activeNotification;
    final String path;
    if (_activeRole == 'rider') {
      path = switch (notification?.type) {
        BuyerNotificationType.orders => '/rider/assignments',
        BuyerNotificationType.deliveries => '/rider/assignments',
        BuyerNotificationType.messages => '/rider/messages',
        _ => '/rider/notifications',
      };
    } else {
      path = switch (notification?.type) {
        BuyerNotificationType.orders => '/buyer/orders',
        BuyerNotificationType.deliveries => '/buyer/orders',
        BuyerNotificationType.messages => '/buyer/messages',
        BuyerNotificationType.rewards => '/buyer/rewards',
        BuyerNotificationType.account => '/buyer/profile',
        _ => '/buyer/notifications',
      };
    }
    widget.router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final BuyerNotificationData? notification = _activeNotification;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (notification != null)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: AnimatedSlide(
                  offset: _bannerVisible ? Offset.zero : const Offset(0, -1.3),
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: AnimatedOpacity(
                    opacity: _bannerVisible ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Material(
                      color: _surface,
                      elevation: 10,
                      shadowColor: Colors.black.withValues(alpha: 0.18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
                        side: const BorderSide(color: _border),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                        child: Row(
                          children: <Widget>[
                            Container(
                              width: 40,
                              height: 40,
                              decoration: const BoxDecoration(
                                color: Color(0xFFF1E4D7),
                                shape: BoxShape.circle,
                              ),
                              alignment: Alignment.center,
                              child: Icon(
                                notification.type.icon,
                                size: 20,
                                color: _maroon,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: InkWell(
                                onTap: _openNotification,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: <Widget>[
                                      Text(
                                        notification.title.trim().isEmpty
                                            ? 'LIKHAE notification'
                                            : notification.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          color: _text,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      if (notification.message
                                          .trim()
                                          .isNotEmpty) ...<Widget>[
                                        const SizedBox(height: 3),
                                        Text(
                                          notification.message,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: _muted,
                                            fontSize: 12,
                                            height: 1.3,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Semantics(
                              button: true,
                              label: 'Dismiss notification',
                              child: SizedBox(
                                width: 40,
                                height: 40,
                                child: InkWell(
                                  onTap: _dismissBanner,
                                  customBorder: const CircleBorder(),
                                  child: const Center(
                                    child: Icon(
                                      Icons.close_rounded,
                                      color: _muted,
                                      size: 19,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

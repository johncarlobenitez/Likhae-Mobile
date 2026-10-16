import 'dart:async';

import '../features/buyer/notifications/notifications_screen.dart';

/// Delivers in-app events created directly by successful app actions.
class AppNotificationCenter {
  AppNotificationCenter._();

  static final StreamController<BuyerNotificationData> _controller =
      StreamController<BuyerNotificationData>.broadcast();

  static Stream<BuyerNotificationData> get notifications => _controller.stream;

  static void showOrderPlaced() {
    final DateTime now = DateTime.now();
    _controller.add(
      BuyerNotificationData(
        id: 'local-order-placed-${now.microsecondsSinceEpoch}',
        type: BuyerNotificationType.orders,
        title: 'Order placed',
        message: 'Your order has been placed successfully.',
        time: 'Just now',
        unread: true,
        createdAt: now,
      ),
    );
  }
}

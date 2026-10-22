import 'dart:async';

import 'package:flutter/services.dart';

class NotificationSoundOption {
  final String key;
  final String title;
  final String description;

  const NotificationSoundOption({
    required this.key,
    required this.title,
    required this.description,
  });
}

/// Mobile version of the notification sound patterns used by Laravel.
class NotificationSoundService {
  NotificationSoundService._();

  static const MethodChannel _channel = MethodChannel(
    'likhae/notification_sounds',
  );

  static const List<NotificationSoundOption> catalog =
      <NotificationSoundOption>[
        NotificationSoundOption(
          key: 'order_updates',
          title: 'Order tone',
          description: 'Order confirmation, processing, and status changes.',
        ),
        NotificationSoundOption(
          key: 'delivery_updates',
          title: 'Delivery tone',
          description: 'Pickup, sorting, rider, and delivery updates.',
        ),
        NotificationSoundOption(
          key: 'chat_updates',
          title: 'Message tone',
          description: 'New messages from the Messages feature.',
        ),
        NotificationSoundOption(
          key: 'promotion_updates',
          title: 'Promotion tone',
          description: 'Vouchers, discounts, and campaign updates.',
        ),
        NotificationSoundOption(
          key: 'earnings_updates',
          title: 'Payment tone',
          description: 'Payment, refund, and account balance updates.',
        ),
        NotificationSoundOption(
          key: 'warning_updates',
          title: 'Warning tone',
          description: 'Security, failed actions, and urgent alerts.',
        ),
        NotificationSoundOption(
          key: 'return_updates',
          title: 'Return tone',
          description: 'Returns, refunds, and dispute updates.',
        ),
        NotificationSoundOption(
          key: 'general_updates',
          title: 'General tone',
          description: 'Other supported LIKHAE notifications.',
        ),
      ];

  static const Map<String, List<List<int>>> _patterns =
      <String, List<List<int>>>{
        'message': <List<int>>[
          <int>[660, 0, 80],
          <int>[880, 90, 100],
        ],
        'order': <List<int>>[
          <int>[523, 0, 90],
          <int>[659, 100, 90],
          <int>[784, 200, 120],
        ],
        'delivery': <List<int>>[
          <int>[440, 0, 80],
          <int>[554, 90, 80],
          <int>[659, 180, 130],
        ],
        'promotion': <List<int>>[
          <int>[784, 0, 70],
          <int>[988, 80, 70],
          <int>[1175, 160, 120],
        ],
        'earnings': <List<int>>[
          <int>[587, 0, 80],
          <int>[740, 90, 80],
          <int>[988, 180, 140],
        ],
        'warning': <List<int>>[
          <int>[392, 0, 120],
          <int>[330, 140, 160],
        ],
        'return': <List<int>>[
          <int>[494, 0, 100],
          <int>[440, 120, 100],
          <int>[392, 240, 140],
        ],
        'general': <List<int>>[
          <int>[620, 0, 90],
          <int>[780, 110, 120],
        ],
      };

  static List<Timer> _fallbackTimers = <Timer>[];

  static Future<void> preview(String key) => play(key);

  static Future<void> play(String notificationType) async {
    final String patternName = _toneFor(notificationType);
    final List<List<int>> tones = _patterns[patternName] ?? _patterns['general']!;

    try {
      await _channel.invokeMethod<void>(
        'play',
        <String, Object>{'tones': tones},
      );
    } on MissingPluginException {
      _playSystemFallback(tones);
    } on PlatformException {
      _playSystemFallback(tones);
    }
  }

  static String _toneFor(String type) {
    final String value = type.toUpperCase();
    if (RegExp(r'MESSAGE|CHAT').hasMatch(value)) return 'message';
    if (RegExp(r'ORDER|PURCHASE|CHECKOUT').hasMatch(value)) return 'order';
    if (RegExp(
      r'DELIVERY|SHIPMENT|PICKUP|PARCEL|DISPATCH|RIDER|SORT|INVENTORY|ROUTE',
    ).hasMatch(value)) {
      return 'delivery';
    }
    if (RegExp(r'PROMO|VOUCHER|DISCOUNT|CAMPAIGN|REWARD').hasMatch(value)) {
      return 'promotion';
    }
    if (RegExp(r'EARNING|PAYOUT|FINANCE|COMMISSION|PAYMENT').hasMatch(value)) {
      return 'earnings';
    }
    if (RegExp(
      r'SUSPEND|SECURITY|COMPLIANCE|WARNING|REJECT|FAILED|EXCEPTION|REGISTRATION',
    ).hasMatch(value)) {
      return 'warning';
    }
    if (RegExp(r'RETURN|REFUND|DISPUTE|COMPLAINT').hasMatch(value)) {
      return 'return';
    }
    return 'general';
  }

  static void _playSystemFallback(List<List<int>> tones) {
    for (final Timer timer in _fallbackTimers) {
      timer.cancel();
    }
    _fallbackTimers = <Timer>[];
    for (final List<int> tone in tones) {
      _fallbackTimers.add(
        Timer(Duration(milliseconds: tone[1]), () {
          unawaited(
            SystemSound.play(SystemSoundType.alert).catchError((Object _) {}),
          );
        }),
      );
    }
  }
}

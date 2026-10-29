import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/config/app_config.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../services/buyer_mobile_service.dart';

class BuyerSystemSettingsController extends ChangeNotifier {
  BuyerSystemSettingsController._();

  static final BuyerSystemSettingsController instance =
      BuyerSystemSettingsController._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'likhae_buyer_system_settings';

  Future<void> _writeQueue = Future<void>.value();
  Future<void>? _loadFuture;

  bool orderUpdates = true;
  bool deliveryUpdates = true;
  bool chatNotifications = true;
  bool promotionUpdates = true;
  bool showOnlineStatus = true;
  bool showAiAssistant = true;
  bool aiResponseSound = false;
  bool notificationSounds = true;
  bool riderAssignmentUpdates = true;
  bool riderRouteUpdates = true;
  bool riderChatUpdates = true;
  bool riderEarningsUpdates = true;
  bool riderSafetyUpdates = true;
  bool riderNotificationSounds = true;

  ThemeMode get themeMode => ThemeController.instance.value;

  Future<void> load() => _loadFuture ??= _load();

  Future<bool> refreshServerSettings() async {
    if (!AppConfig.apiEnabled) return false;
    try {
      final Map<String, dynamic> remote =
          await BuyerMobileService.fetchBuyerSettings();
      orderUpdates = _readApiBool(remote, 'order_updates', orderUpdates);
      deliveryUpdates = _readApiBool(
        remote,
        'delivery_updates',
        deliveryUpdates,
      );
      chatNotifications = _readApiBool(
        remote,
        'chat_updates',
        chatNotifications,
      );
      promotionUpdates = _readApiBool(
        remote,
        'promotion_updates',
        promotionUpdates,
      );
      showOnlineStatus = _readApiBool(
        remote,
        'show_online_status',
        showOnlineStatus,
      );
      showAiAssistant = _readApiBool(
        remote,
        'ai_assistant_enabled',
        showAiAssistant,
      );
      aiResponseSound = _readApiBool(
        remote,
        'ai_response_sound',
        aiResponseSound,
      );
      notificationSounds = _readApiBool(
        remote,
        'notification_sounds',
        notificationSounds,
      );
      final String theme = (remote['theme'] ?? '').toString();
      for (final ThemeMode mode in ThemeMode.values) {
        if (mode.name == theme) ThemeController.instance.value = mode;
      }
      await _enqueueWrite(_encode());
      notifyListeners();
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _load() async {
    try {
      final String? value = await _storage.read(key: _storageKey);
      if (value == null || value.isEmpty) return;

      final dynamic decoded = jsonDecode(value);
      if (decoded is! Map) return;
      final Map<dynamic, dynamic> settings = decoded;

      orderUpdates = _readBool(settings, 'orderUpdates', orderUpdates);
      deliveryUpdates = _readBool(settings, 'deliveryUpdates', deliveryUpdates);
      chatNotifications = _readBool(
        settings,
        'chatNotifications',
        chatNotifications,
      );
      promotionUpdates = _readBool(
        settings,
        'promotionUpdates',
        promotionUpdates,
      );
      showAiAssistant = _readBool(settings, 'showAiAssistant', showAiAssistant);
      aiResponseSound = _readBool(settings, 'aiResponseSound', aiResponseSound);
      notificationSounds = _readBool(
        settings,
        'notificationSounds',
        notificationSounds,
      );
      riderAssignmentUpdates = _readBool(
        settings,
        'riderAssignmentUpdates',
        riderAssignmentUpdates,
      );
      riderRouteUpdates = _readBool(
        settings,
        'riderRouteUpdates',
        riderRouteUpdates,
      );
      riderChatUpdates = _readBool(
        settings,
        'riderChatUpdates',
        riderChatUpdates,
      );
      riderEarningsUpdates = _readBool(
        settings,
        'riderEarningsUpdates',
        riderEarningsUpdates,
      );
      riderSafetyUpdates = _readBool(
        settings,
        'riderSafetyUpdates',
        riderSafetyUpdates,
      );
      riderNotificationSounds = _readBool(
        settings,
        'riderNotificationSounds',
        riderNotificationSounds,
      );

      final String savedTheme = (settings['themeMode'] ?? '').toString();
      for (final ThemeMode mode in ThemeMode.values) {
        if (mode.name == savedTheme) {
          ThemeController.instance.value = mode;
          break;
        }
      }
    } catch (_) {
      // Keep the usable defaults if secure storage is temporarily unavailable.
    }
    if (AppConfig.apiEnabled) {
      try {
        final Map<String, dynamic> remote =
            await BuyerMobileService.fetchBuyerSettings();
        orderUpdates = _readApiBool(remote, 'order_updates', orderUpdates);
        deliveryUpdates = _readApiBool(
          remote,
          'delivery_updates',
          deliveryUpdates,
        );
        chatNotifications = _readApiBool(
          remote,
          'chat_updates',
          chatNotifications,
        );
        promotionUpdates = _readApiBool(
          remote,
          'promotion_updates',
          promotionUpdates,
        );
        showOnlineStatus = _readApiBool(
          remote,
          'show_online_status',
          showOnlineStatus,
        );
        showAiAssistant = _readApiBool(
          remote,
          'ai_assistant_enabled',
          showAiAssistant,
        );
        aiResponseSound = _readApiBool(
          remote,
          'ai_response_sound',
          aiResponseSound,
        );
        notificationSounds = _readApiBool(
          remote,
          'notification_sounds',
          notificationSounds,
        );
        final String theme = (remote['theme'] ?? '').toString();
        for (final ThemeMode mode in ThemeMode.values) {
          if (mode.name == theme) ThemeController.instance.value = mode;
        }
      } catch (_) {
        // Keep device settings available if the account settings endpoint is offline.
      }
    }
    notifyListeners();
  }

  void setTheme(ThemeMode mode) {
    ThemeController.instance.value = mode;
    _persist();
    notifyListeners();
  }

  void update({
    bool? orderUpdates,
    bool? deliveryUpdates,
    bool? chatNotifications,
    bool? promotionUpdates,
    bool? showOnlineStatus,
    bool? showAiAssistant,
    bool? aiResponseSound,
    bool? notificationSounds,
    bool? riderAssignmentUpdates,
    bool? riderRouteUpdates,
    bool? riderChatUpdates,
    bool? riderEarningsUpdates,
    bool? riderSafetyUpdates,
    bool? riderNotificationSounds,
  }) {
    this.orderUpdates = orderUpdates ?? this.orderUpdates;
    this.deliveryUpdates = deliveryUpdates ?? this.deliveryUpdates;
    this.chatNotifications = chatNotifications ?? this.chatNotifications;
    this.promotionUpdates = promotionUpdates ?? this.promotionUpdates;
    this.showOnlineStatus = showOnlineStatus ?? this.showOnlineStatus;
    this.showAiAssistant = showAiAssistant ?? this.showAiAssistant;
    this.aiResponseSound = aiResponseSound ?? this.aiResponseSound;
    this.notificationSounds = notificationSounds ?? this.notificationSounds;
    this.riderAssignmentUpdates =
        riderAssignmentUpdates ?? this.riderAssignmentUpdates;
    this.riderRouteUpdates = riderRouteUpdates ?? this.riderRouteUpdates;
    this.riderChatUpdates = riderChatUpdates ?? this.riderChatUpdates;
    this.riderEarningsUpdates =
        riderEarningsUpdates ?? this.riderEarningsUpdates;
    this.riderSafetyUpdates = riderSafetyUpdates ?? this.riderSafetyUpdates;
    this.riderNotificationSounds =
        riderNotificationSounds ?? this.riderNotificationSounds;
    _persist();
    notifyListeners();
  }

  Future<bool> save({bool syncServer = true}) async {
    await _enqueueWrite(_encode());
    if (!syncServer || !AppConfig.apiEnabled) return true;
    try {
      await BuyerMobileService.saveBuyerSettings(<String, dynamic>{
        'order_updates': orderUpdates,
        'delivery_updates': deliveryUpdates,
        'chat_updates': chatNotifications,
        'promotion_updates': promotionUpdates,
        'show_online_status': showOnlineStatus,
        'ai_assistant_enabled': showAiAssistant,
        'ai_response_sound': aiResponseSound,
        'notification_sounds': notificationSounds,
        'theme': themeMode.name,
        'language': 'en',
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  bool allowsNotification({required String category}) {
    switch (category) {
      case 'orders':
        return orderUpdates;
      case 'deliveries':
        return deliveryUpdates;
      case 'messages':
        return chatNotifications;
      case 'rewards':
        return promotionUpdates;
      default:
        return true;
    }
  }

  bool allowsRiderNotification({required String category}) {
    switch (category) {
      case 'orders':
        return riderAssignmentUpdates;
      case 'deliveries':
        return riderRouteUpdates;
      case 'messages':
        return riderChatUpdates;
      case 'rewards':
        return riderEarningsUpdates;
      case 'account':
      case 'general':
        return riderSafetyUpdates;
      default:
        return true;
    }
  }

  bool _readBool(Map<dynamic, dynamic> settings, String key, bool fallback) {
    final dynamic value = settings[key];
    return value is bool ? value : fallback;
  }

  bool _readApiBool(Map<String, dynamic> settings, String key, bool fallback) {
    final dynamic value = settings[key];
    if (value is bool) return value;
    if (value == null) return fallback;
    return value.toString() == '1' || value.toString().toLowerCase() == 'true';
  }

  void _persist() {
    unawaited(_enqueueWrite(_encode()).catchError((Object _) {}));
  }

  Future<void> _enqueueWrite(String value) {
    final Future<void> nextWrite = _writeQueue
        .catchError((Object _) {})
        .then((_) => _storage.write(key: _storageKey, value: value));
    _writeQueue = nextWrite;
    return nextWrite;
  }

  String _encode() {
    return jsonEncode(<String, Object>{
      'orderUpdates': orderUpdates,
      'deliveryUpdates': deliveryUpdates,
      'chatNotifications': chatNotifications,
      'promotionUpdates': promotionUpdates,
      'showOnlineStatus': showOnlineStatus,
      'showAiAssistant': showAiAssistant,
      'aiResponseSound': aiResponseSound,
      'notificationSounds': notificationSounds,
      'riderAssignmentUpdates': riderAssignmentUpdates,
      'riderRouteUpdates': riderRouteUpdates,
      'riderChatUpdates': riderChatUpdates,
      'riderEarningsUpdates': riderEarningsUpdates,
      'riderSafetyUpdates': riderSafetyUpdates,
      'riderNotificationSounds': riderNotificationSounds,
      'themeMode': themeMode.name,
    });
  }
}

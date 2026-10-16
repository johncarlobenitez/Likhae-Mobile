import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/theme/theme_controller.dart';

class BuyerSystemSettingsController extends ChangeNotifier {
  BuyerSystemSettingsController._();

  static final BuyerSystemSettingsController instance =
      BuyerSystemSettingsController._();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();
  static const String _storageKey = 'likhae_buyer_system_settings';

  Future<void> _writeQueue = Future<void>.value();

  bool orderUpdates = true;
  bool deliveryUpdates = true;
  bool chatNotifications = true;
  bool promotionUpdates = true;
  bool showAiAssistant = true;
  bool aiResponseSound = false;
  bool notificationSounds = true;

  ThemeMode get themeMode => ThemeController.instance.value;

  Future<void> load() async {
    try {
      final String? value = await _storage.read(key: _storageKey);
      if (value == null || value.isEmpty) return;

      final dynamic decoded = jsonDecode(value);
      if (decoded is! Map) return;
      final Map<dynamic, dynamic> settings = decoded;

      orderUpdates = _readBool(settings, 'orderUpdates', orderUpdates);
      deliveryUpdates = _readBool(settings, 'deliveryUpdates', deliveryUpdates);
      chatNotifications =
          _readBool(settings, 'chatNotifications', chatNotifications);
      promotionUpdates =
          _readBool(settings, 'promotionUpdates', promotionUpdates);
      showAiAssistant =
          _readBool(settings, 'showAiAssistant', showAiAssistant);
      aiResponseSound =
          _readBool(settings, 'aiResponseSound', aiResponseSound);
      notificationSounds =
          _readBool(settings, 'notificationSounds', notificationSounds);

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
    bool? showAiAssistant,
    bool? aiResponseSound,
    bool? notificationSounds,
  }) {
    this.orderUpdates = orderUpdates ?? this.orderUpdates;
    this.deliveryUpdates = deliveryUpdates ?? this.deliveryUpdates;
    this.chatNotifications = chatNotifications ?? this.chatNotifications;
    this.promotionUpdates = promotionUpdates ?? this.promotionUpdates;
    this.showAiAssistant = showAiAssistant ?? this.showAiAssistant;
    this.aiResponseSound = aiResponseSound ?? this.aiResponseSound;
    this.notificationSounds = notificationSounds ?? this.notificationSounds;
    _persist();
    notifyListeners();
  }

  Future<void> save() => _enqueueWrite(_encode());

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

  bool _readBool(Map<dynamic, dynamic> settings, String key, bool fallback) {
    final dynamic value = settings[key];
    return value is bool ? value : fallback;
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
      'showAiAssistant': showAiAssistant,
      'aiResponseSound': aiResponseSound,
      'notificationSounds': notificationSounds,
      'themeMode': themeMode.name,
    });
  }
}

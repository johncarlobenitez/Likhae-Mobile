import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'features/buyer/settings/buyer_system_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiClient.initialize();

  runApp(const LikhaeApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(BuyerSystemSettingsController.instance.load());
  });
}

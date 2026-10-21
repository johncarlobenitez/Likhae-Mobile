import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';
import 'core/api/api_client.dart';
import 'features/buyer/settings/buyer_system_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await ApiClient.initialize();

  const String mapboxAccessToken = String.fromEnvironment(
    'MAPBOX_ACCESS_TOKEN',
  );

  if (mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  runApp(const LikhaeApp());
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(BuyerSystemSettingsController.instance.load());
  });
}

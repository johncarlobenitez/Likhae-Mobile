import 'package:flutter/material.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  const String mapboxAccessToken =
      String.fromEnvironment('MAPBOX_ACCESS_TOKEN');

  if (mapboxAccessToken.isNotEmpty) {
    MapboxOptions.setAccessToken(mapboxAccessToken);
  }

  runApp(const LikhaeApp());
}

import 'package:flutter/material.dart';

class ThemeController extends ValueNotifier<ThemeMode> {
  ThemeController._()
      : super(ThemeMode.system);

  static final ThemeController instance =
      ThemeController._();

  bool get isDarkMode {
    return value == ThemeMode.dark;
  }

  bool get usesDarkPalette {
    if (value == ThemeMode.dark) return true;
    if (value == ThemeMode.light) return false;
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }

  bool get isLightMode {
    return value == ThemeMode.light;
  }

  void toggleTheme() {
    value = isDarkMode
        ? ThemeMode.light
        : ThemeMode.dark;
  }

  void setLightMode() {
    value = ThemeMode.light;
  }

  void setDarkMode() {
    value = ThemeMode.dark;
  }

  void setSystemMode() {
    value = ThemeMode.system;
  }
}

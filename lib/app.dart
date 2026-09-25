import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'routes/app_router.dart';

class LikhaeApp extends StatelessWidget {
  const LikhaeApp({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable:
          ThemeController.instance,
      builder: (
        BuildContext context,
        ThemeMode themeMode,
        Widget? child,
      ) {
        return MaterialApp.router(
          title: 'LIKHAE',

          debugShowCheckedModeBanner:
              false,

          routerConfig:
              appRouter,

          theme:
              AppTheme.lightTheme,

          darkTheme:
              AppTheme.darkTheme,

          themeMode:
              themeMode,
        );
      },
    );
  }
}
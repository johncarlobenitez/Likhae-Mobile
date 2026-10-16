import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/theme_controller.dart';
import 'routes/app_router.dart';
import 'shared/widgets/app_notification_host.dart';

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

          builder: (BuildContext context, Widget? child) {
            return AppNotificationHost(
              router: appRouter,
              child: child ?? const SizedBox.shrink(),
            );
          },

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

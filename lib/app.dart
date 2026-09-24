import 'package:flutter/material.dart';

import 'routes/app_router.dart';

class LikhaeApp extends StatelessWidget {
  const LikhaeApp({super.key});

  static const Color _background = Color(0xFFFBF7F2);
  static const Color _surface = Color(0xFFFFFDF9);

  static const Color _maroon = Color(0xFF561C17);
  static const Color _maroonDark = Color(0xFF3E130F);

  static const Color _tan = Color(0xFFC19771);
  static const Color _text = Color(0xFF3B211B);

  static const Color _muted = Color(0xFF987865);
  static const Color _border = Color(0xFFEADCCC);

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'LIKHAE',
      debugShowCheckedModeBanner: false,
      routerConfig: appRouter,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Poppins',
        scaffoldBackgroundColor: _background,
        colorScheme: const ColorScheme.light(
          primary: _maroon,
          onPrimary: Colors.white,
          secondary: _tan,
          onSecondary: _maroonDark,
          surface: _surface,
          onSurface: _text,
          error: Color(0xFFB42318),
          onError: Colors.white,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _text,
          elevation: 0,
          centerTitle: false,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: _surface,
          hintStyle: const TextStyle(
            color: _muted,
            fontSize: 12,
          ),
          labelStyle: const TextStyle(
            color: _text,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
            borderSide: const BorderSide(
              color: _border,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
            borderSide: const BorderSide(
              color: _border,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
            borderSide: const BorderSide(
              color: _maroon,
              width: 1.3,
            ),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
            borderSide: const BorderSide(
              color: Color(0xFFB42318),
            ),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(
              12,
            ),
            borderSide: const BorderSide(
              color: Color(0xFFB42318),
              width: 1.3,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: _maroon,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _maroon.withValues(
              alpha: 0.4,
            ),
            disabledForegroundColor: Colors.white.withValues(
              alpha: 0.7,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: _maroon,
            side: const BorderSide(
              color: _tan,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                12,
              ),
            ),
            textStyle: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: _maroon,
          ),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: _maroonDark,
          contentTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              14,
            ),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: _border,
          thickness: 1,
          space: 1,
        ),
        progressIndicatorTheme:
            const ProgressIndicatorThemeData(
          color: _maroon,
        ),
        checkboxTheme: CheckboxThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(
                WidgetState.selected,
              )) {
                return _maroon;
              }

              return null;
            },
          ),
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.resolveWith<Color?>(
            (Set<WidgetState> states) {
              if (states.contains(
                WidgetState.selected,
              )) {
                return _maroon;
              }

              return null;
            },
          ),
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: _surface,
          indicatorColor: Color(0xFFF1E4D7),
          surfaceTintColor: Colors.transparent,
          elevation: 0,
        ),
      ),
    );
  }
}
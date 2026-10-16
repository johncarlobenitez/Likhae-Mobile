import 'package:flutter/material.dart';

import 'theme_controller.dart';
import 'shop_colors.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // LIKHAE LIGHT PALETTE
  // ============================================================

  static const Color lightBackground = ShopColors.canvas;

  static const Color lightSurface = ShopColors.surface;

  static const Color lightSurfaceSoft = ShopColors.soft;

  static const Color lightSurfaceStrong = ShopColors.accentSoft;

  static const Color lightMaroon = ShopColors.accent;

  static const Color lightMaroonDark = ShopColors.accentDark;

  static const Color lightMaroonSoft = ShopColors.accentLight;

  static const Color lightTan = ShopColors.tan;

  static const Color lightText = ShopColors.text;

  static const Color lightBrown = ShopColors.secondaryText;

  static const Color lightMuted = ShopColors.muted;

  static const Color lightMutedSoft = ShopColors.faint;

  static const Color lightBorder = ShopColors.border;

  static const Color lightBorderStrong = ShopColors.borderStrong;

  static const Color lightDanger =
      Color(0xFFB42318);

  static const Color lightSuccess =
      Color(0xFF1B7A46);

  static const Color lightWarning =
      Color(0xFFC88418);

  // ============================================================
  // LIKHAE DARK PALETTE
  // ============================================================
  //
  // Same warm brown / maroon identity as the light theme.
  // The colors are lightened only where necessary for contrast.
  //
  // This avoids a generic blue/gray Material dark theme.
  // ============================================================

  static const Color darkBackground =
      Color(0xFF17110F);

  static const Color darkSurface =
      Color(0xFF211815);

  static const Color darkSurfaceSoft =
      Color(0xFF2A1E1A);

  static const Color darkSurfaceStrong =
      Color(0xFF34241F);

  static const Color darkMaroon =
      Color(0xFFC9877C);

  static const Color darkMaroonDark =
      Color(0xFF8E5048);

  static const Color darkMaroonSoft =
      Color(0xFFE0A89E);

  static const Color darkTan =
      Color(0xFFD2AA84);

  static const Color darkText =
      Color(0xFFF5ECE7);

  static const Color darkBrown =
      Color(0xFFD1B09D);

  static const Color darkMuted =
      Color(0xFFC0A89B);

  static const Color darkMutedSoft =
      Color(0xFF9D877C);

  static const Color darkBorder =
      Color(0xFF49362F);

  static const Color darkBorderStrong =
      Color(0xFF60463C);

  static const Color darkDanger =
      Color(0xFFFF7D73);

  static const Color darkSuccess =
      Color(0xFF6FD19A);

  static const Color darkWarning =
      Color(0xFFE6B55E);

  // ============================================================
  // LIGHT COLOR SCHEME
  // ============================================================

  static const ColorScheme lightColorScheme =
      ColorScheme.light(
    primary: lightMaroon,
    onPrimary: Colors.white,

    primaryContainer: lightSurfaceStrong,
    onPrimaryContainer: lightMaroonDark,

    secondary: lightTan,
    onSecondary: lightMaroonDark,

    secondaryContainer: lightSurfaceSoft,
    onSecondaryContainer: lightText,

    surface: lightSurface,
    onSurface: lightText,

    error: lightDanger,
    onError: Colors.white,

    outline: lightBorder,
    outlineVariant: lightBorderStrong,
  );

  // ============================================================
  // DARK COLOR SCHEME
  // ============================================================

  static const ColorScheme darkColorScheme =
      ColorScheme.dark(
    primary: darkMaroon,
    onPrimary: Color(0xFF27100D),

    primaryContainer: darkSurfaceStrong,
    onPrimaryContainer: darkText,

    secondary: darkTan,
    onSecondary: Color(0xFF261710),

    secondaryContainer: darkSurfaceSoft,
    onSecondaryContainer: darkText,

    surface: darkSurface,
    onSurface: darkText,

    error: darkDanger,
    onError: Color(0xFF2A0907),

    outline: darkBorder,
    outlineVariant: darkBorderStrong,
  );

  // ============================================================
  // LIGHT THEME
  // ============================================================

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,

      scaffoldBackgroundColor:
          lightBackground,

      colorScheme:
          lightColorScheme,

      canvasColor:
          lightBackground,

      splashColor:
          lightMaroon.withValues(
        alpha: 0.06,
      ),

      highlightColor:
          lightMaroon.withValues(
        alpha: 0.035,
      ),

      appBarTheme:
          const AppBarTheme(
        backgroundColor:
            lightBackground,
        foregroundColor:
            lightText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor:
            Colors.transparent,
        scrolledUnderElevation:
            0,
        iconTheme:
            IconThemeData(
          color:
              lightText,
        ),
        actionsIconTheme:
            IconThemeData(
          color:
              lightMaroon,
        ),
      ),

      iconTheme:
          const IconThemeData(
        color:
            lightText,
      ),

      inputDecorationTheme:
          _lightInputTheme(),

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              lightMaroon,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              lightMaroon.withValues(
            alpha: 0.40,
          ),
          disabledForegroundColor:
              Colors.white.withValues(
            alpha: 0.70,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      filledButtonTheme:
          FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
          elevation: 0,
          backgroundColor:
              lightMaroon,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              lightMaroon.withValues(
            alpha: 0.40,
          ),
          disabledForegroundColor:
              Colors.white.withValues(
            alpha: 0.70,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              lightMaroon,
          side:
              const BorderSide(
            color:
                lightTan,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme:
          TextButtonThemeData(
        style:
            TextButton.styleFrom(
          foregroundColor:
              lightMaroon,
        ),
      ),

      snackBarTheme:
          SnackBarThemeData(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            lightMaroonDark,
        contentTextStyle:
            const TextStyle(
          color:
              Colors.white,
          fontWeight:
              FontWeight.w500,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),

      dividerTheme:
          const DividerThemeData(
        color:
            lightBorder,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color:
            lightMaroon,
      ),

      checkboxTheme:
          CheckboxThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return lightMaroon;
            }

            return null;
          },
        ),
        checkColor:
            const WidgetStatePropertyAll<Color>(
          Colors.white,
        ),
      ),

      radioTheme:
          RadioThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return lightMaroon;
            }

            return lightMuted;
          },
        ),
      ),

      switchTheme:
          SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return Colors.white;
            }

            return lightMuted;
          },
        ),
        trackColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return lightMaroon;
            }

            return lightBorderStrong;
          },
        ),
      ),

      navigationBarTheme:
          const NavigationBarThemeData(
        backgroundColor:
            lightSurface,
        indicatorColor:
            lightSurfaceStrong,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
      ),

      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(
        backgroundColor:
            lightSurface,
        selectedItemColor:
            lightMaroon,
        unselectedItemColor:
            lightMuted,
        elevation: 0,
        type:
            BottomNavigationBarType.fixed,
      ),

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor:
            lightMaroon,
        foregroundColor:
            Colors.white,
        elevation: 2,
      ),

      textSelectionTheme:
          const TextSelectionThemeData(
        cursorColor:
            lightMaroon,
        selectionColor:
            Color(0xFFDCC1B5),
        selectionHandleColor:
            lightMaroon,
      ),

      dialogTheme:
          DialogThemeData(
        backgroundColor:
            lightSurface,
        surfaceTintColor:
            Colors.transparent,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
      ),

      bottomSheetTheme:
          const BottomSheetThemeData(
        backgroundColor:
            lightSurface,
        surfaceTintColor:
            Colors.transparent,
        modalBackgroundColor:
            lightSurface,
        showDragHandle: true,
        dragHandleColor:
            lightBorderStrong,
      ),

      navigationRailTheme:
          const NavigationRailThemeData(
        backgroundColor:
            lightSurface,
        selectedIconTheme:
            IconThemeData(
          color:
              lightMaroon,
        ),
        unselectedIconTheme:
            IconThemeData(
          color:
              lightMuted,
        ),
      ),
    );
  }

  // ============================================================
  // DARK THEME
  // ============================================================

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,

      scaffoldBackgroundColor:
          darkBackground,

      colorScheme:
          darkColorScheme,

      canvasColor:
          darkBackground,

      splashColor:
          darkMaroon.withValues(
        alpha: 0.10,
      ),

      highlightColor:
          darkMaroon.withValues(
        alpha: 0.06,
      ),

      appBarTheme:
          const AppBarTheme(
        backgroundColor:
            darkBackground,
        foregroundColor:
            darkText,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor:
            Colors.transparent,
        scrolledUnderElevation:
            0,
        iconTheme:
            IconThemeData(
          color:
              darkText,
        ),
        actionsIconTheme:
            IconThemeData(
          color:
              darkMaroon,
        ),
      ),

      iconTheme:
          const IconThemeData(
        color:
            darkText,
      ),

      inputDecorationTheme:
          _darkInputTheme(),

      elevatedButtonTheme:
          ElevatedButtonThemeData(
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              darkMaroon,
          foregroundColor:
              const Color(
            0xFF27100D,
          ),
          disabledBackgroundColor:
              darkMaroon.withValues(
            alpha: 0.32,
          ),
          disabledForegroundColor:
              darkText.withValues(
            alpha: 0.50,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      filledButtonTheme:
          FilledButtonThemeData(
        style:
            FilledButton.styleFrom(
          elevation: 0,
          backgroundColor:
              darkMaroon,
          foregroundColor:
              const Color(
            0xFF27100D,
          ),
          disabledBackgroundColor:
              darkMaroon.withValues(
            alpha: 0.32,
          ),
          disabledForegroundColor:
              darkText.withValues(
            alpha: 0.50,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      outlinedButtonTheme:
          OutlinedButtonThemeData(
        style:
            OutlinedButton.styleFrom(
          foregroundColor:
              darkTan,
          side:
              const BorderSide(
            color:
                darkBorderStrong,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 13,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),
          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      textButtonTheme:
          TextButtonThemeData(
        style:
            TextButton.styleFrom(
          foregroundColor:
              darkTan,
        ),
      ),

      snackBarTheme:
          SnackBarThemeData(
        behavior:
            SnackBarBehavior.floating,
        backgroundColor:
            darkSurfaceStrong,
        contentTextStyle:
            const TextStyle(
          color:
              darkText,
          fontWeight:
              FontWeight.w500,
        ),
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            14,
          ),
        ),
      ),

      dividerTheme:
          const DividerThemeData(
        color:
            darkBorder,
        thickness: 1,
        space: 1,
      ),

      progressIndicatorTheme:
          const ProgressIndicatorThemeData(
        color:
            darkMaroon,
      ),

      checkboxTheme:
          CheckboxThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return darkMaroon;
            }

            return null;
          },
        ),
        checkColor:
            const WidgetStatePropertyAll<Color>(
          Color(0xFF27100D),
        ),
      ),

      radioTheme:
          RadioThemeData(
        fillColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return darkMaroon;
            }

            return darkMuted;
          },
        ),
      ),

      switchTheme:
          SwitchThemeData(
        thumbColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return const Color(
                0xFF27100D,
              );
            }

            return darkMuted;
          },
        ),
        trackColor:
            WidgetStateProperty.resolveWith<Color?>(
          (
            Set<WidgetState> states,
          ) {
            if (states.contains(
              WidgetState.selected,
            )) {
              return darkMaroon;
            }

            return darkBorderStrong;
          },
        ),
      ),

      navigationBarTheme:
          const NavigationBarThemeData(
        backgroundColor:
            darkSurface,
        indicatorColor:
            darkSurfaceStrong,
        surfaceTintColor:
            Colors.transparent,
        elevation: 0,
      ),

      bottomNavigationBarTheme:
          const BottomNavigationBarThemeData(
        backgroundColor:
            darkSurface,
        selectedItemColor:
            darkMaroon,
        unselectedItemColor:
            darkMuted,
        elevation: 0,
        type:
            BottomNavigationBarType.fixed,
      ),

      floatingActionButtonTheme:
          const FloatingActionButtonThemeData(
        backgroundColor:
            darkMaroon,
        foregroundColor:
            Color(0xFF27100D),
        elevation: 2,
      ),

      textSelectionTheme:
          const TextSelectionThemeData(
        cursorColor:
            darkMaroon,
        selectionColor:
            Color(0xFF684239),
        selectionHandleColor:
            darkMaroon,
      ),

      dialogTheme:
          DialogThemeData(
        backgroundColor:
            darkSurface,
        surfaceTintColor:
            Colors.transparent,
        shape:
            RoundedRectangleBorder(
          borderRadius:
              BorderRadius.circular(
            20,
          ),
        ),
      ),

      bottomSheetTheme:
          const BottomSheetThemeData(
        backgroundColor:
            darkSurface,
        surfaceTintColor:
            Colors.transparent,
        modalBackgroundColor:
            darkSurface,
        showDragHandle: true,
        dragHandleColor:
            darkBorderStrong,
      ),

      navigationRailTheme:
          const NavigationRailThemeData(
        backgroundColor:
            darkSurface,
        selectedIconTheme:
            IconThemeData(
          color:
              darkMaroon,
        ),
        unselectedIconTheme:
            IconThemeData(
          color:
              darkMuted,
        ),
      ),
    );
  }

  // ============================================================
  // LIGHT INPUTS
  // ============================================================

  static InputDecorationTheme _lightInputTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor:
          lightSurface,

      hintStyle:
          const TextStyle(
        color:
            lightMuted,
        fontSize: 12,
      ),

      labelStyle:
          const TextStyle(
        color:
            lightText,
      ),

      floatingLabelStyle:
          const TextStyle(
        color:
            lightMaroon,
        fontWeight:
            FontWeight.w600,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              lightBorder,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              lightBorder,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              lightMaroon,
          width: 1.3,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              lightDanger,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              lightDanger,
          width: 1.3,
        ),
      ),

      errorStyle:
          const TextStyle(
        color:
            lightDanger,
        fontSize: 10,
      ),
    );
  }

  // ============================================================
  // DARK INPUTS
  // ============================================================

  static InputDecorationTheme _darkInputTheme() {
    return InputDecorationTheme(
      filled: true,
      fillColor:
          darkSurfaceSoft,

      hintStyle:
          const TextStyle(
        color:
            darkMutedSoft,
        fontSize: 12,
      ),

      labelStyle:
          const TextStyle(
        color:
            darkText,
      ),

      floatingLabelStyle:
          const TextStyle(
        color:
            darkMaroon,
        fontWeight:
            FontWeight.w600,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),

      border:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              darkBorder,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              darkBorder,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              darkMaroon,
          width: 1.3,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              darkDanger,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(16),
        borderSide:
            const BorderSide(
          color:
              darkDanger,
          width: 1.3,
        ),
      ),

      errorStyle:
          const TextStyle(
        color:
            darkDanger,
        fontSize: 10,
      ),
    );
  }

  // ============================================================
  // HELPER COLORS FOR CUSTOM SCREENS
  // ============================================================
  //
  // Use these when converting screens that still have hardcoded
  // light colors.
  // ============================================================

  static Color adaptive(Color lightColor) {
    if (!ThemeController.instance.usesDarkPalette) return lightColor;

    switch (lightColor.toARGB32()) {
      case 0xFFF6F4F1: return darkBackground;
      case 0xFFFFFEFC: return darkSurface;
      case 0xFFF0ECE8: return darkSurfaceSoft;
      case 0xFFF0E3E0: return darkSurfaceStrong;
      case 0xFF662A34: return darkMaroon;
      case 0xFF431D25: return darkMaroonDark;
      case 0xFF8C4651: return darkMaroonSoft;
      case 0xFFB29379: return darkTan;
      case 0xFF30272A: return darkText;
      case 0xFF68575C: return darkBrown;
      case 0xFF7B7071: return darkMuted;
      case 0xFF95878A: return darkMutedSoft;
      case 0xFFE7E1DD: return darkBorder;
      case 0xFFD4C7C1: return darkBorderStrong;
      case 0xFFFBF7F2:
        return darkBackground;
      case 0xFFFFFDF9:
        return darkSurface;
      case 0xFFF6EFE7:
        return darkSurfaceSoft;
      case 0xFFF1E4D7:
        return darkSurfaceStrong;
      case 0xFFEFE7DE:
        return darkSurfaceStrong;
      case 0xFFF3ECE4:
        return darkSurfaceSoft;
      case 0xFF561C17:
        return darkMaroon;
      case 0xFF3E130F:
        return darkMaroonDark;
      case 0xFF7A2A22:
        return darkMaroonSoft;
      case 0xFFC19771:
        return darkTan;
      case 0xFF3B211B:
        return darkText;
      case 0xFF6C4936:
        return darkBrown;
      case 0xFF987865:
        return darkMuted;
      case 0xFFA99386:
        return darkMutedSoft;
      case 0xFFEADCCC:
        return darkBorder;
      case 0xFFB42318:
        return darkDanger;
      case 0xFFC88418:
        return darkWarning;
      default:
        return lightColor;
    }
  }

  static bool isDark(
    BuildContext context,
  ) {
    return Theme.of(context).brightness ==
        Brightness.dark;
  }

  static Color background(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkBackground
        : lightBackground;
  }

  static Color surface(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkSurface
        : lightSurface;
  }

  static Color surfaceSoft(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkSurfaceSoft
        : lightSurfaceSoft;
  }

  static Color surfaceStrong(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkSurfaceStrong
        : lightSurfaceStrong;
  }

  static Color maroon(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkMaroon
        : lightMaroon;
  }

  static Color maroonDark(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkMaroonDark
        : lightMaroonDark;
  }

  static Color tan(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkTan
        : lightTan;
  }

  static Color text(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkText
        : lightText;
  }

  static Color muted(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkMuted
        : lightMuted;
  }

  static Color border(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkBorder
        : lightBorder;
  }

  static Color danger(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkDanger
        : lightDanger;
  }

  static Color success(
    BuildContext context,
  ) {
    return isDark(context)
        ? darkSuccess
        : lightSuccess;
  }
}

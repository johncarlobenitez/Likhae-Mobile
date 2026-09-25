import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // ============================================================
  // LIKHAE LIGHT PALETTE
  // ============================================================

  static const Color lightBackground =
      Color(0xFFFBF7F2);

  static const Color lightSurface =
      Color(0xFFFFFDF9);

  static const Color lightSurfaceSoft =
      Color(0xFFF6EFE7);

  static const Color lightSurfaceStrong =
      Color(0xFFF1E4D7);

  static const Color lightMaroon =
      Color(0xFF561C17);

  static const Color lightMaroonDark =
      Color(0xFF3E130F);

  static const Color lightMaroonSoft =
      Color(0xFF7A2A22);

  static const Color lightTan =
      Color(0xFFC19771);

  static const Color lightText =
      Color(0xFF3B211B);

  static const Color lightBrown =
      Color(0xFF6C4936);

  static const Color lightMuted =
      Color(0xFF987865);

  static const Color lightMutedSoft =
      Color(0xFFA99386);

  static const Color lightBorder =
      Color(0xFFEADCCC);

  static const Color lightBorderStrong =
      Color(0xFFD8C2AC);

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
      fontFamily: 'Poppins',

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
                BorderRadius.circular(
              12,
            ),
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
                BorderRadius.circular(
              12,
            ),
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
                BorderRadius.circular(
              12,
            ),
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
      fontFamily: 'Poppins',

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
                BorderRadius.circular(
              12,
            ),
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
                BorderRadius.circular(
              12,
            ),
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
                BorderRadius.circular(
              12,
            ),
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
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              lightBorder,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              lightBorder,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
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
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              lightDanger,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
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
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              darkBorder,
        ),
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              darkBorder,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
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
            BorderRadius.circular(
          12,
        ),
        borderSide:
            const BorderSide(
          color:
              darkDanger,
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          12,
        ),
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
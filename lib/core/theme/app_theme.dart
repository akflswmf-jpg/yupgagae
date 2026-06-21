import 'package:flutter/material.dart';

const Color kAppPrimary = Color(0xFFA56E5F);
const Color kAppPrimaryDark = Color(0xFF875646);
const Color kAppPrimarySoft = Color(0xFFF5ECE8);

const Color kAppBackground = Color(0xFFFFFFFF);
const Color kAppSurface = Color(0xFFFFFFFF);

const Color kAppTextPrimary = Color(0xFF111111);
const Color kAppTextSecondary = Color(0xFF6B7280);

const Color kAppBorder = Color(0xFFE5E7EB);
const Color kAppBorderLight = Color(0xFFF1F3F5);

const Color kAppError = Color(0xFFD92D20);

ThemeData buildAppTheme() {
  final colorScheme = const ColorScheme.light(
    primary: kAppPrimary,
    onPrimary: Colors.white,
    secondary: kAppPrimary,
    onSecondary: Colors.white,
    surface: kAppSurface,
    onSurface: kAppTextPrimary,
    error: kAppError,
    onError: Colors.white,
  );

  final textTheme = const TextTheme(
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w900,
      height: 1.25,
      color: kAppTextPrimary,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w900,
      height: 1.25,
      color: kAppTextPrimary,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w800,
      height: 1.25,
      color: kAppTextPrimary,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      height: 1.4,
      color: kAppTextPrimary,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      height: 1.45,
      color: kAppTextPrimary,
    ),
    bodySmall: TextStyle(
      fontSize: 12.5,
      fontWeight: FontWeight.w500,
      height: 1.4,
      color: kAppTextSecondary,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w800,
      height: 1.0,
      color: Colors.white,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: kAppTextPrimary,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: kAppBackground,
    canvasColor: kAppBackground,
    splashColor: Colors.black.withAlpha(8),
    highlightColor: Colors.black.withAlpha(4),
    dividerColor: kAppBorderLight,
    textTheme: textTheme,

    appBarTheme: const AppBarTheme(
      backgroundColor: kAppBackground,
      foregroundColor: kAppTextPrimary,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        color: kAppTextPrimary,
      ),
      iconTheme: IconThemeData(
        color: kAppTextPrimary,
        size: 22,
      ),
      actionsIconTheme: IconThemeData(
        color: kAppTextPrimary,
        size: 22,
      ),
    ),

    dividerTheme: const DividerThemeData(
      color: kAppBorderLight,
      thickness: 1,
      space: 1,
    ),

    cardTheme: CardThemeData(
      color: kAppSurface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(0),
        side: BorderSide.none,
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 14,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: kAppTextSecondary,
      ),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: kAppTextSecondary,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAppBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAppBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kAppPrimaryDark,
          width: 1.2,
        ),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: kAppBorder),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kAppError,
          width: 1.2,
        ),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: kAppError,
          width: 1.2,
        ),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        elevation: 0,
        backgroundColor: kAppPrimary,
        foregroundColor: Colors.white,
        disabledBackgroundColor: const Color(0xFFE5E7EB),
        disabledForegroundColor: const Color(0xFF9CA3AF),
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        elevation: 0,
        foregroundColor: kAppTextPrimary,
        minimumSize: const Size.fromHeight(48),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        side: const BorderSide(color: kAppBorder),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kAppPrimaryDark,
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: kAppPrimary,
      foregroundColor: Colors.white,
      elevation: 0,
      shape: CircleBorder(),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: kAppTextPrimary,
      unselectedItemColor: Color(0xFF9CA3AF),
      type: BottomNavigationBarType.fixed,
      elevation: 0,
      selectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
      ),
      unselectedLabelStyle: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
      ),
      showUnselectedLabels: true,
    ),

    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        return Colors.white;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) return kAppPrimaryDark;
        return const Color(0xFFD1D5DB);
      }),
      trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: kAppPrimaryDark,
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: kAppTextPrimary,
      contentTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

class AppSpace {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double xxl = 32;
}

class AppRadius {
  static const double sm = 10;
  static const double md = 12;
  static const double lg = 14;
  static const double xl = 16;
}

class AppShadow {
  static List<BoxShadow> card(BuildContext context) => const [];
  static List<BoxShadow> floating(BuildContext context) => const [];
}
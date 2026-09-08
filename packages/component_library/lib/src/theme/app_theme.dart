import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'app_colors_ext.dart';
import 'app_spacing_ext.dart';
import 'app_text_styles_ext.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF202624);
  static const muted = Color(0xFF626C68);
  static const primary = Color(0xFF0F766E);
  static const route = Color(0xFF8057D8);
  static const coral = Color(0xFFD64054);
  static const surface = Color(0xFFF4F6F5);
  static const border = Color(0xFFDFE5E2);
  static const success = primary;
  static const fontFamily = 'packages/forui/Inter';
  static const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  static const appColors = AppColorsExt(
    darkCyan: primary,
    appWhite: surface,
    simpleWhite: Colors.white,
    grayBlue: ink,
    darkPurple: route,
    lightPurple: route,
  );
  static const appSpacing = AppSpacingExt(
    xSmall: 4,
    small: 8,
    medium: 12,
    mediumLarge: 16,
    large: 20,
    xLarge: 24,
    xxLarge: 48,
    xxxLarge: 64,
  );
  static const appStyles = AppTextStylesExt(
    title1: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
  );

  static final forui = FThemeData(
    touch: true,
    colors: FColors.neutralLight.copyWith(
      foreground: ink,
      primary: primary,
      primaryForeground: Colors.white,
      secondary: surface,
      secondaryForeground: ink,
      muted: surface,
      mutedForeground: muted,
      border: border,
      destructive: coral,
      error: coral,
    ),
  );

  static Widget builder(BuildContext context, Widget? child) =>
      FTheme(data: forui, child: child!);

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(seedColor: primary).copyWith(
      primary: primary,
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: muted,
      outlineVariant: border,
      error: coral,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      titleSmall: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(fontSize: 16, letterSpacing: 0),
      bodyMedium: TextStyle(fontSize: 14, letterSpacing: 0),
      bodySmall: TextStyle(fontSize: 12, letterSpacing: 0),
      labelLarge: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(fontSize: 11, letterSpacing: 0),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        color: ink,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        borderSide: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: controlShape,
        textStyle: const TextStyle(
          fontFamily: fontFamily,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: controlShape,
      ),
    ),
    extensions: const [appColors, appStyles, appSpacing],
  );
}

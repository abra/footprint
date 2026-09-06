import 'package:flutter/material.dart';

import 'app_colors_ext.dart';
import 'app_spacing_ext.dart';
import 'app_text_styles_ext.dart';

abstract final class AppTheme {
  static const ink = Color(0xFF5D6A80);
  static const muted = Color(0xFF68758A);
  static const route = Color(0xFFA37BFF);
  static const coral = Color(0xFFE65D65);
  static const surface = Color(0xFFF5F7F9);
  static const border = Color(0xFFE8EDF1);
  static const success = Color(0xFF64CB54);

  static const appColors = AppColorsExt(
    darkCyan: Color(0xFF055C5C),
    appWhite: surface,
    simpleWhite: Colors.white,
    grayBlue: ink,
    darkPurple: Color(0xFF7850CF),
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
  static const appStyles = AppTextStylesExt(title1: TextStyle(fontSize: 24));

  static final light = ThemeData(
    useMaterial3: true,
    fontFamily: 'RobotoCondensed',
    package: 'component_library',
    colorScheme: ColorScheme.fromSeed(seedColor: route).copyWith(
      primary: const Color(0xFF7850CF),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: ink,
      onSurfaceVariant: muted,
      outlineVariant: border,
      error: const Color(0xFFBD3942),
    ),
    scaffoldBackgroundColor: Colors.white,
    appBarTheme: const AppBarTheme(
      centerTitle: true,
      backgroundColor: Colors.white,
      foregroundColor: ink,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        fontFamily: 'packages/component_library/RobotoCondensed',
        fontSize: 24,
        fontWeight: FontWeight.w500,
        color: ink,
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: surface,
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(16)),
        borderSide: BorderSide(color: border),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontFamily: 'packages/component_library/RobotoCondensed',
          fontSize: 22,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    extensions: const [appColors, appStyles, appSpacing],
  );
}

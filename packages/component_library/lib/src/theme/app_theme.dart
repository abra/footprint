import 'package:flutter/material.dart';

import 'app_colors_ext.dart';
import 'app_spacing_ext.dart';
import 'app_text_styles_ext.dart';

class AppTheme {
  static const appColors = AppColorsExt(
    darkCyan: Color(0xFF055C5C),
    appWhite: Color(0xFFE7E3E3),
    simpleWhite: Color(0xFFFFFFFF),
    grayBlue: Color(0xFF47556B),
    darkPurple: Color(0xFF6B36DC),
    lightPurple: Color(0xFF885EE1),
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

  // TODO: add app text styles
  static const appStyles = AppTextStylesExt(title1: TextStyle());

  // TODO: add app themes
  static final ThemeData light = ThemeData.light().copyWith(
    scaffoldBackgroundColor: appColors.appWhite,
    splashColor: Colors.transparent,
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      // hintStyle: appStyles.buttonText.copyWith(
      //   color: appColors.grey6,
      //   fontWeight: FontWeight.w600,
      // ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.zero,
    ),
    // textTheme: TextTheme(
    //   displayLarge: appStyles.title1.copyWith(
    //     color: appColors.white,
    //   ),
    //   displayMedium: appStyles.title2.copyWith(
    //     color: appColors.white,
    //   ),
    // ),
    // switchTheme: SwitchThemeData(
    //   thumbColor: WidgetStateProperty.all(
    //     appColors.blue,
    //   ),
    // ),
    // outlinedButtonTheme: OutlinedButtonThemeData(
    //   // remove border
    //   style: ButtonStyle(
    //     textStyle: WidgetStateProperty.all(appStyles.buttonText),
    //     backgroundColor: WidgetStateProperty.all(appColors.blue),
    //     foregroundColor: WidgetStateProperty.all(appColors.white),
    //     side: WidgetStateProperty.all(
    //       BorderSide.none,
    //     ),
    //     shape: WidgetStateProperty.all(
    //       const RoundedRectangleBorder(
    //         borderRadius: BorderRadius.all(
    //           Radius.circular(4),
    //         ),
    //       ),
    //     ),
    //   ),
    // ),
    // bottomSheetTheme: BottomSheetThemeData(
    //   surfaceTintColor: Colors.transparent,
    //   backgroundColor: appColors.grey2,
    //   modalBackgroundColor: appColors.grey2,
    //   shape: const RoundedRectangleBorder(
    //     borderRadius: BorderRadius.vertical(
    //       top: Radius.circular(16),
    //     ),
    //   ),
    // ),
    // bottomNavigationBarTheme: BottomNavigationBarThemeData(
    //   type: BottomNavigationBarType.fixed,
    //   elevation: 0,
    //   backgroundColor: appColors.black,
    //   selectedItemColor: appColors.blue,
    //   unselectedItemColor: appColors.grey6,
    //   selectedLabelStyle: appStyles.tabText.copyWith(
    //     color: appColors.blue,
    //   ),
    //   unselectedLabelStyle: appStyles.tabText.copyWith(
    //     color: appColors.grey6,
    //   ),
    // ),
    extensions: [
      appColors,
      appStyles,
      appSpacing,
    ],
  );
}

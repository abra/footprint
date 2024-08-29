import 'package:flutter/material.dart';

class AppColorsExt extends ThemeExtension<AppColorsExt> {
  const AppColorsExt({
    required this.darkCyan,
    required this.appWhite,
    required this.simpleWhite,
    required this.grayBlue,
    required this.darkPurple,
    required this.lightPurple,
  });

  final Color darkCyan;
  final Color appWhite;
  final Color simpleWhite;
  final Color grayBlue;
  final Color darkPurple;
  final Color lightPurple;

  @override
  ThemeExtension<AppColorsExt> copyWith({
    Color? darkCyan,
    Color? appWhite,
    Color? simpleWhite,
    Color? grayBlue,
    Color? darkPurple,
    Color? lightPurple,
  }) =>
      AppColorsExt(
        darkCyan: darkCyan ?? this.darkCyan,
        appWhite: appWhite ?? this.appWhite,
        simpleWhite: simpleWhite ?? this.simpleWhite,
        grayBlue: grayBlue ?? this.grayBlue,
        darkPurple: darkPurple ?? this.darkPurple,
        lightPurple: lightPurple ?? this.lightPurple,
      );

  @override
  ThemeExtension<AppColorsExt> lerp(
      ThemeExtension<AppColorsExt>? other, double t) {
    if (other is! AppColorsExt) {
      return this;
    }
    return AppColorsExt(
      darkCyan: Color.lerp(darkCyan, other.darkCyan, t)!,
      appWhite: Color.lerp(appWhite, other.appWhite, t)!,
      simpleWhite: Color.lerp(simpleWhite, other.simpleWhite, t)!,
      grayBlue: Color.lerp(grayBlue, other.grayBlue, t)!,
      darkPurple: Color.lerp(darkPurple, other.darkPurple, t)!,
      lightPurple: Color.lerp(lightPurple, other.lightPurple, t)!,
    );
  }
}

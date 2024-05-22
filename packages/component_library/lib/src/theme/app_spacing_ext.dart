// abstract class AppSpacing {
//   static const double xSmall = 4;
//   static const double small = 8;
//   static const double medium = 12;
//   static const double mediumLarge = 16;
//   static const double large = 20;
//   static const double xLarge = 24;
//   static const double xxLarge = 48;
//   static const double xxxLarge = 64;
// }
import 'dart:ui';

import 'package:flutter/material.dart';

class AppSpacingExt extends ThemeExtension<AppSpacingExt> {
  const AppSpacingExt({
    required this.xSmall,
    required this.small,
    required this.medium,
    required this.mediumLarge,
    required this.large,
    required this.xLarge,
    required this.xxLarge,
    required this.xxxLarge,
  });

  final double xSmall;
  final double small;
  final double medium;
  final double mediumLarge;
  final double large;
  final double xLarge;
  final double xxLarge;
  final double xxxLarge;

  @override
  ThemeExtension<AppSpacingExt> copyWith({
    double? xSmall,
    double? small,
    double? medium,
    double? mediumLarge,
    double? large,
    double? xLarge,
    double? xxLarge,
    double? xxxLarge,
  }) =>
      AppSpacingExt(
        xSmall: xSmall ?? this.xSmall,
        small: small ?? this.small,
        medium: medium ?? this.medium,
        mediumLarge: mediumLarge ?? this.mediumLarge,
        large: large ?? this.large,
        xLarge: xLarge ?? this.xLarge,
        xxLarge: xxLarge ?? this.xxLarge,
        xxxLarge: xxxLarge ?? this.xxxLarge,
      );

  @override
  ThemeExtension<AppSpacingExt> lerp(
      ThemeExtension<AppSpacingExt>? other, double t) {
    if (other is! AppSpacingExt) {
      return this;
    }
    return AppSpacingExt(
      xSmall: lerpDouble(xSmall, other.xSmall, t)!,
      small: lerpDouble(small, other.small, t)!,
      medium: lerpDouble(medium, other.medium, t)!,
      mediumLarge: lerpDouble(mediumLarge, other.mediumLarge, t)!,
      large: lerpDouble(large, other.large, t)!,
      xLarge: lerpDouble(xLarge, other.xLarge, t)!,
      xxLarge: lerpDouble(xxLarge, other.xxLarge, t)!,
      xxxLarge: lerpDouble(xxxLarge, other.xxxLarge, t)!,
    );
  }
}

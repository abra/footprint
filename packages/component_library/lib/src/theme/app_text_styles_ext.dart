import 'package:flutter/material.dart';

class AppTextStylesExt extends ThemeExtension<AppTextStylesExt> {
  const AppTextStylesExt({
    required this.title1,
  });

  final TextStyle title1;

  @override
  ThemeExtension<AppTextStylesExt> copyWith({
    TextStyle? title1,
  }) {
    return AppTextStylesExt(
      title1: title1 ?? this.title1,
    );
  }

  @override
  ThemeExtension<AppTextStylesExt> lerp(
    ThemeExtension<AppTextStylesExt>? other,
    double t,
  ) {
    if (other is! AppTextStylesExt) {
      return this;
    }
    return AppTextStylesExt(
      title1: TextStyle.lerp(title1, other.title1, t)!,
    );
  }

}

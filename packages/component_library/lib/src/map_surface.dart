import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class MapSurface extends StatelessWidget {
  const MapSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const ShapeDecoration(
      shape: AppTheme.controlShape,
      shadows: [
        BoxShadow(
          color: Color(0x1A000000),
          blurRadius: 16,
          offset: Offset(0, 4),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      shape: AppTheme.controlShape,
      clipBehavior: Clip.antiAlias,
      child: child,
    ),
  );
}

import 'package:flutter/material.dart';

class MapSurface extends StatelessWidget {
  const MapSurface({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white.withValues(alpha: 0.96),
    elevation: 4,
    shadowColor: Colors.black.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(16),
    clipBehavior: Clip.antiAlias,
    child: child,
  );
}

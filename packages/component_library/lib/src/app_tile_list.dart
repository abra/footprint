import 'package:flutter/widgets.dart';

import 'theme/app_theme.dart';

/// Separates individually outlined tiles without adding an outer surface.
class AppTileList extends StatelessWidget {
  const AppTileList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    spacing: AppTheme.appSpacing.small,
    children: children,
  );
}

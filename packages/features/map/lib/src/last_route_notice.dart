import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class LastRouteNotice extends StatelessWidget {
  const LastRouteNotice({super.key, required this.onHide});

  final VoidCallback onHide;

  @override
  Widget build(BuildContext context) => MapSurface(
    child: Padding(
      padding: const EdgeInsets.only(left: 12, right: 4),
      child: Row(
        children: [
          const Icon(FLucideIcons.route, size: 18, color: AppTheme.muted),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Last route',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 8),
          AppIconButton(
            tooltip: 'Hide last route',
            icon: const Icon(FLucideIcons.x),
            onPressed: onHide,
          ),
        ],
      ),
    ),
  );
}

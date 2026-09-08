import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import 'explore_state.dart';

class PlanPreview extends StatelessWidget {
  const PlanPreview({super.key, required this.state});

  final ExploreState state;

  @override
  Widget build(BuildContext context) {
    final plan = state.plan!;
    final distance = state.distanceToStart;
    final startMessage = state.locating
        ? 'Checking your location...'
        : distance == null
        ? 'Location will be checked before starting.'
        : state.startTooFar
        ? '${_distance(distance)} to start\nMove within 100 m'
        : 'Start nearby';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (distance == null || state.startTooFar || state.locating) ...[
          Semantics(
            liveRegion: state.locating,
            child: Text(
              startMessage,
              style: TextStyle(
                color: state.startTooFar ? null : AppTheme.muted,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${(plan.distance / 1000).toStringAsFixed(2)} km',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Text('About ${plan.estimatedDuration.inMinutes} min'),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '${plan.checkpoints.length} ${plan.checkpoints.length == 1 ? 'checkpoint' : 'checkpoints'}, up to ${state.newAreas} new areas',
        ),
      ],
    );
  }

  static String _distance(double meters) => meters >= 1000
      ? '${(meters / 1000).toStringAsFixed(1)} km'
      : '${meters.ceil()} m';
}

class PlanPreviewTools extends StatelessWidget {
  const PlanPreviewTools({
    super.key,
    required this.state,
    required this.onEdit,
    required this.onClear,
    required this.onUndo,
    required this.onRefreshLocation,
  });

  final ExploreState state;
  final VoidCallback onEdit;
  final VoidCallback onClear;
  final VoidCallback onUndo;
  final VoidCallback onRefreshLocation;

  @override
  Widget build(BuildContext context) {
    final busy = state.starting || state.recording;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 8,
      children: [
        AppIconButton(
          tooltip: 'Edit route',
          icon: const Icon(FLucideIcons.slidersHorizontal),
          onPressed: busy ? null : onEdit,
        ),
        AppIconButton(
          tooltip: 'Clear route',
          icon: const Icon(FLucideIcons.x),
          onPressed: busy ? null : onClear,
        ),
        AppIconButton(
          tooltip: 'Restore previous route',
          icon: const Icon(FLucideIcons.undo2),
          onPressed: busy || state.previousPreview == null ? null : onUndo,
        ),
        AppIconButton(
          tooltip: 'Refresh start location',
          icon: const Icon(FLucideIcons.locateFixed),
          onPressed: busy || state.locating || state.generating
              ? null
              : onRefreshLocation,
        ),
      ],
    );
  }
}

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'distance_sheet.dart';
import 'explore_cubit.dart';
import 'explore_state.dart';

enum RouteEndpoint { start, end }

String pointLabel(GeoPoint point) =>
    '${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}';

class PlanningSettings extends StatelessWidget {
  const PlanningSettings({
    super.key,
    required this.state,
    required this.onPick,
    required this.onCancelPick,
    this.picking,
  });
  final ExploreState state;
  final ValueChanged<RouteEndpoint> onPick;
  final VoidCallback onCancelPick;
  final RouteEndpoint? picking;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExploreCubit>();
    final disabled = state.starting || state.recording;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<RoutePlanMode>(
          segments: const [
            ButtonSegment(
              value: RoutePlanMode.loop,
              icon: Icon(Icons.loop),
              label: Text('Loop'),
            ),
            ButtonSegment(
              value: RoutePlanMode.pointToPoint,
              icon: Icon(Icons.route),
              label: Text('A to B'),
            ),
          ],
          selected: {state.mode},
          showSelectedIcon: false,
          onSelectionChanged: disabled
              ? null
              : (modes) {
                  onCancelPick();
                  cubit.selectMode(modes.single);
                },
        ),
        const SizedBox(height: 12),
        if (state.mode == RoutePlanMode.loop)
          Row(
            children: [
              const Icon(Icons.directions_walk, color: explorationColor),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${(state.distance / 1000).toStringAsFixed(state.distance % 1000 == 0 ? 0 : 1)} km loop',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Change distance',
                onPressed: disabled
                    ? null
                    : () async {
                        final distance = await showDistanceSheet(
                          context,
                          state.distance,
                        );
                        if (context.mounted && distance != null) {
                          cubit.selectDistance(distance);
                        }
                      },
                icon: const Icon(Icons.tune),
              ),
              if (state.plan != null)
                IconButton(
                  tooltip: 'Clear route',
                  onPressed: disabled ? null : cubit.clearPlan,
                  icon: const Icon(Icons.close),
                ),
            ],
          ),
        if (state.mode == RoutePlanMode.pointToPoint)
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _EndpointTile(
                      label: 'Start',
                      letter: 'A',
                      value: state.start == null
                          ? 'Current location'
                          : pointLabel(state.start!),
                      selected: picking == RouteEndpoint.start,
                      onTap: disabled
                          ? null
                          : () => onPick(RouteEndpoint.start),
                    ),
                    _EndpointTile(
                      label: 'Destination',
                      letter: 'B',
                      value: state.end == null
                          ? 'Choose on map'
                          : pointLabel(state.end!),
                      selected: picking == RouteEndpoint.end,
                      onTap: disabled ? null : () => onPick(RouteEndpoint.end),
                    ),
                  ],
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Use current location for start',
                    onPressed: disabled || state.start == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.selectStart(null);
                          },
                    icon: const Icon(Icons.my_location),
                  ),
                  IconButton(
                    tooltip: 'Swap start and destination',
                    onPressed:
                        disabled || state.start == null || state.end == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.swapEndpoints();
                          },
                    icon: const Icon(Icons.swap_vert),
                  ),
                  IconButton(
                    tooltip: 'Clear route',
                    onPressed: disabled || state.plan == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.clearPlan();
                          },
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ],
          ),
      ],
    );
  }
}

class _EndpointTile extends StatelessWidget {
  const _EndpointTile({
    required this.label,
    required this.letter,
    required this.value,
    required this.selected,
    this.onTap,
  });
  final String label;
  final String letter;
  final String value;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    dense: true,
    selected: selected,
    selectedColor: letter == 'A' ? explorationColor : AppTheme.coral,
    selectedTileColor: (letter == 'A' ? explorationColor : AppTheme.coral)
        .withValues(alpha: 0.08),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
      side: BorderSide(
        color: selected
            ? letter == 'A'
                  ? explorationColor
                  : AppTheme.coral
            : Colors.transparent,
      ),
    ),
    leading: CircleAvatar(
      radius: 16,
      backgroundColor: letter == 'A' ? explorationColor : AppTheme.coral,
      child: Text(
        letter,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(color: Colors.white),
      ),
    ),
    title: Text(label),
    subtitle: Text(value),
    onTap: onTap,
    enabled: onTap != null,
  );
}

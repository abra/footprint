import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'distance_sheet.dart';
import 'explore_cubit.dart';
import 'explore_state.dart';
import 'loop_distance_picker.dart';

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
    final showEndpoints = state.mode == RoutePlanMode.pointToPoint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSegmentedControl<RoutePlanMode>(
          segments: const [
            AppSegment(
              value: RoutePlanMode.loop,
              icon: FLucideIcons.repeat,
              label: 'Loop',
            ),
            AppSegment(
              value: RoutePlanMode.pointToPoint,
              icon: FLucideIcons.route,
              label: 'A to B',
            ),
          ],
          value: state.mode,
          onChanged: disabled
              ? null
              : (mode) {
                  onCancelPick();
                  cubit.selectMode(mode);
                },
        ),
        const SizedBox(height: 12),
        // Only the endpoint form determines the shared settings height.
        AnimatedCrossFade(
          key: ValueKey(MediaQuery.disableAnimationsOf(context)),
          duration: AppMotion.durationOf(context),
          firstCurve: AppMotion.fadeOut,
          secondCurve: AppMotion.fadeIn,
          crossFadeState: showEndpoints
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          layoutBuilder: (top, topKey, bottom, bottomKey) => Stack(
            children: [
              KeyedSubtree(
                key: showEndpoints ? topKey : bottomKey,
                child: showEndpoints ? top : bottom,
              ),
              Positioned.fill(
                key: showEndpoints ? bottomKey : topKey,
                child: showEndpoints ? bottom : top,
              ),
            ],
          ),
          secondChild: Row(
            key: const ValueKey('route-endpoint-settings'),
            children: [
              Expanded(
                child: AppTileList(
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
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppIconButton(
                    tooltip: 'Use current location for start',
                    onPressed: disabled || state.start == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.selectStart(null);
                          },
                    icon: const Icon(FLucideIcons.locateFixed),
                  ),
                  AppIconButton(
                    tooltip: 'Swap start and destination',
                    onPressed:
                        disabled || state.start == null || state.end == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.swapEndpoints();
                          },
                    icon: const Icon(FLucideIcons.arrowDownUp),
                  ),
                  AppIconButton(
                    tooltip: 'Clear route',
                    onPressed: disabled || state.plan == null
                        ? null
                        : () {
                            onCancelPick();
                            cubit.clearPlan();
                          },
                    icon: const Icon(FLucideIcons.x),
                  ),
                ],
              ),
            ],
          ),
          firstChild: LoopDistancePicker(
            distance: state.distance,
            onSelected: disabled ? null : cubit.selectDistance,
            onCustomRequested: disabled
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
            hasPlan: state.plan != null,
            onClear: disabled ? null : cubit.clearPlan,
          ),
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
  Widget build(BuildContext context) => FTile(
    selected: selected,
    style: .delta(
      padding: .value(EdgeInsets.zero),
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
    ),
    prefix: MediaQuery.textScalerOf(context).scale(1) > 1.4
        ? null
        : CircleAvatar(
            radius: 16,
            backgroundColor: letter == 'A' ? explorationColor : AppTheme.coral,
            child: Text(
              letter,
              textScaler: TextScaler.noScaling,
              style: const TextStyle(color: Colors.white),
            ),
          ),
    title: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (MediaQuery.textScalerOf(context).scale(1) > 1.4)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: RouteEndpointBadge(letter: letter),
          ),
        Text(
          label,
          overflow: TextOverflow.visible,
          style: const TextStyle(fontSize: 14),
        ),
      ],
    ),
    subtitle: Text(
      value,
      overflow: TextOverflow.visible,
      style: const TextStyle(fontSize: 12),
    ),
    onPress: onTap,
    enabled: onTap != null,
  );
}

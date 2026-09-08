import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

class LoopDistancePicker extends StatelessWidget {
  const LoopDistancePicker({
    super.key,
    required this.distance,
    required this.onSelected,
    required this.onCustomRequested,
    this.onClear,
    this.hasPlan = false,
  });

  static const _presets = [1000.0, 3000.0, 5000.0, 10000.0];
  final double distance;
  final ValueChanged<double>? onSelected;
  final VoidCallback? onCustomRequested;
  final VoidCallback? onClear;
  final bool hasPlan;

  @override
  Widget build(BuildContext context) {
    final custom = !_presets.contains(distance);
    final kilometers = distance / 1000;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 8,
            children: [
              for (var row = 0; row < 2; row++)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: 8,
                    children: [
                      for (final meters in _presets.skip(row * 2).take(2))
                        Expanded(
                          child: Semantics(
                            selected: distance == meters,
                            inMutuallyExclusiveGroup: true,
                            child: FButton(
                              key: ValueKey('loop-distance-${meters.toInt()}'),
                              selected: distance == meters,
                              variant: distance == meters
                                  ? FButtonVariant.primary
                                  : FButtonVariant.outline,
                              onPress: onSelected == null
                                  ? null
                                  : () {
                                      if (distance != meters) {
                                        onSelected!(meters);
                                      }
                                    },
                              style: .delta(
                                tappableStyle: const .delta(
                                  motion: FTappableMotion.none,
                                ),
                                contentStyle: .delta(
                                  constraints: const BoxConstraints(
                                    minHeight: 48,
                                  ),
                                  padding: const .value(EdgeInsets.all(8)),
                                ),
                              ),
                              child: Flexible(
                                child: Text(
                                  '${(meters / 1000).toInt()} km',
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              if (custom)
                Text(
                  'Custom: ${distance % 1000 == 0 ? kilometers.toInt() : kilometers} km',
                  style: const TextStyle(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIconButton(
              tooltip: 'Change distance',
              selected: custom,
              onPressed: onCustomRequested,
              icon: const Icon(FLucideIcons.slidersHorizontal),
            ),
            if (hasPlan)
              AppIconButton(
                tooltip: 'Clear route',
                onPressed: onClear,
                icon: const Icon(FLucideIcons.x),
              ),
          ],
        ),
      ],
    );
  }
}

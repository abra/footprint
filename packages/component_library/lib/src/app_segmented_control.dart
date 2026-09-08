import 'package:flutter/widgets.dart';
import 'package:forui/forui.dart';

class AppSegment<T> {
  const AppSegment({required this.value, required this.label, this.icon});
  final T value;
  final String label;
  final IconData? icon;
}

class AppSegmentedControl<T> extends StatelessWidget {
  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
  });
  final List<AppSegment<T>> segments;
  final T value;
  final ValueChanged<T>? onChanged;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: context.theme.colors.secondary,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          for (final segment in segments)
            Expanded(
              child: Semantics(
                selected: segment.value == value,
                inMutuallyExclusiveGroup: true,
                child: FButton(
                  variant: segment.value == value
                      ? FButtonVariant.outline
                      : FButtonVariant.ghost,
                  selected: segment.value == value,
                  onPress: onChanged == null
                      ? null
                      : () => onChanged!(segment.value),
                  style: const .delta(
                    tappableStyle: .delta(motion: FTappableMotion.none),
                    contentStyle: .delta(
                      constraints: BoxConstraints(minHeight: 44),
                      padding: .value(
                        EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      ),
                    ),
                  ),
                  prefix: segment.icon == null
                      ? null
                      : Icon(segment.icon, size: 16, applyTextScaling: false),
                  child: Flexible(
                    child: Text(segment.label, textAlign: TextAlign.center),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

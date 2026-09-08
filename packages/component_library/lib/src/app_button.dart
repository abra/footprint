import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

/// Shared touch sizing and wrapping for commands built on Forui.
class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.onPressed,
    required this.label,
    this.prefix,
    this.variant = FButtonVariant.primary,
    this.compact = false,
    this.foreground,
    this.preserveDisabledAppearance = false,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget? prefix;
  final FButtonVariant variant;
  final bool compact;
  final Color? foreground;
  final bool preserveDisabledAppearance;

  @override
  Widget build(BuildContext context) {
    final base = context.theme.buttonStyles
        .resolve({variant, context.platformVariant})
        .resolve({FButtonSizeVariant.md, context.platformVariant});
    final style = base.copyWith(
      tappableStyle: const .delta(motion: FTappableMotion.none),
      contentStyle: const .delta(
        constraints: BoxConstraints(minHeight: 48),
        padding: .value(EdgeInsets.symmetric(horizontal: 16, vertical: 12)),
      ),
      decoration: preserveDisabledAppearance
          ? FVariants.all(base.decoration.resolve({}))
          : null,
    );
    return FButton(
      onPress: onPressed,
      variant: variant,
      style: style,
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      prefix: prefix == null
          ? null
          : IconTheme.merge(
              data: const IconThemeData(size: 20, applyTextScaling: false),
              child: prefix!,
            ),
      child: Flexible(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(color: foreground),
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.selected = false,
    this.square = false,
  });

  final String tooltip;
  final Widget icon;
  final VoidCallback? onPressed;
  final bool selected;
  final bool square;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    excludeFromSemantics: true,
    // One accessible node keeps tooltip/field clipping consistent during navigation.
    child: Semantics(
      button: true,
      enabled: onPressed != null,
      selected: selected,
      label: tooltip,
      onTap: onPressed,
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: 48,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(square ? 0 : 8),
          child: FButton.icon(
            onPress: onPressed,
            variant: FButtonVariant.ghost,
            selected: selected,
            semanticsLabel: tooltip,
            style: .delta(
              decoration: .delta([
                .all(
                  .shapeDelta(
                    shape: square
                        ? const RoundedRectangleBorder()
                        : const RoundedRectangleBorder(
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                  ),
                ),
              ]),
              tappableStyle: const .delta(motion: FTappableMotion.none),
              iconContentStyle: const .delta(
                constraints: BoxConstraints.tightFor(width: 48, height: 48),
                padding: .value(EdgeInsets.zero),
              ),
            ),
            child: IconTheme.merge(
              data: const IconThemeData(size: 22, applyTextScaling: false),
              child: icon,
            ),
          ),
        ),
      ),
    ),
  );
}

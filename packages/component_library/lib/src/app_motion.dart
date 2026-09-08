import 'package:flutter/widgets.dart';

abstract final class AppMotion {
  static const duration = Duration(milliseconds: 180);
  static const fadeOut = Interval(0, 0.5, curve: Curves.easeInOut);
  static const fadeIn = Interval(0.5, 1, curve: Curves.easeInOut);

  static Duration durationOf(BuildContext context) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}

/// Fades between intentional view changes, keeping only the new view interactive.
class AppFadeSwitcher extends StatelessWidget {
  const AppFadeSwitcher({super.key, required this.value, required this.child});

  final Object value;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
    // Discard an in-flight transition when reduced motion changes.
    key: ValueKey(MediaQuery.disableAnimationsOf(context)),
    duration: AppMotion.durationOf(context),
    switchInCurve: AppMotion.fadeIn,
    // The outgoing controller runs in reverse: disappear in the first half.
    switchOutCurve: AppMotion.fadeIn,
    transitionBuilder: (child, animation) => FadeTransition(
      opacity: animation,
      alwaysIncludeSemantics: true,
      child: child,
    ),
    layoutBuilder: (current, previous) => ClipRect(
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          for (final child in previous)
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: ExcludeSemantics(
                  child: ExcludeFocus(
                    child: TickerMode(enabled: false, child: child),
                  ),
                ),
              ),
            ),
          ?current,
        ],
      ),
    ),
    child: KeyedSubtree(key: ValueKey(value), child: child),
  );
}

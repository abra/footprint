import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';

class CenterLocationIcon extends StatefulWidget {
  const CenterLocationIcon({super.key, required this.centered});

  final bool centered;

  @override
  State<CenterLocationIcon> createState() => _CenterLocationIconState();
}

class _CenterLocationIconState extends State<CenterLocationIcon>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
    value: widget.centered ? 1 : 0,
  );
  late final _progress = _controller.drive(
    CurveTween(curve: Curves.easeInOutCubic),
  );
  late final _outlineOpacity = ReverseAnimation(_progress);
  // Align both glyphs throughout the diagonal-to-upright transition.
  late final _outlineTurns = _progress.drive(Tween(begin: 0.0, end: -0.125));
  late final _filledTurns = _progress.drive(Tween(begin: 0.125, end: 0.0));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncAnimation();
  }

  @override
  void didUpdateWidget(CenterLocationIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.centered != oldWidget.centered) _syncAnimation();
  }

  void _syncAnimation() {
    final target = widget.centered ? 1.0 : 0.0;
    if (MediaQuery.disableAnimationsOf(context) ||
        !TickerMode.valuesOf(context).enabled) {
      _controller.value = target;
    } else {
      _controller.animateTo(target);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: 28,
      child: ExcludeSemantics(
        child: Stack(
          alignment: Alignment.center,
          children: [
            FadeTransition(
              opacity: _outlineOpacity,
              child: RotationTransition(
                turns: _outlineTurns,
                child: const Icon(
                  Icons.near_me_outlined,
                  color: AppTheme.ink,
                  size: 28,
                  applyTextScaling: false,
                ),
              ),
            ),
            FadeTransition(
              opacity: _progress,
              child: RotationTransition(
                turns: _filledTurns,
                child: const Icon(
                  Icons.navigation,
                  color: AppTheme.route,
                  size: 28,
                  applyTextScaling: false,
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

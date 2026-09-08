import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// A finite, shortest-arc turn shared by the location arrow and following camera.
class HeadingMotion extends ChangeNotifier
    with WidgetsBindingObserver
    implements ValueListenable<double?> {
  HeadingMotion({required TickerProvider vsync, required this._heading})
    : _controller = AnimationController(
        vsync: vsync,
        duration: const Duration(milliseconds: 240),
        value: 1,
      ) {
    turns = _controller
        .drive(CurveTween(curve: Curves.easeInOutCubic))
        .drive(_tween);
    _controller.addListener(notifyListeners);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
    _heading.addListener(_update);
    _update();
  }

  final ValueListenable<double?> _heading;
  final AnimationController _controller;
  final _tween = Tween<double>(begin: 0, end: 0);
  late final Animation<double> turns;
  double? _target;
  bool _enabled = false;
  bool _foreground = true;

  @override
  double? get value => _target == null ? null : turns.value * 360;

  set enabled(bool value) {
    _enabled = value;
    _settleIfHidden();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _settleIfHidden();
  }

  void _settleIfHidden() {
    if ((!_enabled || !_foreground) &&
        (_controller.isAnimating || _controller.value != 1)) {
      _controller.value = 1;
    }
  }

  void _update() {
    final raw = _heading.value;
    final next = raw != null && raw.isFinite ? (raw % 360) / 360 : null;
    final previous = _target;
    if (next == previous) return;
    final current = turns.value;
    final delta = next == null ? 0.0 : (next - current + 0.5) % 1 - 0.5;
    if (previous != null &&
        next != null &&
        !_controller.isAnimating &&
        delta.abs() < 2 / 360) {
      return;
    }
    _target = next;
    _controller.stop();
    if (previous == null || next == null) {
      _tween.begin = _tween.end = next ?? 0;
      _controller.value = 1;
    } else {
      _tween
        ..begin = current
        ..end = current + delta;
      if (_enabled && _foreground) {
        _controller.forward(from: 0);
      } else {
        _controller.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _heading.removeListener(_update);
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }
}

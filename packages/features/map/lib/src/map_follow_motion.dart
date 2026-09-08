import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Camera-only animation. Recording and Cubit state never receive frame updates.
class MapFollowMotion with WidgetsBindingObserver {
  MapFollowMotion({
    required TickerProvider vsync,
    required this.controller,
    required this.position,
    required this.heading,
    required this.defaultZoom,
  }) : _transition = AnimationController(
         vsync: vsync,
         duration: const Duration(milliseconds: 240),
         value: 1,
       ) {
    _offset = _transition
        .drive(CurveTween(curve: Curves.easeInOutCubic))
        .drive(_tween);
    _transition.addListener(_follow);
    position.addListener(_follow);
    heading.addListener(_headingChanged);
    WidgetsBinding.instance.addObserver(this);
    final lifecycle = WidgetsBinding.instance.lifecycleState;
    _foreground = lifecycle == null || lifecycle == AppLifecycleState.resumed;
  }

  final MapController controller;
  final ValueListenable<LatLng?> position;
  final ValueListenable<double?> heading;
  final double defaultZoom;
  final AnimationController _transition;
  final _tween = Tween<double>(begin: 0, end: 0);
  late final Animation<double> _offset;
  bool _ready = false;
  bool _following = false;
  bool _courseUp = false;
  bool _courseKnown = false;
  bool _hasLocation = false;
  bool _enabled = false;
  bool _foreground = true;
  double _heldRotation = 0;

  set enabled(bool value) {
    _enabled = value;
    _settleIfHidden();
  }

  void attach({required bool following, required bool courseUp}) {
    _ready = true;
    update(following: following, courseUp: courseUp);
  }

  void update({required bool following, required bool courseUp}) {
    final changed = following != _following || courseUp != _courseUp;
    _following = following;
    _courseUp = courseUp;
    if (!_ready) return;
    if (!_following) {
      _transition.stop();
    } else if (changed) {
      _courseKnown = heading.value != null;
      _heldRotation = controller.camera.rotation;
      _retarget();
    } else {
      _follow();
    }
  }

  double get _targetRotation =>
      _courseUp ? -(heading.value ?? -_heldRotation) : 0;

  void _headingChanged() {
    final known = heading.value != null;
    final acquired = known && !_courseKnown;
    _courseKnown = known;
    if (!_ready || !_following || !_courseUp) return;
    if (!known) {
      _heldRotation = controller.camera.rotation;
      _transition.stop();
      _tween.begin = _tween.end = 0;
      _transition.value = 1;
    } else if (acquired) {
      _retarget();
    } else {
      _follow();
    }
  }

  void _retarget() {
    _transition.stop();
    // Animate only the offset to the live course. Both map and arrow then
    // consume exactly the same smoothed heading throughout subsequent turns.
    _tween
      ..begin = (controller.camera.rotation - _targetRotation + 180) % 360 - 180
      ..end = 0;
    if (_enabled && _foreground && _tween.begin!.abs() > 0.01) {
      _transition.forward(from: 0);
    } else {
      _transition.value = 1;
    }
  }

  void _follow() {
    final point = position.value;
    if (!_ready || !_following || point == null) return;
    controller.moveAndRotate(
      point,
      _hasLocation ? controller.camera.zoom : defaultZoom,
      _targetRotation + _offset.value,
    );
    _hasLocation = true;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _settleIfHidden();
  }

  void _settleIfHidden() {
    if ((!_enabled || !_foreground) &&
        (_transition.isAnimating || _transition.value != 1)) {
      _transition.value = 1;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    position.removeListener(_follow);
    heading.removeListener(_headingChanged);
    _transition.dispose();
  }
}

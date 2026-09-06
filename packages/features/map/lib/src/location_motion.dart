import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';

/// Presentation coordinates only; recorded GPS samples are never interpolated.
class LocationMotion extends ValueNotifier<LatLng?> {
  LocationMotion({
    required TickerProvider vsync,
    Duration duration = const Duration(milliseconds: 700),
    this.maxAnimatedDistance = 500,
  }) : _controller = AnimationController(vsync: vsync, duration: duration),
       super(null) {
    _controller.addListener(_tick);
  }

  static const _distance = DistanceHaversine(roundResult: false);
  final AnimationController _controller;
  final double maxAnimatedDistance;
  LatLng? _from;
  LatLng? _target;
  double _meters = 0;
  double _bearing = 0;

  void moveTo(LatLng target, {bool animate = true}) {
    if (animate && target == _target) return;
    final from = value;
    _controller.stop();
    _target = target;
    if (from == null || !animate || from == target) {
      value = target;
      return;
    }
    _meters = _distance(from, target);
    if (_meters > maxAnimatedDistance) {
      value = target;
      return;
    }
    _from = from;
    _bearing = _distance.bearing(from, target);
    _controller.forward(from: 0);
  }

  void _tick() {
    if (_controller.value == 0) {
      value = _from;
      return;
    }
    if (_controller.value == 1) {
      value = _target;
      return;
    }
    final point = _distance.offset(
      _from!,
      _meters * Curves.easeOutCubic.transform(_controller.value),
      _bearing,
    );
    value = LatLng(point.latitude, (point.longitude + 180) % 360 - 180);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

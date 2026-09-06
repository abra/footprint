import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:latlong2/latlong.dart';

/// Presentation coordinates only; recorded GPS samples are never interpolated.
class LocationMotion extends ValueNotifier<LatLng?> {
  LocationMotion({
    required TickerProvider vsync,
    this.maxAnimatedDistance = 500,
  }) : super(null) {
    _ticker = vsync.createTicker(_tick);
  }

  static const _distance = DistanceHaversine(roundResult: false);
  static const _minimumDelay = Duration(milliseconds: 1200);
  static const _maximumDelay = Duration(seconds: 4);
  static const _bufferMargin = Duration(milliseconds: 200);
  static const _resetGap = Duration(seconds: 10);
  static const _maxSamples = 32;

  late final Ticker _ticker;
  final double maxAnimatedDistance;
  final _samples = Queue<_LocationSample>();
  Duration _delay = _minimumDelay;
  Duration? _playhead;
  Duration _lastTick = Duration.zero;
  Duration _lastArrival = Duration.zero;
  _LocationSample? _segmentEnd;
  double _meters = 0;
  double _bearing = 0;

  /// GPS time corresponding to [value], clamped to known samples.
  DateTime? get displayedAt {
    if (_samples.isEmpty) return null;
    final playhead = _playhead;
    if (playhead == null || playhead >= _samples.last.time) {
      return _samples.last.timestamp;
    }
    if (playhead <= _samples.first.time) return _samples.first.timestamp;
    return DateTime.fromMicrosecondsSinceEpoch(
      playhead.inMicroseconds,
      isUtc: true,
    );
  }

  void moveTo(
    LatLng target, {
    required DateTime timestamp,
    bool animate = true,
  }) {
    if (!target.latitude.isFinite ||
        !target.longitude.isFinite ||
        !target.isValid) {
      return;
    }
    final previous = _samples.lastOrNull;
    if (previous != null &&
        (timestamp.isBefore(previous.timestamp) ||
            (animate && timestamp == previous.timestamp))) {
      return;
    }
    final sample = _LocationSample(target, timestamp);
    if (previous == null ||
        !animate ||
        timestamp.difference(previous.timestamp) >= _resetGap ||
        _distance(previous.point, target) > maxAnimatedDistance ||
        _samples.length >= _maxSamples ||
        (_samples.length == 1 && previous.point == target) ||
        (_playhead != null && sample.time - _playhead! > _maximumDelay * 2)) {
      _reset(sample);
      return;
    }

    final interval = timestamp.difference(previous.timestamp);
    // Keep a little headroom for jitter. Grow promptly, shrink gradually.
    final wanted = (interval + _bufferMargin).inMicroseconds.clamp(
      _minimumDelay.inMicroseconds,
      _maximumDelay.inMicroseconds,
    );
    _delay = Duration(
      microseconds: wanted >= _delay.inMicroseconds
          ? wanted
          : (_delay.inMicroseconds * 0.8 + wanted * 0.2).round(),
    );
    _samples.add(sample);
    _lastArrival = _lastTick;
    if (!_ticker.isActive) {
      _playhead = sample.time - _delay;
      _lastTick = Duration.zero;
      _lastArrival = Duration.zero;
      _ticker.start();
    }
  }

  void _tick(Duration elapsed) {
    final frameDuration = elapsed - _lastTick;
    _lastTick = elapsed;
    // Adjust buffering through playback speed, never by rewinding the marker.
    final expected = _playhead! + frameDuration;
    final desired = _samples.last.time + elapsed - _lastArrival - _delay;
    final error = (desired - expected).inMicroseconds;
    final rate = (1 + error / _delay.inMicroseconds).clamp(0.5, 1.25);
    final playhead =
        _playhead! +
        Duration(microseconds: (frameDuration.inMicroseconds * rate).round());
    _playhead = playhead;

    final previousSample = _samples.first;
    while (_samples.length > 1 && _samples.elementAt(1).time <= playhead) {
      _samples.removeFirst();
    }
    final from = _samples.first;
    if (_samples.length == 1) {
      _ticker.stop();
      _playhead = null;
      _segmentEnd = null;
      _publish(from.point, timelineChanged: from != previousSample);
      return;
    }
    final to = _samples.elementAt(1);
    final span = (to.time - from.time).inMicroseconds;
    final fraction = span <= 0
        ? 1.0
        : ((playhead - from.time).inMicroseconds / span).clamp(0.0, 1.0);
    if (fraction == 0) {
      _publish(from.point, timelineChanged: from != previousSample);
      return;
    }
    if (_segmentEnd != to) {
      _segmentEnd = to;
      _meters = _distance(from.point, to.point);
      _bearing = _distance.bearing(from.point, to.point);
    }
    // Follow every buffered leg, including turns, without easing at each fix.
    final point = _distance.offset(from.point, _meters * fraction, _bearing);
    _publish(
      LatLng(point.latitude, (point.longitude + 180) % 360 - 180),
      timelineChanged: from != previousSample,
    );
  }

  void _publish(LatLng point, {required bool timelineChanged}) {
    if (value == point) {
      // A completed loop can advance the route without moving the marker.
      if (timelineChanged) notifyListeners();
    } else {
      value = point;
    }
  }

  void _reset(_LocationSample sample) {
    final hadPendingSamples = _samples.length > 1;
    _ticker.stop();
    _samples
      ..clear()
      ..add(sample);
    _delay = _minimumDelay;
    _playhead = null;
    _lastTick = Duration.zero;
    _lastArrival = Duration.zero;
    _segmentEnd = null;
    _publish(sample.point, timelineChanged: hadPendingSamples);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}

class _LocationSample {
  _LocationSample(this.point, this.timestamp)
    : time = Duration(microseconds: timestamp.microsecondsSinceEpoch);

  final LatLng point;
  final DateTime timestamp;
  final Duration time;
}

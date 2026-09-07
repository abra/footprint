import 'dart:async';
import 'dart:math' as math;

import 'package:domain_models/domain_models.dart';
import 'package:latlong2/latlong.dart';

/// Stabilizes GPS fixes before either native recording path persists them.
/// Work and retained state are constant per fix, independent of route length.
class LocationFilter {
  LocationFilter({LocationDM? initialLocation}) {
    if (initialLocation != null && initialLocation.hasValidCoordinates) {
      _anchor = initialLocation;
      _lastObserved = initialLocation.timestamp;
      _lastMovement = initialLocation.timestamp;
      _stationary = initialLocation.isStationary;
      _speed = initialLocation.filteredSpeed ?? 0;
      _moving = !_stationary && _speed > _minimumMovingSpeed;
    }
  }

  static const _distance = DistanceHaversine(roundResult: false);
  static const _maximumAccuracy = 35.0;
  static const _minimumRadius = 3.0;
  static const _departureRadiusMultiplier = 1.5;
  static const _minimumSensorMovement = 1.0;
  static const _minimumMovingSpeed = 0.35;
  static const _maximumSpeed = 100.0;
  static const _stopDelay = Duration(seconds: 8);
  static const _confirmationWindow = Duration(minutes: 1);

  LocationDM? _anchor;
  LocationDM? _candidate;
  DateTime? _lastObserved;
  DateTime? _lastMovement;
  bool _moving = false;
  bool _stationary = false;
  double _speed = 0;

  Stream<LocationDM> bind(Stream<LocationDM> locations) => locations.transform(
    StreamTransformer.fromHandlers(
      handleData: (point, sink) {
        final filtered = add(point);
        if (filtered != null) sink.add(filtered);
      },
    ),
  );

  LocationDM? add(LocationDM point) {
    if (!point.hasValidCoordinates ||
        (_lastObserved != null && !point.timestamp.isAfter(_lastObserved!))) {
      return null;
    }
    final accuracy = point.accuracy;
    if (accuracy != null &&
        (!accuracy.isFinite || accuracy <= 0 || accuracy > _maximumAccuracy)) {
      _candidate = null;
      return null;
    }
    if (_lastObserved != null &&
        point.timestamp.difference(_lastObserved!) >= _stopDelay) {
      _moving = false;
    }
    _lastObserved = point.timestamp;

    // Legacy/imported samples have no uncertainty estimate. Do not invent one
    // or silently reinterpret their geometry as a confirmed stop.
    if (accuracy == null) {
      _anchor = point;
      _candidate = null;
      _lastMovement = point.timestamp;
      _moving = false;
      _stationary = point.isStationary;
      return point;
    }

    final sensorSpeed = point.reliableSpeed;
    final sensorMoving =
        sensorSpeed != null &&
        sensorSpeed - point.speedAccuracy! > _minimumMovingSpeed;
    final anchor = _anchor;
    if (anchor == null) return _accept(point, moving: sensorMoving);

    final meters = _meters(anchor, point);
    final radius = math.max(
      _minimumRadius,
      math.max(anchor.accuracy ?? accuracy, accuracy),
    );
    final elapsed =
        point.timestamp.difference(anchor.timestamp).inMicroseconds /
        Duration.microsecondsPerSecond;
    if (meters > _maximumSpeed * elapsed + radius * 2) {
      _candidate = null;
      return _hold(point);
    }

    final departureRadius = _stationary
        ? radius * _departureRadiusMultiplier
        : radius;
    if (meters <= departureRadius &&
        !(sensorMoving && meters >= _minimumSensorMovement)) {
      _candidate = null;
      return _hold(point);
    }

    // Reliable sensor motion can preserve short walking steps. Departures and
    // unexplained jumps still need a second fix on the same side of the anchor.
    final expected = sensorSpeed == null
        ? 0.0
        : (sensorSpeed + point.speedAccuracy!) * elapsed + radius * 2;
    if (_moving && sensorMoving && meters <= expected) {
      return _accept(point, moving: true);
    }
    final candidate = _candidate;
    if (candidate != null &&
        point.timestamp.difference(candidate.timestamp) <=
            _confirmationWindow) {
      final before = _meters(anchor, candidate);
      final between = _meters(candidate, point);
      final aligned =
          (before * before + meters * meters - between * between) /
          (2 * before * meters);
      if (aligned > 0.5 && meters >= before * 0.8) {
        return _accept(point, moving: true);
      }
    }
    _candidate = point;
    return _hold(point);
  }

  LocationDM _accept(LocationDM point, {required bool moving}) {
    final anchor = _anchor;
    final seconds = anchor == null
        ? 0.0
        : point.timestamp.difference(anchor.timestamp).inMicroseconds /
              Duration.microsecondsPerSecond;
    // Use the accepted anchor's time, not the last held fix's time: otherwise
    // releasing several buffered meters creates a fictitious speed spike.
    final geometricSpeed = seconds <= 0
        ? 0.0
        : _meters(anchor!, point) / seconds;
    final sensorSpeed = point.reliableSpeed;
    _speed = sensorSpeed != null && sensorSpeed <= _maximumSpeed
        ? sensorSpeed
        : geometricSpeed;
    final result = point.withFilteredPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      isStationary: false,
      filteredSpeed: _speed,
    );
    _anchor = result;
    _candidate = null;
    _lastMovement = point.timestamp;
    _moving = moving;
    _stationary = false;
    return result;
  }

  LocationDM _hold(LocationDM point) {
    if (point.timestamp.difference(_lastMovement!) >= _stopDelay) {
      _stationary = true;
      _moving = false;
    }
    return point.withFilteredPosition(
      latitude: _anchor!.latitude,
      longitude: _anchor!.longitude,
      isStationary: _stationary,
      filteredSpeed: _stationary ? 0 : _speed,
    );
  }

  static double _meters(LocationDM a, LocationDM b) => _distance(
    LatLng(a.latitude, a.longitude),
    LatLng(b.latitude, b.longitude),
  );
}

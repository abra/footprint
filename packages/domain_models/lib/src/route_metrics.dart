import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'location_dm.dart';

/// A measured segment speed in meters per second at elapsed recording time.
class RouteSpeedSample extends Equatable {
  const RouteSpeedSample({required this.elapsed, required this.speed});

  final Duration elapsed;
  final double speed;

  @override
  List<Object?> get props => [elapsed, speed];
}

/// GPS estimates in meters, seconds, and meters per second.
class RouteMetrics extends Equatable {
  const RouteMetrics({
    this.distance = 0,
    this.duration = Duration.zero,
    this.currentSpeed = 0,
    this.maxSpeed = 0,
    this.speedHistory = const [],
  });

  factory RouteMetrics.fromLocations(
    Iterable<LocationDM> points, {
    DateTime? startedAt,
    DateTime? endedAt,
  }) {
    const calculator = Distance(roundResult: false);
    LocationDM? previous;
    DateTime? first;
    var distance = 0.0;
    var speed = 0.0;
    var maximum = 0.0;
    final speeds = <RouteSpeedSample>[];
    for (final point in points) {
      if (!point.hasValidCoordinates) continue;
      final before = previous;
      if (before != null) {
        final seconds =
            point.timestamp.difference(before.timestamp).inMicroseconds /
            Duration.microsecondsPerSecond;
        if (seconds <= 0) continue;
        final segment = calculator(
          LatLng(before.latitude, before.longitude),
          LatLng(point.latitude, point.longitude),
        );
        distance += segment;
        speed = point.isStationary
            ? 0
            : point.filteredSpeed ?? point.reliableSpeed ?? segment / seconds;
        maximum = math.max(maximum, speed);
        speeds.add(
          RouteSpeedSample(
            elapsed: point.timestamp.difference(first!),
            speed: speed,
          ),
        );
      }
      first ??= point.timestamp;
      previous = point;
    }
    final start = startedAt ?? first;
    final end = endedAt ?? previous?.timestamp;
    return RouteMetrics(
      distance: distance,
      duration: start == null || end == null || end.isBefore(start)
          ? Duration.zero
          : end.difference(start),
      currentSpeed: speed,
      maxSpeed: maximum,
      speedHistory: List.unmodifiable(speeds),
    );
  }

  final double distance;
  final Duration duration;
  final double currentSpeed;
  final double maxSpeed;
  final List<RouteSpeedSample> speedHistory;

  double get averageSpeed => duration.inMicroseconds <= 0
      ? 0
      : distance / (duration.inMicroseconds / Duration.microsecondsPerSecond);

  RouteMetrics atTime({
    required DateTime start,
    required DateTime lastSample,
    required DateTime now,
  }) => RouteMetrics(
    distance: distance,
    duration: now.isBefore(start) ? Duration.zero : now.difference(start),
    currentSpeed: now.difference(lastSample) > const Duration(seconds: 10)
        ? 0
        : currentSpeed,
    maxSpeed: maxSpeed,
    speedHistory: speedHistory,
  );

  @override
  List<Object?> get props => [
    distance,
    duration,
    currentSpeed,
    maxSpeed,
    speedHistory,
  ];
}

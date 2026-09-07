import 'package:domain_models/domain_models.dart';
import 'package:test/test.dart';

final start = DateTime.utc(2026, 9, 6, 10);
LocationDM point(double longitude, int seconds) => LocationDM(
  id: '$seconds',
  latitude: 0,
  longitude: longitude,
  timestamp: start.add(Duration(seconds: seconds)),
);

void main() {
  LocationDM measured(
    int second,
    double longitude, {
    double? speed = 0.8,
    double? speedAccuracy = 0.1,
    bool stationary = false,
  }) => LocationDM(
    id: '$second',
    latitude: 0,
    longitude: longitude,
    timestamp: start.add(Duration(seconds: second)),
    speed: speed,
    speedAccuracy: speedAccuracy,
    isStationary: stationary,
  );

  test(
    'reliable sensor speed takes precedence over quantized GPS segments',
    () {
      final metrics = RouteMetrics.fromLocations([
        measured(0, 0),
        measured(1, 0.00002),
        measured(2, 0.00002),
      ]);
      expect(metrics.currentSpeed, 0.8);
      expect(metrics.maxSpeed, 0.8);
      expect(metrics.distance, closeTo(2.23, 0.01));
    },
  );

  test(
    'confirmed stops override reported speed without stopping elapsed time',
    () {
      final metrics = RouteMetrics.fromLocations([
        measured(0, 0),
        measured(10, 0.0001),
        measured(600, 0.0001, stationary: true),
      ]);
      expect(metrics.currentSpeed, 0);
      expect(metrics.maxSpeed, 0.8);
      expect(metrics.duration, const Duration(minutes: 10));
      expect(metrics.averageSpeed, closeTo(11.13 / 600, 0.001));
    },
  );

  test('unavailable or invalid sensor speed falls back to geometry', () {
    for (final (speed, uncertainty) in <(double?, double?)>[
      (null, null),
      (1, null),
      (-1, 0.1),
      (double.nan, 0.1),
      (double.infinity, 0.1),
      (1, -1),
      (1, double.nan),
      (1, 2),
    ]) {
      final metrics = RouteMetrics.fromLocations([
        measured(0, 0),
        measured(10, 0.0001, speed: speed, speedAccuracy: uncertainty),
      ]);
      expect(metrics.currentSpeed, closeTo(1.113, 0.001));
    }
  });
  test('empty and single-point tracks have finite zero metrics', () {
    expect(RouteMetrics.fromLocations([]), const RouteMetrics());
    final metrics = RouteMetrics.fromLocations([point(0, 0)]);
    expect(metrics.distance, 0);
    expect(metrics.averageSpeed, 0);
    expect(metrics.maxSpeed, 0);
  });
  test('distance and speeds use original coordinates and elapsed time', () {
    final metrics = RouteMetrics.fromLocations([
      point(0, 0),
      point(0.001, 10),
      point(0.002, 30),
    ], endedAt: start.add(const Duration(minutes: 1)));
    expect(metrics.distance, closeTo(222.64, 1));
    expect(metrics.duration, const Duration(minutes: 1));
    expect(metrics.currentSpeed, closeTo(5.566, 0.1));
    expect(metrics.maxSpeed, closeTo(11.132, 0.1));
    expect(metrics.averageSpeed, closeTo(222.64 / 60, 0.1));
    expect(metrics.speedHistory.map((sample) => sample.elapsed), [
      const Duration(seconds: 10),
      const Duration(seconds: 30),
    ]);
    expect(metrics.speedHistory.first.speed, closeTo(11.132, 0.1));
    expect(metrics.speedHistory.last.speed, metrics.currentSpeed);
    expect(() => metrics.speedHistory.clear(), throwsUnsupportedError);
  });
  test('invalid coordinates and non-increasing timestamps are ignored', () {
    final normal = RouteMetrics.fromLocations([point(0, 0), point(0.001, 10)]);
    final dirty = RouteMetrics.fromLocations([
      point(0, 0),
      point(100, 0),
      point(50, -1),
      point(double.nan, 5),
      point(181, 6),
      point(0.001, 10),
    ]);
    expect(dirty, normal);
  });
  test('date-line crossing uses the short geodesic', () {
    final metrics = RouteMetrics.fromLocations([
      point(179.999, 0),
      point(-179.999, 60),
    ]);
    expect(metrics.distance, closeTo(222.64, 1));
  });
  test('stationary time grows duration and clears stale current speed', () {
    final trace = RouteMetrics.fromLocations([point(0, 0), point(0.001, 10)]);
    final live = trace.atTime(
      start: start,
      lastSample: point(0, 10).timestamp,
      now: start.add(const Duration(seconds: 30)),
    );
    expect(live.distance, trace.distance);
    expect(live.duration, const Duration(seconds: 30));
    expect(live.currentSpeed, 0);
    expect(live.maxSpeed, trace.maxSpeed);
    expect(live.speedHistory, same(trace.speedHistory));
  });
  test('speed history is empty until a segment is measured', () {
    expect(RouteMetrics.fromLocations([]).speedHistory, isEmpty);
    expect(RouteMetrics.fromLocations([point(0, 0)]).speedHistory, isEmpty);
  });
  test('stationary segments produce finite zero speed samples', () {
    final metrics = RouteMetrics.fromLocations([point(0, 0), point(0, 10)]);
    expect(metrics.speedHistory, [
      const RouteSpeedSample(elapsed: Duration(seconds: 10), speed: 0),
    ]);
  });
  test('clock rollback never creates negative duration or speed', () {
    final metrics = RouteMetrics.fromLocations([
      point(0, 0),
    ], endedAt: start.subtract(const Duration(seconds: 1)));
    expect(metrics.duration, Duration.zero);
    expect(metrics.averageSpeed, 0);
  });
}

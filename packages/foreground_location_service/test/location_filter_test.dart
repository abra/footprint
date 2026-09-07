import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';

import 'gps_fixtures.dart';

void main() {
  test(
    'ten minutes of meter-sized jitter add no distance or marker motion',
    () {
      final filter = LocationFilter();
      final points = [filter.add(fix(0, 0))!];
      for (var second = 1; second <= 600; second++) {
        points.add(
          filter.add(
            fix(
              second,
              second.isEven ? 1 : -1,
              north: second % 3 - 1,
              speed: 0,
              speedAccuracy: 0.2,
            ),
          )!,
        );
      }
      expect(points.every((p) => p.latitude == 0 && p.longitude == 0), isTrue);
      expect(points[7].isStationary, isFalse);
      expect(points[8].isStationary, isTrue);
      expect(points.last.isStationary, isTrue);
      expect(points.last.rawLongitude, closeTo(1 / 111195, 1e-12));
      expect(points.last.timestamp, gpsEpoch.add(const Duration(minutes: 10)));
      final metrics = RouteMetrics.fromLocations(points);
      expect(metrics.distance, 0);
      expect(metrics.currentSpeed, 0);
      expect(metrics.maxSpeed, 0);
      expect(metrics.duration, const Duration(minutes: 10));
    },
  );

  test('one excursion and alternating directions do not confirm departure', () {
    final filter = LocationFilter()..add(fix(0, 0));
    for (final point in [fix(10, 12), fix(11, 0), fix(12, -12), fix(13, 12)]) {
      expect(filter.add(point)!.longitude, 0);
    }
    expect(filter.add(fix(14, 1))!.isStationary, isTrue);
  });

  test('slow walking accumulates displacement from the anchor, not each fix', () {
    final filter = LocationFilter();
    final points = <LocationDM>[];
    for (var second = 0; second <= 120; second++) {
      points.add(filter.add(fix(second, second * 0.25))!);
    }
    final metrics = RouteMetrics.fromLocations(points);
    // The unconfirmed tail stays within the 7.5 m departure radius plus a fix.
    expect(metrics.distance, inInclusiveRange(22, 31));
    expect(metrics.maxSpeed, lessThan(0.3));
    expect(points.last.longitude, greaterThan(22 / 111195));
    expect(
      points.map((p) => p.longitude).toList(),
      orderedEquals(points.map((p) => p.longitude).toList()..sort()),
    );
  });

  test(
    'reliable sensor speed preserves short steps after a confirmed start',
    () {
      final filter = LocationFilter()..add(fix(0, 0));
      filter.add(fix(10, 1));
      final points = <LocationDM>[];
      for (var second = 11; second <= 30; second++) {
        points.add(
          filter.add(
            fix(second, (second - 10) * 0.6, speed: 0.6, speedAccuracy: 0.1),
          )!,
        );
      }
      expect(points[2].longitude, greaterThan(0));
      expect(points.last.longitude, closeTo(12 / 111195, 1 / 111195));
      expect(points.last.isStationary, isFalse);
      expect(
        RouteMetrics.fromLocations(points).currentSpeed,
        closeTo(0.6, 1e-9),
      );
    },
  );

  test('uncertain speed does not turn jitter into short walking steps', () {
    final filter = LocationFilter()..add(fix(0, 0));
    for (var second = 1; second <= 30; second++) {
      final result = filter.add(
        fix(second, second.isEven ? 2 : -2, speed: 1, speedAccuracy: 3),
      )!;
      expect(result.longitude, 0);
    }
  });

  test('distance-filtered slow updates can still confirm movement', () {
    final filter = LocationFilter();
    final points = [
      for (var second = 0; second <= 240; second += 20)
        filter.add(fix(second, second * 0.25))!,
    ];
    final metrics = RouteMetrics.fromLocations(points);
    expect(metrics.distance, greaterThan(49));
    expect(metrics.maxSpeed, lessThan(0.3));
  });

  test('a confirmed stop uses a wider departure radius', () {
    final filter = LocationFilter()..add(fix(0, 0));
    expect(filter.add(fix(10, 1))!.isStationary, isTrue);
    expect(filter.add(fix(11, 6))!.longitude, 0);
    expect(filter.add(fix(12, 6.5))!.longitude, 0);
    expect(filter.add(fix(13, 8))!.longitude, 0);
    expect(filter.add(fix(14, 9))!.longitude, greaterThan(0));
  });

  test('normal walking, a stop and a restart preserve a continuous route', () {
    final filter = LocationFilter();
    final points = [filter.add(fix(0, 0, speed: 1, speedAccuracy: 0.1))!];
    for (var second = 1; second <= 20; second++) {
      points.add(
        filter.add(
          fix(second, second.toDouble(), speed: 1, speedAccuracy: 0.1),
        )!,
      );
    }
    final stoppedAt = points.last.longitude;
    for (var second = 21; second <= 620; second++) {
      points.add(filter.add(fix(second, 20 + (second.isEven ? 1 : -1)))!);
      expect(points.last.longitude, stoppedAt);
    }
    expect(points.last.isStationary, isTrue);
    for (var second = 621; second <= 640; second++) {
      points.add(
        filter.add(
          fix(second, (second - 600).toDouble(), speed: 1, speedAccuracy: 0.1),
        )!,
      );
    }
    final metrics = RouteMetrics.fromLocations(points);
    expect(metrics.distance, closeTo(40, 1));
    expect(metrics.duration, const Duration(seconds: 640));
    expect(metrics.averageSpeed, closeTo(40 / 640, 0.01));
  });

  test('isolated GPS teleport cannot inflate distance or maximum speed', () {
    final filter = LocationFilter();
    final points = [filter.add(fix(0, 0, speed: 1, speedAccuracy: 0.1))!];
    points.add(filter.add(fix(1, 1, speed: 1, speedAccuracy: 0.1))!);
    points.add(filter.add(fix(2, 1000))!);
    expect(points.last.longitude, points[1].longitude);
    points.add(filter.add(fix(3, 3, speed: 1, speedAccuracy: 0.1))!);
    final metrics = RouteMetrics.fromLocations(points);
    expect(metrics.distance, lessThan(4));
    expect(metrics.maxSpeed, lessThanOrEqualTo(1));
  });

  test(
    'fresh coherent fixes recover after signal loss without a permanent lock',
    () {
      final filter = LocationFilter()..add(fix(0, 0));
      expect(filter.add(fix(60, 50, accuracy: 100)), isNull);
      expect(filter.add(fix(120, 100))!.longitude, 0);
      expect(
        filter.add(fix(121, 101))!.longitude,
        closeTo(101 / 111195, 1e-12),
      );
    },
  );

  test('normal vehicle speed is not classified as a walking-only outlier', () {
    final filter = LocationFilter();
    final points = [
      for (var second = 0; second <= 10; second++)
        filter.add(
          fix(second, second * 33.3, speed: 33.3, speedAccuracy: 0.3),
        )!,
    ];
    expect(RouteMetrics.fromLocations(points).distance, closeTo(333, 1));
    expect(points.last.isStationary, isFalse);
  });

  test(
    'poor accuracy and stale or invalid fixes do not replace the anchor',
    () {
      final filter = LocationFilter();
      expect(filter.add(fix(0, 30, accuracy: 100)), isNull);
      filter.add(fix(1, 0));
      for (final accuracy in [0.0, -1.0, double.nan, double.infinity, 36.0]) {
        expect(filter.add(fix(2, 100, accuracy: accuracy)), isNull);
      }
      expect(filter.add(fix(0, 100)), isNull);
      expect(filter.add(fix(1, 100)), isNull);
      expect(filter.add(fix(2, double.nan)), isNull);
      expect(filter.add(fix(3, 1))!.longitude, 0);
    },
  );

  test('unknown accuracy remains unknown and legacy geometry is unchanged', () {
    final filter = LocationFilter();
    for (var second = 0; second <= 3; second++) {
      final point = fix(second, second.toDouble(), accuracy: null);
      expect(filter.add(point), same(point));
    }
  });

  test(
    'restored stationary anchor survives a new stream and can leave again',
    () {
      final previous = fix(
        600,
        1,
      ).withFilteredPosition(latitude: 0, longitude: 0, isStationary: true);
      final filter = LocationFilter(initialLocation: previous);
      expect(filter.add(fix(600, 1)), isNull);
      expect(filter.add(fix(601, -1))!.longitude, 0);
      expect(filter.add(fix(602, 10))!.longitude, 0);
      final moving = filter.add(fix(603, 11))!;
      expect(moving.isStationary, isFalse);
      expect(moving.longitude, closeTo(11 / 111195, 1e-12));
    },
  );

  test('expired confirmation never joins unrelated excursions', () {
    final filter = LocationFilter()..add(fix(0, 0));
    expect(filter.add(fix(1, 10))!.longitude, 0);
    expect(filter.add(fix(90, 11))!.longitude, 0);
    expect(filter.add(fix(91, 12))!.longitude, greaterThan(0));
  });

  test(
    'stream adapter forwards errors and cancellation to the producer',
    () async {
      var cancelled = false;
      final stream = StreamController<LocationDM>(
        onCancel: () => cancelled = true,
      );
      final output = <LocationDM>[];
      final errors = <Object>[];
      final subscription = LocationFilter()
          .bind(stream.stream)
          .listen(output.add, onError: errors.add);
      stream.add(fix(0, 0));
      stream.addError(StateError('GPS unavailable'));
      stream.add(fix(1, 1));
      await Future<void>.delayed(Duration.zero);
      expect(output, hasLength(2));
      expect(errors.single, isA<StateError>());
      await subscription.cancel();
      expect(cancelled, isTrue);
      await stream.close();
    },
  );
}

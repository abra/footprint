import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:test/test.dart';

import 'walk_fixtures.dart';

void main() {
  test(
    'plan round-trips independently from recordings with ordered checkpoints',
    () {
      final plan = loopPlan();
      expect(RoutePlan.fromMap(jsonDecode(jsonEncode(plan.toMap()))), plan);
      expect(plan.distance, closeTo(1200, 1));
      expect(plan.checkpoints, hasLength(3));
      expect(
        plan.checkpoints.last.point.distanceTo(plan.points.first),
        lessThan(1),
      );
      expect(
        plan.checkpoints.first.point.distanceTo(plan.points.first),
        greaterThan(100),
      );
      expect(() => plan.points.clear(), throwsUnsupportedError);
      expect(plan.estimatedDuration.inMinutes, 16);
    },
  );

  test('saved plans reject unknown versions and invalid checkpoint order', () {
    final map = loopPlan().toMap();
    expect(
      () => RoutePlan.fromMap({...map, 'version': 99}),
      throwsFormatException,
    );
    final checkpoints = (map['checkpoints'] as List).reversed.toList();
    expect(
      () => RoutePlan.fromMap({...map, 'checkpoints': checkpoints}),
      throwsFormatException,
    );
    final restored = RoutePlan.fromMap(map);
    expect(() => restored.checkpoints.clear(), throwsUnsupportedError);
    expect(() => restored.explorationSamples.clear(), throwsUnsupportedError);
  });

  test('legacy v1 loops remain readable; v2 preserves point-to-point mode', () {
    final loop = loopPlan();
    final legacy = {...loop.toMap(), 'version': 1}..remove('mode');
    expect(RoutePlan.fromMap(legacy), loop);
    final pointToPoint = pointToPointPlan();
    expect(pointToPoint.isLoop, isFalse);
    expect(pointToPoint.requestedDistance, isNull);
    expect(pointToPoint.checkpoints.last.point, pointToPoint.points.last);
    expect(
      pointToPoint.checkpoints.last.point,
      isNot(pointToPoint.points.first),
    );
    expect(
      RoutePlan.fromMap(jsonDecode(jsonEncode(pointToPoint.toMap()))),
      pointToPoint,
    );
    expect(
      () => RoutePlan.fromMap({...loop.toMap(), 'mode': 'unknown'}),
      throwsFormatException,
    );
  });

  test(
    'short open walks have a finish checkpoint; invalid ranges are rejected',
    () {
      const start = GeoPoint(0, 0);
      final short = pointToPointPlan(
        start: start,
        end: const GeoPoint(0.002, 0),
      );
      expect(short.checkpoints, hasLength(1));
      expect(short.checkpoints.single.point, short.points.last);
      for (final end in [
        start,
        const GeoPoint(0.0001, 0),
        const GeoPoint(1, 0),
        const GeoPoint(double.nan, 0),
      ]) {
        expect(
          () => pointToPointPlan(start: start, end: end),
          throwsFormatException,
        );
      }
      expect(
        () => RoutePlan.fromGeometry(
          id: 'bad',
          mode: RoutePlanMode.pointToPoint,
          requestedDistance: 1000,
          points: short.points,
        ),
        throwsFormatException,
      );
    },
  );

  test('invalid, open and wrong-length routes are rejected', () {
    final plan = loopPlan();
    for (final points in [
      <GeoPoint>[],
      plan.points.take(4).toList(),
      [...plan.points.take(4), const GeoPoint(double.nan, 0)],
    ]) {
      expect(
        () => RoutePlan.fromGeometry(
          id: 'bad',
          requestedDistance: 1200,
          points: points,
        ),
        throwsFormatException,
      );
    }
    expect(
      () => RoutePlan.fromGeometry(
        id: 'bad',
        requestedDistance: 3000,
        points: plan.points,
      ),
      throwsFormatException,
    );
    expect(() => loopPlan(distance: 500), throwsFormatException);
  });

  test(
    'geohash cells encode and decode with stable bounds including dateline',
    () {
      for (final point in [
        const GeoPoint(56.84, 60.61),
        const GeoPoint(-34, -58),
        const GeoPoint(0, 179.99999),
      ]) {
        final cell = ExplorationCell.at(point);
        expect(ExplorationCell.fromId(cell.id), cell);
        expect(
          point.latitude,
          inInclusiveRange(
            cell.corners.first.latitude,
            cell.corners.last.latitude,
          ),
        );
        expect(
          point.longitude,
          inInclusiveRange(
            cell.corners.first.longitude,
            cell.corners[1].longitude,
          ),
        );
        expect(cell.corners.every((p) => p.isValid), isTrue);
      }
      expect(() => ExplorationCell.fromId('invalid!'), throwsFormatException);
    },
  );

  test('cell requires two accurate fixes, not uncertain boundary jitter', () {
    final cell = ExplorationCell.at(const GeoPoint(56.84, 60.61));
    expect(
      ExplorationRules.discovered(
        walkFix(cell.center, 0),
        walkFix(cell.center, 2),
      ),
      cell,
    );
    final border = cell.corners.first;
    expect(
      ExplorationRules.discovered(walkFix(border, 0), walkFix(border, 2)),
      isNull,
    );
    expect(
      ExplorationRules.discovered(
        walkFix(cell.center, 0),
        walkFix(cell.center, 2, accuracy: null),
      ),
      isNull,
    );
    expect(
      ExplorationRules.discovered(
        walkFix(cell.center, 0),
        walkFix(cell.center, 2, accuracy: 40),
      ),
      isNull,
    );
  });

  test(
    'gaps, duplicate timestamps and vehicle speed do not confirm progress',
    () {
      final point = loopPlan().points.first;
      for (final fix in [
        walkFix(point, 0),
        walkFix(point, -1),
        walkFix(point, 31),
        walkFix(point, 2, speed: 30),
      ]) {
        expect(ExplorationRules.consecutive(walkFix(point, 0), fix), isFalse);
      }
      expect(
        ExplorationRules.consecutive(
          walkFix(point, 0),
          walkFix(const GeoPoint(1, 1), 2),
        ),
        isFalse,
      );
    },
  );

  test('checkpoint needs two nearby fixes and respects accuracy and previous checkpoint time', () {
    final point = loopPlan().checkpoints.first.point;
    final first = walkFix(point, 2);
    final second = walkFix(point, 3);
    expect(ExplorationRules.reaches(first, second, point), isTrue);
    expect(
      ExplorationRules.reaches(
        first,
        second,
        point,
        lastReached: first.timestamp,
      ),
      isFalse,
    );
    expect(
      ExplorationRules.reaches(first, walkFix(point, 3, accuracy: 35), point),
      isFalse,
    );
    final held = walkFix(const GeoPoint(2, 2), 3).withFilteredPosition(
      latitude: point.latitude,
      longitude: point.longitude,
      isStationary: true,
    );
    expect(ExplorationRules.reaches(first, held, point), isFalse);
  });

  test('a closed plan starts incomplete despite being near its finish', () {
    final plan = loopPlan();
    final progress = WalkProgress(
      routeId: 1,
      plan: plan,
      reached: 0,
      newCells: 0,
      recording: true,
    );
    expect(progress.completed, isFalse);
    expect(
      ExplorationRules.reaches(
        walkFix(plan.points.first, 0),
        walkFix(plan.points.first, 2),
        progress.next!.point,
      ),
      isFalse,
    );
  });
}

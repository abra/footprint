import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:test/test.dart';

import '../../domain_models/test/walk_fixtures.dart';

Future<bool> append(SqliteStorage storage, int routeId, LocationDM point) =>
    storage.routes.addPoint(
      routeId: routeId,
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: point.timestamp,
      accuracy: point.accuracy,
      speed: point.speed,
      speedAccuracy: point.speedAccuracy,
      sourceId: point.id,
    );

void main() {
  sqfliteFfiInit();
  late Directory directory;
  late SqliteStorage storage;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('footprint-exploration-');
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/routes.db',
    );
  });
  tearDown(() async {
    await storage.close();
    await directory.delete(recursive: true);
  });

  Future<int> start({RoutePlan? plan}) {
    final point =
        plan?.points.first ??
        ExplorationCell.at(const GeoPoint(0.001, 0.001)).center;
    return storage.routes.create(
      latitude: point.latitude,
      longitude: point.longitude,
      timestamp: walkEpoch,
      sourceId: 'walk:0',
      accuracy: 5,
      plan: plan,
    );
  }

  test(
    'point-to-point plan reopens and completes at B without returning to A',
    () async {
      final plan = pointToPointPlan();
      final id = await start(plan: plan);
      for (final (i, checkpoint) in plan.checkpoints.indexed) {
        await append(storage, id, walkFix(checkpoint.point, (i + 1) * 45));
        await append(storage, id, walkFix(checkpoint.point, (i + 1) * 45 + 2));
      }
      await storage.routes.complete(
        id,
        walkEpoch.add(const Duration(minutes: 3)),
      );
      await storage.close();
      storage = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/routes.db',
      );
      final restored = (await storage.exploration.getPlan(id))!;
      expect(restored, plan);
      expect(restored.mode, RoutePlanMode.pointToPoint);
      final progress = (await storage.exploration.getProgress(id, restored))!;
      expect(progress.completed, isTrue);
      expect(progress.recording, isFalse);
      expect((await storage.exploration.getProfile()).completedWalks, 1);
      expect(
        (await storage.routes.getById(id))!.routePoints!.last.latitude,
        plan.points.last.latitude,
      );
    },
  );

  test(
    'free recording discovers cells once without creating a planned walk',
    () async {
      final id = await start();
      final center = ExplorationCell.at(const GeoPoint(0.001, 0.001)).center;
      final fix = walkFix(center, 2);
      expect(await append(storage, id, fix), isTrue);
      expect(await append(storage, id, fix), isFalse);
      expect((await storage.exploration.getProfile()).cells, 1);
      expect(await storage.exploration.getPlan(id), isNull);
      await storage.routes.complete(
        id,
        walkEpoch.add(const Duration(minutes: 1)),
      );
      await storage.routes.delete(id);
      expect((await storage.exploration.getProfile()).cells, 1);
    },
  );

  test('checkpoint order, early finish and persisted plan remain independent of GPS geometry', () async {
    final plan = loopPlan();
    final id = await start(plan: plan);
    await append(storage, id, walkFix(plan.points.first, 2));
    expect((await storage.exploration.getProgress(id, plan))!.reached, 0);
    await append(storage, id, walkFix(plan.checkpoints[1].point, 40));
    await append(storage, id, walkFix(plan.checkpoints[1].point, 42));
    expect((await storage.exploration.getProgress(id, plan))!.reached, 0);
    final first = plan.checkpoints.first.point;
    await append(storage, id, walkFix(first, 80));
    await append(storage, id, walkFix(first, 82));
    await storage.routes.complete(
      id,
      walkEpoch.add(const Duration(seconds: 90)),
    );
    final progress = (await storage.exploration.getProgress(id, plan))!;
    expect(progress.reached, 1);
    expect(progress.completed, isFalse);
    expect(progress.recording, isFalse);
    expect((await storage.exploration.getProfile()).achievements, isEmpty);
    expect(await storage.exploration.getPlan(id), plan);
  });

  test(
    'full loop, duplicate delivery, reopening and repeated stop award once',
    () async {
      final plan = loopPlan();
      final id = await start(plan: plan);
      var second = 0;
      for (final checkpoint in plan.checkpoints) {
        second += 45;
        await append(storage, id, walkFix(checkpoint.point, second));
        final point = walkFix(checkpoint.point, second + 2);
        await append(storage, id, point);
        await append(storage, id, point);
      }
      await storage.close();
      storage = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/routes.db',
      );
      final restored = (await storage.exploration.getProgress(
        id,
        (await storage.exploration.getPlan(id))!,
      ))!;
      expect(restored.completed, isTrue);
      expect(restored.recording, isTrue);
      await storage.routes.complete(
        id,
        walkEpoch.add(const Duration(minutes: 3)),
      );
      await storage.routes.complete(
        id,
        walkEpoch.add(const Duration(minutes: 4)),
      );
      final profile = await storage.exploration.getProfile();
      expect(profile.completedWalks, 1);
      expect(profile.achievements, contains(ExplorationAchievement.firstWalk));
      expect(
        await append(storage, id, walkFix(plan.points.first, 190)),
        isFalse,
      );
    },
  );

  test('failed discovery rolls back the GPS write; retry is atomic', () async {
    final id = await start();
    final db = await databaseFactoryFfi.openDatabase(
      '${directory.path}/routes.db',
      options: OpenDatabaseOptions(singleInstance: false),
    );
    try {
      await db.execute(
        "CREATE TRIGGER fail_discovery BEFORE INSERT ON explored_cells BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
      );
      final point = walkFix(
        ExplorationCell.at(const GeoPoint(0.001, 0.001)).center,
        2,
      );
      await expectLater(
        append(storage, id, point),
        throwsA(isA<DatabaseException>()),
      );
      expect((await storage.routes.getById(id))!.routePoints, hasLength(1));
      expect((await storage.exploration.getProfile()).cells, 0);
      await db.execute('DROP TRIGGER fail_discovery');
      await append(storage, id, point);
      expect((await storage.routes.getById(id))!.routePoints, hasLength(2));
      expect((await storage.exploration.getProfile()).cells, 1);
    } finally {
      await db.close();
    }
  });

  test(
    'discovery thresholds award once and viewport queries wrap at the dateline',
    () async {
      final id = await start();
      for (var i = 0; i < 100; i++) {
        final center = ExplorationCell.at(GeoPoint(0.01 + i * 0.002, 0.01))
            .center;
        await append(storage, id, walkFix(center, i * 40 + 40));
        await append(storage, id, walkFix(center, i * 40 + 42));
        if (i == 8) {
          expect(
            (await storage.exploration.getProfile()).achievements,
            isEmpty,
          );
        }
        if (i == 9) {
          expect((await storage.exploration.getProfile()).achievements, {
            ExplorationAchievement.tenAreas,
          });
        }
      }
      final profile = await storage.exploration.getProfile();
      expect(profile.cells, 100);
      expect(profile.achievements, {
        ExplorationAchievement.tenAreas,
        ExplorationAchievement.hundredAreas,
      });
      final cells = [
        ExplorationCell.at(const GeoPoint(0, 179.999)),
        ExplorationCell.at(const GeoPoint(0, -179.999)),
      ];
      for (final (i, cell) in cells.indexed) {
        await append(storage, id, walkFix(cell.center, 4100 + i * 40));
        await append(storage, id, walkFix(cell.center, 4102 + i * 40));
      }
      expect(
        await storage.exploration.getCells(
          south: -1,
          north: 1,
          west: 179,
          east: -179,
        ),
        unorderedEquals(cells),
      );
      expect(
        await storage.exploration.getCells(
          south: -1,
          north: 1,
          west: -1,
          east: 1,
          limit: 3,
        ),
        hasLength(3),
      );
    },
  );

  test(
    'failed completion award keeps the route active until a successful retry',
    () async {
      final plan = loopPlan();
      final id = await start(plan: plan);
      for (final (i, checkpoint) in plan.checkpoints.indexed) {
        await append(storage, id, walkFix(checkpoint.point, (i + 1) * 40));
        await append(storage, id, walkFix(checkpoint.point, (i + 1) * 40 + 2));
      }
      final db = await databaseFactoryFfi.openDatabase(
        '${directory.path}/routes.db',
        options: OpenDatabaseOptions(singleInstance: false),
      );
      try {
        await db.execute(
          "CREATE TRIGGER fail_award BEFORE INSERT ON exploration_achievements BEGIN SELECT RAISE(ABORT, 'disk failure'); END",
        );
        final end = walkEpoch.add(const Duration(minutes: 3));
        await expectLater(
          storage.routes.complete(id, end),
          throwsA(isA<DatabaseException>()),
        );
        expect(
          (await storage.exploration.getProgress(id, plan))!.recording,
          isTrue,
        );
        expect((await storage.exploration.getProfile()).achievements, isEmpty);
        await db.execute('DROP TRIGGER fail_award');
        await storage.routes.complete(id, end);
        await storage.routes.complete(id, end);
        expect(
          (await storage.exploration.getProgress(id, plan))!.recording,
          isFalse,
        );
        expect((await storage.exploration.getProfile()).achievements, {
          ExplorationAchievement.firstWalk,
        });
      } finally {
        await db.close();
      }
    },
  );

  test(
    'separate connections deduplicate a racing GPS fix and discovery',
    () async {
      final id = await start();
      final other = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: '${directory.path}/routes.db',
      );
      try {
        final point = walkFix(
          ExplorationCell.at(const GeoPoint(0.001, 0.001)).center,
          2,
        );
        final results = await Future.wait([
          append(storage, id, point),
          append(other, id, point),
        ]);
        expect(results.where((r) => r), hasLength(1));
        expect((await other.exploration.getProfile()).cells, 1);
      } finally {
        await other.close();
      }
    },
  );
}

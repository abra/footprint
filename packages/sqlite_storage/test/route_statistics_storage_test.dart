import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:sqlite_storage/src/database_helper.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  late SqliteStorage storage;
  final start = DateTime(2026, 9, 7, 10);
  setUp(() async {
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => storage.close());

  Future<int> record() async {
    final id = await storage.routes.create(
      latitude: 56,
      longitude: 60,
      timestamp: start,
    );
    await storage.routes.addPoint(
      routeId: id,
      latitude: 56.001,
      longitude: 60,
      timestamp: start.add(const Duration(minutes: 1)),
    );
    await storage.routes.complete(id, start.add(const Duration(minutes: 10)));
    return id;
  }

  test(
    'only completed recordings count, with the same geometry and elapsed time',
    () async {
      final id = await record();
      await storage.routes.create(latitude: 0, longitude: 0, timestamp: start);
      final result = (await storage.statistics.getSummaries()).single;
      final expected = RouteMetrics.fromLocations(
        [
          LocationDM(id: '1', latitude: 56, longitude: 60, timestamp: start),
          LocationDM(
            id: '2',
            latitude: 56.001,
            longitude: 60,
            timestamp: start.add(const Duration(minutes: 1)),
          ),
        ],
        startedAt: start,
        endedAt: start.add(const Duration(minutes: 10)),
      );
      expect(result.id, id);
      expect(result.distance, expected.distance);
      expect(result.duration, const Duration(minutes: 10));
      expect(result.startedAt, start);
    },
  );

  test('rename retains metrics; deletion removes the cached summary', () async {
    final id = await record();
    final first = await storage.statistics.getSummaries();
    await storage.routes.rename(id, 'New name');
    expect(await storage.statistics.getSummaries(), first);
    await storage.routes.delete(id);
    expect(await storage.statistics.getSummaries(), isEmpty);
  });

  test(
    'later completions appear on refresh and duplicate reads coalesce',
    () async {
      await record();
      final first = storage.statistics.getSummaries();
      final second = storage.statistics.getSummaries();
      expect(identical(first, second), isTrue);
      expect(await first, hasLength(1));
      await second;
      await record();
      expect(await storage.statistics.getSummaries(), hasLength(2));
    },
  );

  test(
    'closing joins an in-flight cache operation and rejects new reads',
    () async {
      await record();
      final pending = storage.statistics.getSummaries();
      final closing = storage.close();
      await pending;
      await closing;
      await expectLater(storage.statistics.getSummaries(), throwsStateError);
      await storage.close();
    },
  );

  test(
    'v7 migration preserves records and caches once across reopening',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'footprint-statistics-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/legacy.db';
      final old = await databaseFactoryFfi.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 7,
          onCreate: (db, version) async {
            await DatabaseHelper.create(db, version);
            await db.execute('DROP TABLE route_statistics');
          },
        ),
      );
      await old.insert('routes', {
        'id': 1,
        'name': 'Legacy route',
        'start_time': start.toIso8601String(),
        'end_time': start.add(const Duration(hours: 1)).toIso8601String(),
        'status': 'completed',
        'distance': 999999,
      });
      for (final (lat, seconds) in [
        (56.0, 0),
        (95.0, 10),
        (56.0005, 20),
        (56.01, 15),
        (56.0005, 30),
      ]) {
        await old.insert('route_points', {
          'route_id': 1,
          'latitude': lat,
          'longitude': 60,
          'timestamp': start.add(Duration(seconds: seconds)).toIso8601String(),
        });
      }
      await old.insert('explored_cells', {
        'cell_id': 'cell',
        'latitude': 56,
        'longitude': 60,
        'first_route_id': 1,
        'discovered_at': start.toIso8601String(),
      });
      await old.close();
      var migrated = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final first = (await migrated.statistics.getSummaries()).single;
      expect(first.distance, inExclusiveRange(50, 60));
      expect(first.duration, const Duration(hours: 1));
      expect((await migrated.routes.getById(1))!.routePoints, hasLength(5));
      expect((await migrated.routes.getById(1))!.name, 'Legacy route');
      await migrated.close();
      final check = await databaseFactoryFfi.openDatabase(path);
      expect(await check.getVersion(), 8);
      expect(await check.query('route_statistics'), hasLength(1));
      expect(await check.query('explored_cells'), hasLength(1));
      // A cached query must not depend on loading the trace again.
      await check.execute('ALTER TABLE route_points RENAME TO hidden_points');
      await check.close();
      migrated = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        expect((await migrated.statistics.getSummaries()).single, first);
      } finally {
        await migrated.close();
      }
    },
  );
}

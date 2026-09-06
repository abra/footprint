import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  late SqliteStorage storage;
  final timestamp = DateTime.utc(2026, 9, 6, 10);

  setUp(() async {
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
  });
  tearDown(() => storage.close());

  test(
    'route lifecycle persists ordered points and nullable addresses',
    () async {
      final id = await storage.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: timestamp,
      );
      await storage.routes.addPoint(
        routeId: id,
        latitude: 56.01,
        longitude: 60.01,
        timestamp: timestamp.add(const Duration(seconds: 10)),
      );
      var route = (await storage.routes.getById(id))!;
      expect(route.id, id);
      expect(route.status, 'active');
      expect(route.routePoints!.map((p) => p.latitude), [56, 56.01]);
      expect(route.routePoints!.first.address, isNull);
      await storage.routes.complete(
        id,
        timestamp.add(const Duration(seconds: 10)),
      );
      route = (await storage.routes.getById(id))!;
      expect(route.status, 'completed');
      expect(route.endTime, '2026-09-06T10:00:10.000Z');
      await storage.routes.delete(id);
      expect(await storage.routes.getById(id), isNull);
      expect(await storage.routes.getAll(), isEmpty);
    },
  );

  test('orphan route points are not inserted', () async {
    expect(
      await storage.routes.addPoint(
        routeId: 999,
        latitude: 56,
        longitude: 60,
        timestamp: timestamp,
      ),
      isFalse,
    );
  });

  test(
    'cache query includes nearby points across longitude grid boundaries',
    () async {
      await storage.geocodingCache.add(
        address: 'Nearby',
        latitude: 56.00015,
        longitude: 120,
      );
      final result = await storage.geocodingCache.nearby(
        latitude: 56,
        longitude: 120,
        maxAge: const Duration(days: 7),
      );
      expect(result.single.address, 'Nearby');
      await storage.geocodingCache.markUsed(result.single.id);
      expect(
        (await storage.geocodingCache.nearby(
          latitude: 56,
          longitude: 120,
          maxAge: const Duration(days: 7),
        )).single.usageFrequency,
        1,
      );
    },
  );

  test('cache query handles the international date line', () async {
    await storage.geocodingCache.add(
      address: 'Across date line',
      latitude: 0,
      longitude: -179.9999,
    );
    expect(
      await storage.geocodingCache.nearby(
        latitude: 0,
        longitude: 179.9999,
        maxAge: const Duration(days: 7),
      ),
      hasLength(1),
    );
  });

  test(
    'close is idempotent and a new connection can reopen persisted data',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'footprint-storage-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/test.db';
      final first = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      final id = await first.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: timestamp,
      );
      await Future.wait([first.close(), first.close()]);
      final second = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: path,
      );
      try {
        expect((await second.routes.getById(id))!.routePoints, hasLength(1));
      } finally {
        await second.close();
      }
    },
  );

  for (final legacyVersion in [1, 2, 3, 4]) {
    test(
      'version $legacyVersion migration preserves existing route data and repairs indexes',
      () async {
        final directory = await Directory.systemTemp.createTemp(
          'footprint-migration-',
        );
        addTearDown(() => directory.delete(recursive: true));
        final path = '${directory.path}/legacy.db';
        final legacy = await databaseFactoryFfi.openDatabase(
          path,
          options: OpenDatabaseOptions(
            version: legacyVersion,
            onCreate: (db, version) async {
              await db.execute(
                'CREATE TABLE routes (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'start_point TEXT, end_point TEXT, start_time TEXT, end_time TEXT, distance REAL, average_speed REAL, '
                "status TEXT NOT NULL CHECK(status IN ('active', 'completed')))${legacyVersion == 1 ? ' STRICT' : ''}",
              );
              await db.execute(
                'CREATE TABLE route_points (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'route_id INTEGER NOT NULL REFERENCES routes(id), latitude REAL NOT NULL, longitude REAL NOT NULL, '
                "address TEXT, timestamp TEXT NOT NULL)${legacyVersion == 1 ? ' STRICT' : ''}",
              );
              await db.execute(
                'CREATE TABLE geocoding_cache (id INTEGER PRIMARY KEY AUTOINCREMENT, '
                'address TEXT, latitude REAL, longitude REAL, latitude_idx INTEGER, '
                "longitude_idx INTEGER, usage_frequency INTEGER DEFAULT 0, timestamp TEXT)${legacyVersion == 1 ? ' STRICT' : ''}",
              );
              if (legacyVersion >= 3) {
                await db.execute(
                  'ALTER TABLE route_points ADD COLUMN source_id TEXT',
                );
              }
              if (legacyVersion >= 4) {
                await db.execute('ALTER TABLE routes ADD COLUMN name TEXT');
                await db.execute(
                  'ALTER TABLE routes ADD COLUMN name_search TEXT',
                );
              }
              await db.insert('routes', {
                'id': 7,
                'start_time': timestamp.toIso8601String(),
                'status': 'active',
              });
              await db.insert('route_points', {
                'route_id': 7,
                'latitude': 56.0,
                'longitude': 60.0,
                'timestamp': timestamp.toIso8601String(),
              });
            },
          ),
        );
        await legacy.close();
        final migrated = await SqliteStorage.open(
          factory: databaseFactoryFfi,
          path: path,
        );
        expect(
          (await migrated.routes.getById(7))!.routePoints!.single.latitude,
          56,
        );
        expect(
          (await migrated.routes.getById(7))!.routePoints!.single.sourceId,
          isNull,
        );
        await migrated.routes.addPoint(
          routeId: 7,
          latitude: 56.01,
          longitude: 60,
          timestamp: timestamp.add(const Duration(seconds: 1)),
          sourceId: 'new',
        );
        expect(
          await migrated.routes.addPoint(
            routeId: 7,
            latitude: 56.01,
            longitude: 60,
            timestamp: timestamp.add(const Duration(seconds: 1)),
            sourceId: 'new',
          ),
          isFalse,
        );
        expect((await migrated.routes.getById(7))!.routePoints, hasLength(2));
        await migrated.close();
        final check = await databaseFactoryFfi.openDatabase(path);
        expect(await check.getVersion(), 5);
        expect(
          await check.rawQuery(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name = 'idx_geocoding_cache_coordinates'",
          ),
          hasLength(1),
        );
        await check.close();
      },
    );
  }

  test(
    'duplicate source IDs and samples after completion are not inserted',
    () async {
      final id = await storage.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: timestamp,
        sourceId: 'first',
      );
      expect(
        await storage.routes.addPoint(
          routeId: id,
          latitude: 56,
          longitude: 60,
          timestamp: timestamp,
          sourceId: 'first',
        ),
        isFalse,
      );
      await storage.routes.complete(id, timestamp);
      expect(
        await storage.routes.addPoint(
          routeId: id,
          latitude: 56.1,
          longitude: 60,
          timestamp: timestamp.add(const Duration(seconds: 1)),
          sourceId: 'late',
        ),
        isFalse,
      );
      expect((await storage.routes.getById(id))!.routePoints, hasLength(1));
    },
  );

  test('concurrent starts cannot create two active routes', () async {
    final first = storage.routes.create(
      latitude: 56,
      longitude: 60,
      timestamp: timestamp,
    );
    final second = storage.routes.create(
      latitude: 56,
      longitude: 60,
      timestamp: timestamp,
    );
    final rejected = expectLater(second, throwsStateError);
    await first;
    await rejected;
    expect(await storage.routes.getAll(), hasLength(1));
  });

  test(
    'completion is idempotent and cannot precede the last saved sample',
    () async {
      final id = await storage.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: timestamp,
      );
      final last = timestamp.add(const Duration(seconds: 10));
      await storage.routes.addPoint(
        routeId: id,
        latitude: 56.1,
        longitude: 60,
        timestamp: last,
      );
      await storage.routes.complete(id, timestamp);
      await storage.routes.complete(
        id,
        timestamp.add(const Duration(hours: 1)),
      );
      expect(
        (await storage.routes.getById(id))!.endTime,
        last.toIso8601String(),
      );
    },
  );
}

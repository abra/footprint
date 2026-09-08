import 'package:sqflite/sqflite.dart';

abstract final class DatabaseHelper {
  static Future<void> create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_point TEXT, end_point TEXT,
        start_time TEXT NOT NULL, end_time TEXT, name TEXT, name_search TEXT,
        distance REAL, average_speed REAL,
        status TEXT NOT NULL CHECK (status IN ('active', 'completed'))
      )
    ''');
    await db.execute('''
      CREATE TABLE route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id INTEGER NOT NULL REFERENCES routes(id),
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        address TEXT, timestamp TEXT NOT NULL, source_id TEXT,
        accuracy REAL, speed REAL, speed_accuracy REAL, filtered_speed REAL,
        raw_latitude REAL, raw_longitude REAL,
        is_stationary INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute('''
      CREATE TABLE geocoding_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        address TEXT NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        latitude_idx INTEGER NOT NULL, longitude_idx INTEGER NOT NULL,
        usage_frequency INTEGER DEFAULT 0, timestamp TEXT NOT NULL
      )
    ''');
    await createPhotoTables(db);
    await addPhotoComments(db);
    await createExplorationTables(db);
    await createStatisticsTable(db);
    await createIndexes(db);
  }

  static Future<void> upgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE route_points ADD COLUMN source_id TEXT');
    }
    if (oldVersion < 4) {
      await db.execute('ALTER TABLE routes ADD COLUMN name TEXT');
      await db.execute('ALTER TABLE routes ADD COLUMN name_search TEXT');
    }
    if (oldVersion < 5) await createPhotoTables(db);
    if (oldVersion < 6) {
      for (final column in [
        'accuracy',
        'speed',
        'speed_accuracy',
        'filtered_speed',
        'raw_latitude',
        'raw_longitude',
      ]) {
        await db.execute('ALTER TABLE route_points ADD COLUMN $column REAL');
      }
      await db.execute(
        'ALTER TABLE route_points ADD COLUMN is_stationary INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 7) await createExplorationTables(db);
    if (oldVersion < 8) await createStatisticsTable(db);
    if (oldVersion < 9) await addPhotoComments(db);
    await createIndexes(db);
  }

  static Future<void> addPhotoComments(Database db) => db.execute(
    "ALTER TABLE route_photos ADD COLUMN comment TEXT NOT NULL DEFAULT ''",
  );

  static Future<void> createStatisticsTable(Database db) => db.execute('''
    CREATE TABLE route_statistics (
      route_id INTEGER PRIMARY KEY REFERENCES routes(id) ON DELETE CASCADE,
      distance REAL NOT NULL CHECK(distance >= 0),
      duration_us INTEGER NOT NULL CHECK(duration_us >= 0)
    )
  ''');

  static Future<void> createExplorationTables(Database db) async {
    await db.execute('''
      CREATE TABLE walks (
        route_id INTEGER PRIMARY KEY REFERENCES routes(id) ON DELETE CASCADE,
        plan TEXT NOT NULL,
        reached INTEGER NOT NULL DEFAULT 0,
        last_reached_at TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE walk_checkpoints (
        route_id INTEGER NOT NULL REFERENCES walks(route_id) ON DELETE CASCADE,
        ordinal INTEGER NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        PRIMARY KEY (route_id, ordinal)
      )
    ''');
    await db.execute('''
      CREATE TABLE explored_cells (
        cell_id TEXT PRIMARY KEY NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        first_route_id INTEGER REFERENCES routes(id) ON DELETE SET NULL,
        discovered_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX explored_cells_position ON explored_cells(latitude, longitude)',
    );
    await db.execute(
      'CREATE INDEX explored_cells_route ON explored_cells(first_route_id)',
    );
    await db.execute('''
      CREATE TABLE exploration_achievements (
        code TEXT PRIMARY KEY NOT NULL, unlocked_at TEXT NOT NULL
      )
    ''');
  }

  static Future<void> createPhotoTables(Database db) async {
    await db.execute('''
      CREATE TABLE route_photos (
        id TEXT PRIMARY KEY NOT NULL,
        route_id INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL UNIQUE,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        captured_at TEXT NOT NULL
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_route_photos_route ON route_photos(route_id)',
    );
    await db.execute('''
      CREATE TABLE pending_photo (
        slot INTEGER PRIMARY KEY CHECK (slot = 1),
        id TEXT NOT NULL UNIQUE,
        route_id INTEGER NOT NULL REFERENCES routes(id) ON DELETE CASCADE,
        file_name TEXT NOT NULL,
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        captured_at TEXT NOT NULL, source_path TEXT
      )
    ''');
  }

  static Future<void> createIndexes(Database db) async {
    // Separate statements also repair the missing index in version 1 databases.
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_route_points_route '
      'ON route_points(route_id, id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_geocoding_cache_coordinates '
      'ON geocoding_cache(latitude, longitude)',
    );
    await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_route_points_source '
      'ON route_points(route_id, source_id)',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_routes_status ON routes(status, id)',
    );
  }
}

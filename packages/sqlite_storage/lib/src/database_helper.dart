import 'package:sqflite/sqflite.dart';

abstract final class DatabaseHelper {
  static Future<void> create(Database db, int version) async {
    await db.execute('''
      CREATE TABLE routes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        start_point TEXT, end_point TEXT,
        start_time TEXT NOT NULL, end_time TEXT,
        distance REAL, average_speed REAL,
        status TEXT NOT NULL CHECK (status IN ('active', 'completed'))
      )
    ''');
    await db.execute('''
      CREATE TABLE route_points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        route_id INTEGER NOT NULL REFERENCES routes(id),
        latitude REAL NOT NULL, longitude REAL NOT NULL,
        address TEXT, timestamp TEXT NOT NULL, source_id TEXT
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
    await createIndexes(db);
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

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'exceptions.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  Future<Database> _initDatabase() async {
    final databasePath = await getDatabasesPath();
    final path = join(databasePath, 'footprint.db');
    try {
      return await openDatabase(path, version: 1, onCreate: _createTables);
    } on DatabaseException catch (_) {
      throw UnableCreateDatabaseException();
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await Routes.createTable(db);
      await RoutePoints.createTable(db);
      await GeocodingCache.createTable(db);
    } on DatabaseException catch (_) {
      throw UnableCreateTableException();
    }
  }
}

class Routes {
  static const String tableName = 'routes';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableName (
      id            INTEGER PRIMARY KEY AUTOINCREMENT,
      start_point   TEXT,
      end_point     TEXT,
      start_time    TEXT,
      end_time      TEXT,
      distance      REAL,
      average_speed REAL,
      status        TEXT CHECK(status IN ('active', 'completed')), 
    );
    ''');
  }
}

class RoutePoints {
  static const String tableName = 'route_points';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableName (
      id              INTEGER PRIMARY KEY AUTOINCREMENT,
      route_id        INTEGER NOT NULL,
      latitude        REAL NOT NULL,
      longitude       REAL NOT NULL,  
      address         TEXT,
      timestamp       TEXT NOT NULL,
      FOREIGN KEY(route_id) REFERENCES routes(id)
    );
    ''');
  }
}

class GeocodingCache {
  static const String tableName = 'geocoding_cache';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE IF NOT EXISTS $tableName (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude  REAL NOT NULL,
      longitude REAL NOT NULL,
      usage_frequency INTEGER DEFAULT 0,
      timestamp TEXT NOT NULL,
    );
    ''');
  }
}

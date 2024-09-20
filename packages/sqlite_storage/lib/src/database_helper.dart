import 'dart:developer';

import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'models/exceptions.dart';

class DatabaseHelper {
  DatabaseHelper._internal();

  static final DatabaseHelper _instance = DatabaseHelper._internal();

  factory DatabaseHelper() => _instance;

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    await Future.delayed(const Duration(milliseconds: 100));
    log('init database', name: 'DatabaseHelper', time: DateTime.now());
    _database = await _initDatabase();
    return _database!;
  }

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  Future<Database> _initDatabase() async {
    try {
      final databasePath = await getDatabasesPath();
      final path = join(databasePath, 'footprint.db');
      return await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
      );
    } catch (e, s) {
      throw SqliteStorageDatabaseException(
        message: 'Failed to open database: $e',
        stackTrace: s,
      );
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await Routes.createTable(db);
      await RoutePoints.createTable(db);
      await GeocodingCache.createTable(db);
    } catch (e) {
      rethrow;
      // throw UnableCreateTableException(
      //   message: "Failed to create table: $e",
      // );
    }
  }
}

class Routes {
  static const String tableName = 'routes';

  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id            INTEGER PRIMARY KEY AUTOINCREMENT,
          start_point   TEXT,
          end_point     TEXT,
          start_time    TEXT,
          end_time      TEXT,
          distance      REAL,
          average_speed REAL,
          status        TEXT NOT NULL CHECK (status IN ('active', 'completed')) 
        ) STRICT;
        ''');
    } catch (e, s) {
      throw SqliteStorageDatabaseException(
        message: "Failed to create table $tableName: $e",
        stackTrace: s,
      );
    }
  }
}

class RoutePoints {
  static const String tableName = 'route_points';

  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS $tableName (
          id              INTEGER PRIMARY KEY AUTOINCREMENT,
          route_id        INTEGER NOT NULL,
          latitude        REAL NOT NULL,
          longitude       REAL NOT NULL,  
          address         TEXT,
          timestamp       TEXT NOT NULL,
          FOREIGN KEY(route_id) REFERENCES routes(id)
        ) STRICT;
        ''');
    } catch (e, s) {
      throw SqliteStorageDatabaseException(
        message: "Failed to create table $tableName: $e",
        stackTrace: s,
      );
    }
  }
}

class GeocodingCache {
  static const String tableName = 'geocoding_cache';

  static Future<void> createTable(Database db) async {
    try {
      await db.execute('''
        -- Create table
        CREATE TABLE IF NOT EXISTS $tableName (
          id        INTEGER PRIMARY KEY AUTOINCREMENT,
          address   TEXT NOT NULL,
          latitude  REAL NOT NULL,
          longitude REAL NOT NULL,
          latitude_idx INTEGER NOT NULL,
          longitude_idx INTEGER NOT NULL,
          usage_frequency INTEGER DEFAULT 0,
          timestamp TEXT NOT NULL
        ) STRICT;
        
        -- Create indexes
        CREATE INDEX IF NOT EXISTS idx_${tableName}_location
        ON $tableName(latitude_idx, longitude_idx);
        ''');
    } catch (e, s) {
      throw SqliteStorageDatabaseException(
        message: "Failed to create table $tableName: $e",
        stackTrace: s,
      );
    }
  }
}

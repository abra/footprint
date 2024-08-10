import 'package:domain_models/domain_models.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'exceptions.dart';

class SqliteStorage {
  const SqliteStorage();

  static Database? _database;

  Future<void> init() async {
    final String path = join(
      await getDatabasesPath(),
      'footprint.db',
    );

    try {
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: _createTables,
      );
    } on DatabaseException catch (_) {
      throw UnableCreateDatabaseException();
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await _Routes.createTable(db);
      await _RoutePoints.createTable(db);
    } on DatabaseException catch (_) {
      throw UnableCreateTableException();
    }
  }

  Future<int> createRoute(Location location) async {
    if (_database == null) {
      await init();
    }

    try {
      final int routeId = await _database!.insert(
        _Routes.tableName,
        <String, dynamic>{
          'start_point': location.id,
          'start_time': location.timestamp.toIso8601String(),
          'status': 0,
        },
      );

      await _database!.insert(_RoutePoints.tableName, {
        'route_id': routeId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': location.timestamp.toIso8601String(),
      });

      return routeId;
    } on DatabaseException catch (_) {
      throw UnableInsertDatabaseException();
    }
  }

  Future<void> addRoutePoints(
    int routeId,
    Location location,
  ) async {
    if (_database == null) {
      await init();
    }

    try {
      await _database!.insert(
        _RoutePoints.tableName,
        <String, dynamic>{
          'route_id': routeId,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'timestamp': location.timestamp.toIso8601String(),
        },
      );
    } on DatabaseException catch (_) {
      throw UnableInsertDatabaseException();
    }
  }

  Future<List<Location>> getRoutePoints(int routeId) async {
    if (_database == null) {
      await init();
    }

    try {
      final List<Map<String, dynamic>> result = await _database!.query(
        _RoutePoints.tableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      return List<Location>.generate(
        result.length,
        (int index) => Location.fromMap(result[index]),
      );
    } on DatabaseException catch (_) {
      throw UnableExecuteQueryDatabaseException();
    }
  }

  Future<void> deleteRoute(int routeId) async {
    if (_database == null) {
      await init();
    }

    try {
      await _database!.transaction((Transaction txn) async {
        await txn.delete(
          _RoutePoints.tableName,
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        await txn.delete(
          _Routes.tableName,
          where: 'id = ?',
          whereArgs: [routeId],
        );
      });
    } on DatabaseException catch (_) {
      throw UnableDeleteDatabaseException();
    }
  }

  Future<int> changeRouteStatus(int routeId, int status) async {
    if (_database == null) {
      await init();
    }

    try {
      final int result = await _database!.update(
        _Routes.tableName,
        <String, dynamic>{
          'status': status,
        },
      );

      return result;
    } on DatabaseException catch (_) {
      throw UnableUpdateDatabaseException();
    }
  }
}

class _Routes {
  static const String tableName = 'routes';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY,
      start_point TEXT,
      end_point TEXT,
      start_time TEXT,
      end_time TEXT,
      distance REAL,
      average_speed REAL,
      status TINYINT
    )
    ''');
  }
}

class _RoutePoints {
  static const String tableName = 'route_points';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE $tableName (
      id INTEGER PRIMARY KEY,
      route_id INTEGER,
      latitude REAL,
      longitude REAL,  
      placemark TEXT,
      timestamp TEXT,
      FOREIGN KEY(route_id) REFERENCES routes(id)
    );
    ''');
  }
}

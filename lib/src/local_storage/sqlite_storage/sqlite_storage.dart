import 'package:footprint/src/domain_models/location.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../local_storage.dart';
import 'exceptions.dart';

class SqliteStorage implements LocalStorage {
  const SqliteStorage();

  static Database? _database;

  @override
  Future<List<Location>> getRoutePoints(int routeId) async {
    if (_database == null) {
      await init();
    }

    try {
      List<Map<String, dynamic>> result = await _database!.query(
        _RoutePoints.tableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      return List.generate(
        result.length,
        (index) => Location.fromMap(result[index]),
      );
    } on DatabaseException catch (_) {
      throw UnableExecuteQueryDatabaseException();
    }
  }

  @override
  Future<void> deleteRoute(int routeId) async {
    if (_database == null) {
      await init();
    }

    try {
      await _database!.transaction((txn) async {
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

  @override
  Future<int> changeRouteStatus(int routeId, int status) async {
    if (_database == null) {
      await init();
    }

    try {
      final result = await _database!.update(_Routes.tableName, {
        'status': status,
      });

      return result;
    } on DatabaseException catch (_) {
      throw UnableUpdateDatabaseException();
    }
  }

  @override
  Future<void> addRoutePoints(
    int routeId,
    Location location,
  ) async {
    if (_database == null) {
      await init();
    }

    try {
      await _database!.insert(_RoutePoints.tableName, {
        'route_id': routeId,
        'latitude': location.latitude,
        'longitude': location.longitude,
        'timestamp': location.timestamp.toIso8601String(),
      });
    } on DatabaseException catch (_) {
      throw UnableInsertDatabaseException();
    }
  }

  @override
  Future<int> createRoute(Location location) async {
    if (_database == null) {
      await init();
    }

    try {
      final routeId = await _database!.insert(_Routes.tableName, {
        'start_point': location.id,
        'start_time': location.timestamp.toIso8601String(),
        'status': 0,
      });

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

  @override
  Future<void> init() async {
    String path = join(await getDatabasesPath(), 'footprint.db');
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
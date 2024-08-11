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

  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
    }
  }

  Future<void> _createTables(Database db, int version) async {
    try {
      await _Routes.createTable(db);
      await _RoutePoints.createTable(db);
      await _GeocodingCache.createTable(db);
    } on DatabaseException catch (_) {
      throw UnableCreateTableException();
    }
  }

  Future<int> createRoute(RoutePoint routePoint) async {
    try {
      if (_database == null) {
        await init();
      }

      final int routeId = await _database!.insert(
        _Routes.tableName,
        <String, dynamic>{
          'start_time': DateTime.now().toIso8601String(),
          'status': 'active',
        },
      );

      final int routePointsId = await _database!.insert(
        _RoutePoints.tableName,
        <String, dynamic>{
          'route_id': routeId,
          'latitude': routePoint.latitude,
          'longitude': routePoint.longitude,
          'timestamp': routePoint.timestamp.toIso8601String(),
        },
      );

      return routeId;
    } on DatabaseException catch (_) {
      throw UnableInsertDatabaseException();
    }
  }

  Future<int> upsertRoutePointOfRouteById(
    int routeId,
    RoutePoint routePoint,
  ) async {
    try {
      if (_database == null) {
        await init();
      }

      return await _database!.update(
        _RoutePoints.tableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        <String, dynamic>{
          'latitude': routePoint.latitude,
          'longitude': routePoint.longitude,
          'address': routePoint.address,
          'timestamp': routePoint.timestamp.toIso8601String(),
        },
      );
    } on DatabaseException catch (_) {
      throw UnableInsertDatabaseException();
    }
  }

  Future<Route> getPointsOfRouteById(int routeId) async {
    try {
      if (_database == null) {
        await init();
      }

      final List<Map<String, dynamic>> result = await _database!.query(
        _RoutePoints.tableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      final routePoints = List<RoutePoint>.generate(
        result.length,
        (int index) => RoutePoint.fromMap(result[index]),
      );

      final route = await _database!.query(
        _Routes.tableName,
        where: 'id = ?',
        whereArgs: [routeId],
      );

      final routes = Route.fromMap(route.first);

      return Route(
        id: routes.id,
        startPoint: routePoints.first,
        endPoint: routePoints.last,
        startTime: routes.startTime,
        endTime: routes.endTime,
        distance: routes.distance,
        averageSpeed: routes.averageSpeed,
        status: routes.status,
        routePoints: routePoints,
      );
    } on DatabaseException catch (_) {
      throw UnableExecuteQueryDatabaseException();
    }
  }

  Future<void> deleteRoute(int routeId) async {
    try {
      if (_database == null) {
        await init();
      }

      // await database.transaction((txn) async {
      //   // Ok
      //   await txn. execute(...);
      //
      //   // DON'T  use the database object in a transaction
      //   // this will deadlock!
      //   await database. execute(...);
      // });
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

  Future<int> changeRouteStatus(int routeId, String status) async {
    try {
      if (_database == null) {
        await init();
      }

      return await _database!.update(
        _Routes.tableName,
        where: 'id = ?',
        whereArgs: [routeId],
        <String, dynamic>{
          'status': status,
        },
      );
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

class _RoutePoints {
  static const String tableName = 'route_points';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE $tableName (
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

class _GeocodingCache {
  static const String tableName = 'geocoding_cache';

  static Future<void> createTable(Database db) async {
    await db.execute('''
    CREATE TABLE $tableName (
      id        INTEGER PRIMARY KEY AUTOINCREMENT,
      latitude  REAL NOT NULL,
      longitude REAL NOT NULL,
      usage_frequency INTEGER DEFAULT 0,
      timestamp TEXT NOT NULL,
    );
    ''');
  }
}

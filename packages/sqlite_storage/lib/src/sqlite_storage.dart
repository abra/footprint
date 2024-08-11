import 'package:domain_models/domain_models.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqlite_storage/src/database_helper.dart';

import 'exceptions.dart';

class SqliteStorage {
  final DatabaseHelper _dbHelper = DatabaseHelper();

  Database? _database;

  Future<void> init() async {
    _database = await _dbHelper.database;
  }

  Future<void> close() async {
    await _dbHelper.close();
  }

  Future<int> createRoute(RoutePoint routePoint) async {
    try {
      if (_database == null) {
        await init();
      }

      final int routeId = await _database!.insert(
        Routes.tableName,
        <String, dynamic>{
          'start_time': DateTime.now().toIso8601String(),
          'status': 'active',
        },
      );

      final int routePointsId = await _database!.insert(
        RoutePoints.tableName,
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

  Future<int> insertRoutePoint(int routeId, RoutePoint routePoint) async {
    try {
      if (_database == null) {
        await init();
      }

      return await _database!.insert(
        RoutePoints.tableName,
        <String, dynamic>{
          'route_id': routeId,
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

  Future<Route> getAllRoutePoints(int routeId) async {
    try {
      if (_database == null) {
        await init();
      }

      final List<Map<String, dynamic>> result = await _database!.query(
        RoutePoints.tableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      final routePoints = List<RoutePoint>.generate(
        result.length,
        (int index) => RoutePoint.fromMap(result[index]),
      );

      final route = await _database!.query(
        Routes.tableName,
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

  Future<void> deleteRouteById(int routeId) async {
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
          RoutePoints.tableName,
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        await txn.delete(
          Routes.tableName,
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
        Routes.tableName,
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

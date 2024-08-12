import 'package:domain_models/domain_models.dart';
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'exceptions.dart';

class SqliteStorage {
  SqliteStorage() {
    init();
  }

  static const String _routesTableName = Routes.tableName;
  static const String _routePointsTableName = RoutePoints.tableName;
  static const String _geocodingCacheTableName = GeocodingCache.tableName;

  final DatabaseHelper _dbHelper = DatabaseHelper();
  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _dbHelper.database;
    return _database!;
  }

  /// Initialize database
  Future<void> init() async {
    _database = await _dbHelper.database;
  }

  /// Close database
  Future<void> close() async {
    await _dbHelper.close();
  }

  /// Create new route.
  ///
  /// [routePoint] - [RoutePoint] object to insert
  ///
  /// Returns inserted route id
  ///
  /// Throws [UnableInsertDatabaseException] if failed to insert route point
  Future<int> createRoute(RoutePoint routePoint) async {
    try {
      final db = await database;

      return await db.transaction((Transaction txn) async {
        final int routeId = await txn.insert(
          _routesTableName,
          <String, dynamic>{
            'start_time': DateTime.now().toIso8601String(),
            'status': 'active',
          },
        );

        await txn.insert(
          _routePointsTableName,
          <String, dynamic>{
            'route_id': routeId,
            'latitude': routePoint.latitude,
            'longitude': routePoint.longitude,
            'timestamp': routePoint.timestamp.toIso8601String(),
          },
        );

        return routeId;
      });
    } on DatabaseException catch (e) {
      throw UnableInsertDatabaseException(
        message: "Failed to insert route and route point: $e",
      );
    }
  }

  /// Insert route point into route.
  ///
  /// [routeId] - route id
  /// [routePoint] - [RoutePoint] object point to insert
  ///
  /// Returns inserted route point id
  ///
  /// Throws [UnableInsertDatabaseException] if unable to insert
  Future<int> insertRoutePoint(int routeId, RoutePoint routePoint) async {
    try {
      final db = await database;

      return await db.insert(
        _routePointsTableName,
        <String, dynamic>{
          'route_id': routeId,
          'latitude': routePoint.latitude,
          'longitude': routePoint.longitude,
          'address': routePoint.address,
          'timestamp': routePoint.timestamp.toIso8601String(),
        },
      );
    } on DatabaseException catch (e) {
      throw UnableInsertDatabaseException(
        message: "Failed to insert route point for route id $routeId: $e",
      );
    }
  }

  /// Get [Route] object with all points by id.
  ///
  /// [routeId] route id
  ///
  /// Returns [Route] object with route points
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<Route> getAllRoutePoints(int routeId) async {
    try {
      final db = await database;

      final List<Map<String, dynamic>> result = await db.query(
        _routePointsTableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      final routePoints = List<RoutePoint>.generate(
        result.length,
        (int index) => RoutePoint.fromMap(result[index]),
      );

      final route = await db.query(
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
    } on DatabaseException catch (e) {
      throw UnableExecuteQueryDatabaseException(
        message: 'Failed to get route points by route id: [$routeId]: $e',
      );
    }
  }

  /// Delete route by id.
  ///
  /// [routeId] - Id of the route to delete.
  ///
  /// Throws [UnableDeleteDatabaseException] if database operation fails.
  Future<void> deleteRouteById(int routeId) async {
    try {
      final db = await database;

      // await database.transaction((txn) async {
      //   // Ok
      //   await txn. execute(...);
      //
      //   // DON'T  use the database object in a transaction
      //   // this will deadlock!
      //   await database. execute(...);
      // });
      await db.transaction((Transaction txn) async {
        await txn.delete(
          _routePointsTableName,
          where: 'route_id = ?',
          whereArgs: [routeId],
        );

        await txn.delete(
          _routesTableName,
          where: 'id = ?',
          whereArgs: [routeId],
        );
      });
    } on DatabaseException catch (e) {
      throw UnableDeleteDatabaseException(
        message: 'Failed to delete route by id: [$routeId]: $e',
      );
    }
  }

  /// Change route status.
  ///
  /// [routeId] - Id of the route.
  /// [status] - Status of the route to change.
  ///
  /// Returns number of rows affected.
  ///
  /// Throws [UnableUpdateDatabaseException] if unable to update database.
  Future<int> changeRouteStatus(int routeId, String status) async {
    try {
      final db = await database;

      return await db.update(
        _routesTableName,
        where: 'id = ?',
        whereArgs: [routeId],
        <String, dynamic>{
          'status': status,
        },
      );
    } on DatabaseException catch (e) {
      throw UnableUpdateDatabaseException(
        message: 'Failed to update route [$routeId] status to [$status]: $e',
      );
    }
  }

  /// Get address from cache if available
  ///
  /// [location] - [Location] object of the point.
  /// [distance] - Max distance in meters.
  /// [limit] - Max amount of results.
  ///
  /// Returns string with address or null if not found.
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<String?> getAddressFromCache(
    Location location, [
    int distance = 20,
    int limit = 1,
  ]) async {
    try {
      final db = await database;
      final result = await db.rawQuery(
        '''
        @input_lat = ${location.latitude};
        @input_lng = ${location.longitude};
        @table = ${GeocodingCache.tableName};
        @distance = $distance;
        @limit = $limit;
        
        CREATE FUNCTION RADIANS(degrees DOUBLE) RETURNS DOUBLE
        BEGIN
          RETURN degrees * (3.14159265358979323846 / 180.0);
        END;
        
        SELECT 
        id, 
        address,
        usage_frequency,
        timestamp,
          (
            6371 * 1000 * acos(
              cos(
                RADIANS(input_lat)
              ) * cos(
                RADIANS(lat)
              ) * cos(
                RADIANS(lng) - RADIANS(input_lng)
              ) + sin(
                RADIANS(input_lat)
              ) * sin(
                RADIANS(lat)
              )
            )
          ) AS distance_meters 
        FROM 
          @table
        WHERE 
          (
            6371 * 1000 * acos(
              cos(
                RADIANS(input_lat)
              ) * cos(
                RADIANS(lat)
              ) * cos(
                RADIANS(lng) - RADIANS(input_lng)
              ) + sin(
                RADIANS(input_lat)
              ) * sin(
                RADIANS(lat)
              )
            )
          ) < @distance
        ORDER BY 
          distance_meters
        LIMIT 
          @limit;
        ''',
      );

      if (result.isEmpty) {
        return null;
      }

      final int usageFrequency = result.first['usage_frequency'] as int;

      await db.update(
        _geocodingCacheTableName,
        <String, dynamic>{
          'usage_frequency': usageFrequency + 1,
          'timestamp': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );

      return result.first['address'] as String;
    } on DatabaseException catch (e) {
      throw UnableExecuteQueryDatabaseException(
        message: 'Failed to execute query: $e',
      );
    }
  }

  /// Add new geocoding cache entry.
  ///
  /// [point] - [RoutePoint] object to add to cache.
  ///
  /// Throws [UnableInsertDatabaseException] if insertion fails.
  Future<int> addNewAddressToCache(RoutePoint point) async {
    try {
      final db = await database;

      return await db.insert(
        _geocodingCacheTableName,
        <String, dynamic>{
          'latitude': point.latitude,
          'longitude': point.longitude,
          'address': point.address,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on DatabaseException catch (e) {
      throw UnableInsertDatabaseException(
        message: "Failed to add new address to cache: $e",
      );
    }
  }

  /// Delete all geocoding cache entries.
  ///
  /// [hours] - Max age of entries in hours
  ///
  /// Throws [UnableDeleteDatabaseException] if deletion fails.
  Future<void> clearGeocodingCache([int hours = 168]) async {
    try {
      final db = await database;

      final timestamp = DateTime.now()
          .subtract(
            Duration(hours: hours),
          )
          .toIso8601String();

      await db.delete(
        _geocodingCacheTableName,
        where: 'timestamp < ?',
        whereArgs: [timestamp],
      );
    } on DatabaseException catch (e) {
      throw UnableDeleteDatabaseException(
        message: "Failed to clear geocoding cache: $e",
      );
    }
  }
}

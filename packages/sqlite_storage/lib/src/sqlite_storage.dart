import 'dart:developer';

import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'exceptions.dart';

class SqliteStorage {
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
  /// [point] - [Map] object of route point to insert
  ///
  /// Returns inserted route id
  ///
  /// Throws [UnableInsertDatabaseException] if failed to insert route point
  Future<int> createRoute(Map<String, dynamic> point) async {
    try {
      final db = await database;

      final timestamp = point['timestamp'] as DateTime;

      return await db.transaction((Transaction txn) async {
        final int routeId = await txn.insert(
          _routesTableName,
          <String, dynamic>{
            'start_time': timestamp.toIso8601String(),
            'status': 'active',
          },
        );

        await txn.insert(
          _routePointsTableName,
          <String, dynamic>{
            'route_id': routeId,
            'latitude': point['latitude'] as double,
            'longitude': point['longitude'] as double,
            'address': point['address'] as String,
            'timestamp': timestamp.toIso8601String(),
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
  /// [routePoint] - [Map] object of route point to insert
  ///
  /// Returns inserted route point id
  ///
  /// Throws [UnableInsertDatabaseException] if unable to insert
  Future<int> insertRoutePoint(
    int routeId,
    Map<String, dynamic> routePoint,
  ) async {
    try {
      final db = await database;

      final timestamp = routePoint['timestamp'] as DateTime;

      return await db.insert(
        _routePointsTableName,
        <String, dynamic>{
          'route_id': routeId,
          'latitude': routePoint['latitude'] as double,
          'longitude': routePoint['longitude'] as double,
          'address': routePoint['address'] as String,
          'timestamp': timestamp.toIso8601String(),
        },
      );
    } on DatabaseException catch (e) {
      throw UnableInsertDatabaseException(
        message: "Failed to insert route point for route id $routeId: $e",
      );
    }
  }

  /// Get route with all points by id.
  ///
  /// [routeId] route id
  ///
  /// Returns [Map] object with route points
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<Map<String, dynamic>?> getAllRoutePoints(int routeId) async {
    try {
      final db = await database;

      final List<Map<String, dynamic>> result = await db.query(
        _routePointsTableName,
        where: 'route_id = ?',
        whereArgs: [routeId],
        orderBy: 'id ASC',
      );

      final routePoints = List<Map<String, dynamic>>.generate(
        result.length,
        (int index) => result[index],
      );

      final route = await db.query(
        Routes.tableName,
        where: 'id = ?',
        whereArgs: [routeId],
      );

      return <String, dynamic>{
        ...route.first,
        'routePoints': routePoints,
      };
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
  /// [location] - [Map] object of the point.
  /// [distance] - Max distance in meters.
  /// [limit] - Max amount of results.
  ///
  /// Returns string with address or null if not found.
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<String?> getAddressFromCache(
    Map<String, dynamic> location, [
    int distance = 20,
    int limit = 1,
  ]) async {
    try {
      final db = await database;
      final latitude = location['latitude'] as double;
      final longitude = location['longitude'] as double;

      final result = await db.rawQuery(
        '''
        SELECT 
        id, 
        address,
        usage_frequency,
        timestamp,
          (
            6371 * 1000 * acos(
              cos(
                (? * (3.14159265358979323846 / 180.0))
              ) * cos(
                (latitude * (3.14159265358979323846 / 180.0))
              ) * cos(
                (longitude * (3.14159265358979323846 / 180.0)) - (? * (3.14159265358979323846 / 180.0))
              ) + sin(
                (? * (3.14159265358979323846 / 180.0))
              ) * sin(
                (latitude * (3.14159265358979323846 / 180.0))
              )
            )
          ) AS distance_meters 
        FROM 
          ?
        WHERE 
          (
            6371 * 1000 * acos(
              cos(
                (? * (3.14159265358979323846 / 180.0))
              ) * cos(
                (latitude * (3.14159265358979323846 / 180.0))
              ) * cos(
                (longitude * (3.14159265358979323846 / 180.0)) - (? * (3.14159265358979323846 / 180.0))
              ) + sin(
                (? * (3.14159265358979323846 / 180.0))
              ) * sin(
                (latitude * (3.14159265358979323846 / 180.0))
              )
            )
          ) < ?
        ORDER BY 
          distance_meters
        LIMIT 
          ?;
        ''',
        [
          location,
          location,
          location,
          _geocodingCacheTableName,
          location,
          location,
          location,
          distance,
          limit,
        ],
      );

      if (result.isEmpty) {
        return null;
      }

      final int usageFrequency = result.first['usage_frequency'] as int;

      final int resultCount = await db.update(
        _geocodingCacheTableName,
        <String, dynamic>{
          'usage_frequency': usageFrequency + 1,
          'timestamp': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [result.first['id']],
      );

      if (resultCount > 0) {
        log('Usage frequency increased: $usageFrequency');
      }

      return result.first['address'] as String;
    } on DatabaseException catch (e) {
      throw UnableExecuteQueryDatabaseException(
        message: 'Failed to execute query: $e',
      );
    }
  }

  /// Add new geocoding cache entry.
  ///
  /// [point] - [Map] object to add to cache.
  ///
  /// Throws [UnableInsertDatabaseException] if insertion fails.
  Future<int> addNewAddressToCache(Map<String, dynamic> locationAddress) async {
    try {
      final db = await database;

      return await db.insert(
        _geocodingCacheTableName,
        <String, dynamic>{
          'latitude': locationAddress['latitude'] as double,
          'longitude': locationAddress['longitude'] as double,
          'address': locationAddress['address'] as String,
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
  /// [maxAge] - [Duration] object of max age of entries
  ///
  /// Throws [UnableDeleteDatabaseException] if deletion fails.
  Future<int> clearGeocodingCache(Duration maxAge) async {
    try {
      final db = await database;

      final timestamp = DateTime.now().subtract(maxAge).toIso8601String();

      return await db.delete(
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

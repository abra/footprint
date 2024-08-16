import 'dart:math';

import 'package:sqflite/sqflite.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'database_helper.dart';

class SqliteStorage {
  SqliteStorage() {
    _init();
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
  Future<void> _init() async {
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
  /// Returns [RouteDTO] object with route points
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<RouteDTO?> getAllRoutePoints(int routeId) async {
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

      if (route.isEmpty) return null;

      final data = <String, dynamic>{
        ...route.first,
        'route_points': routePoints,
      };

      return RouteDTO.fromMap(data);
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

  /// Get nearest addresses of specified latitude and longitude from cache storage.
  ///
  /// [lat] - latitude<br />
  /// [lon] - longitude<br />
  ///
  /// Returns string with address or null if not found.
  ///
  /// Throws [UnableExecuteQueryDatabaseException] if unable to execute query
  Future<List<Map<String, dynamic>>> getNearestPlaces({
    required double lat,
    required double lon,
  }) async {
    try {
      final db = await database;
      final (latitudeIdx, longitudeIdx) = _getScaledValue(lat, lon);

      // There is some conversion error, but it still allows you to limit
      // the query fetching from the database
      final result = await db.query(
        _geocodingCacheTableName,
        where: 'latitude_idx BETWEEN ? AND ? AND longitude_idx BETWEEN ? AND ?',
        whereArgs: [
          latitudeIdx - 1,
          latitudeIdx + 1,
          longitudeIdx - 1,
          longitudeIdx + 1,
        ],
      );

      if (result.isEmpty) {
        return [];
      }

      return result;
    } on DatabaseException catch (e) {
      throw UnableExecuteQueryDatabaseException(
        message: 'Failed to execute query: $e',
      );
    }
  }

  (int, int) _getScaledValue(
    double latitude,
    double longitude, [
    int distanceInMeters = 50,
  ]) {
    const double latitudeDegreeInMeters = 111120;

    final latitudeScaleFactor = 1 / (distanceInMeters / latitudeDegreeInMeters);
    final latitudeIdx = (latitude * latitudeScaleFactor).round();

    final metersPerDegreeLongitude =
        latitudeDegreeInMeters * cos(latitude * pi / 180);

    final longitudeScaleFactor =
        1 / (distanceInMeters / metersPerDegreeLongitude);
    final longitudeIdx = (longitude * longitudeScaleFactor).round();

    return (latitudeIdx, longitudeIdx);
  }

  /// Update usage frequency and timestamp of geocoding cache entry.
  ///
  /// [placeAddressId] - Place address id of the entry to update
  ///
  /// Returns number of rows affected.
  Future<int> updatePlaceAddressInfoById(
    int placeAddressId,
    int newValue,
  ) async {
    try {
      final db = await database;

      return await db.update(
        _geocodingCacheTableName,
        <String, dynamic>{
          'usage_frequency': newValue,
          'timestamp': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [placeAddressId],
      );
    } on DatabaseException catch (e) {
      throw UnableUpdateDatabaseException(
        message:
            "Failed to update usage frequency to [$newValue] of address [$placeAddressId]: $e",
      );
    }
  }

  /// Add new geocoding cache entry.
  ///
  /// [placeAddress] - [PlaceAddressCM] model to add to cache.
  ///
  /// Throws [UnableInsertDatabaseException] if insertion fails.
  Future<int> addPlaceAddress(PlaceAddressCM placeAddress) async {
    try {
      final db = await database;

      final (latitudeIdx, longitudeIdx) = _getScaledValue(
        placeAddress.latitude,
        placeAddress.longitude,
      );

      return await db.insert(
        _geocodingCacheTableName,
        <String, dynamic>{
          'latitude': placeAddress.latitude,
          'longitude': placeAddress.longitude,
          'latitude_idx': latitudeIdx,
          'longitude_idx': longitudeIdx,
          'address': placeAddress.address,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );
    } on DatabaseException catch (e) {
      throw UnableInsertDatabaseException(
        message: "Failed to add new address to cache: $e",
      );
    }
  }

  /// Delete all geocoding cache entries older than [maxAge].
  ///
  /// [maxAge] - [Duration] object of max age of records to delete.
  ///
  /// Throws [UnableDeleteDatabaseException] if deletion fails.
  Future<int> clearGeocodingCache({required Duration maxAge}) async {
    try {
      final db = await database;

      final timestamp = DateTime.now().subtract(maxAge);

      return await db.delete(
        _geocodingCacheTableName,
        where: 'timestamp < ?',
        whereArgs: [timestamp.toIso8601String()],
      );
    } on DatabaseException catch (e) {
      throw UnableDeleteDatabaseException(
        message: "Failed to clear geocoding cache: $e",
      );
    }
  }
}

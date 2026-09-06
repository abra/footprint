import 'dart:math';

import 'package:sqflite/sqflite.dart';

import '../database_retry.dart';
import '../models/place_address_cm.dart';

class GeocodingCacheDao {
  const GeocodingCacheDao(this._db);

  final Database _db;

  Future<int> add({
    required String address,
    required double latitude,
    required double longitude,
  }) => retryOnDatabaseBusy(
    () => _db.insert('geocoding_cache', {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      // Retain the version 1 columns for existing databases.
      'latitude_idx': (latitude * 2222.4).round(),
      'longitude_idx': (longitude * 2222.4 * cos(latitude * pi / 180)).round(),
      'timestamp': DateTime.now().toIso8601String(),
    }),
  );

  Future<List<PlaceAddressCM>> nearby({
    required double latitude,
    required double longitude,
    required Duration maxAge,
  }) async {
    const latitudeDelta = 50 / 111120;
    final longitudeDelta =
        latitudeDelta / cos(latitude * pi / 180).abs().clamp(0.000001, 1);
    final minLongitude = longitude - longitudeDelta;
    final maxLongitude = longitude + longitudeDelta;
    final wraps = minLongitude < -180 || maxLongitude > 180;
    final rows = await _db.query(
      'geocoding_cache',
      where:
          'latitude BETWEEN ? AND ? AND '
          '${wraps ? '(longitude >= ? OR longitude <= ?)' : 'longitude BETWEEN ? AND ?'} '
          'AND timestamp >= ?',
      whereArgs: [
        latitude - latitudeDelta,
        latitude + latitudeDelta,
        minLongitude < -180 ? minLongitude + 360 : minLongitude,
        maxLongitude > 180 ? maxLongitude - 360 : maxLongitude,
        DateTime.now().subtract(maxAge).toIso8601String(),
      ],
    );
    return rows.map(PlaceAddressCM.fromMap).toList(growable: false);
  }

  Future<void> markUsed(int id) async {
    await retryOnDatabaseBusy(
      () => _db.rawUpdate(
        'UPDATE geocoding_cache SET usage_frequency = usage_frequency + 1 WHERE id = ?',
        [id],
      ),
    );
  }

  Future<int> clearOlderThan(Duration maxAge) => retryOnDatabaseBusy(
    () => _db.delete(
      'geocoding_cache',
      where: 'timestamp < ?',
      whereArgs: [DateTime.now().subtract(maxAge).toIso8601String()],
    ),
  );
}

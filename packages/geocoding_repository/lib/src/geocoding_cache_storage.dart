import 'dart:isolate';
import 'dart:math';

import 'package:sqlite_storage/sqlite_storage.dart';

class GeocodingCacheStorage {
  const GeocodingCacheStorage({
    required SqliteStorage sqliteStorage,
    Duration? cacheMaxAge,
  })  : _sqliteStorage = sqliteStorage,
        _cacheMaxAge = cacheMaxAge ?? const Duration(days: 7);

  final SqliteStorage _sqliteStorage;
  final Duration _cacheMaxAge;

  Future<int> addAddressToCache(LocationAddressCM locationAddress) async {
    return await _sqliteStorage.addAddressToCache(locationAddress);
  }

  Future<LocationAddressCM?> getAddressFromCache({
    required double lat,
    required double lon,
    double distance = 15,
    double limit = 1,
  }) async {
    final result = await _sqliteStorage.getNearestAddressListFromCache(
      lat: lat,
      lon: lon,
    );

    if (result.isEmpty) return null;

    final nearestResult = await Isolate.run(
      () => _getNearestAddress(
        result,
        lat,
        lon,
        distance,
        limit,
      ),
    );

    if (nearestResult.isEmpty) {
      return null;
    }

    final int usageFrequency = nearestResult['usage_frequency'] as int;

    await _sqliteStorage.updateCacheInfoByAddressId(
      nearestResult['id'] as int,
      usageFrequency + 1,
    );

    return LocationAddressCM.fromMap(nearestResult);
  }

  Future<Map<String, dynamic>> _getNearestAddress(
    List<Map<String, dynamic>> result,
    double lat,
    double lon,
    double distance,
    double limit,
  ) async {
    // logger.log('Isolate: _getNearestAddress started');
    List<Map<String, dynamic>> filteredCoordinates = result
        .where((e) =>
            _calculateDistance(
              lat,
              lon,
              e['latitude'] as double,
              e['longitude'] as double,
            ) <=
            distance)
        .map((e) => <String, dynamic>{
              ...e,
              'distance': _calculateDistance(
                lat,
                lon,
                e['latitude'] as double,
                e['longitude'] as double,
              ),
            })
        .toList();

    if (filteredCoordinates.isEmpty) {
      return {};
    }

    filteredCoordinates.sort(
      (a, b) => (a['distance'] as double).compareTo((b['distance'] as double)),
    );

    // logger.log('5> GET FROM CACHE: ${filteredCoordinates.first['address']}');
    // logger.log('Isolate: _getNearestAddress finished');

    return filteredCoordinates.first;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;

    double dLat = _toRadians(lat2 - lat1);
    double dLon = _toRadians(lon2 - lon1);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    double distanceInKilometers = earthRadius * c;
    return distanceInKilometers * 1000;
  }

  double _toRadians(double degrees) {
    return degrees * pi / 180;
  }

  Future<int> clearCache() async =>
      await _sqliteStorage.clearGeocodingCache(_cacheMaxAge);
}

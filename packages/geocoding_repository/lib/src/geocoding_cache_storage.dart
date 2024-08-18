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

  /// Add new geocoding cache entry.
  ///
  /// [address] - Address of the entry<br />
  /// [lat] - Latitude of the entry<br />
  /// [lon] - Longitude of the entry
  ///
  /// Returns number of rows affected.
  Future<int> addPlaceAddress({
    required String address,
    required double lat,
    required double lon,
  }) async =>
      await _sqliteStorage.addPlaceAddressToCache(
        address: address,
        lat: lat,
        lon: lon,
      );

  /// Get the nearest address to the coordinates from the cache.
  ///
  /// [lat] - latitude<br />
  /// [lon] - longitude<br />
  /// [distance] - Maximum distance in meters to the nearest address<br />
  /// [limit] - The maximum number of addresses to return
  ///
  /// Returns the nearest address as [PlaceAddressCM] or null if not found.
  Future<PlaceAddressCM?> getPlaceAddress({
    required double lat,
    required double lon,
    double distance = 15,
    double limit = 1,
  }) async {
    final places = await _sqliteStorage.fetchNearestPlaces(
      lat: lat,
      lon: lon,
    );

    if (places.isEmpty) return null;

    final nearestPlace = await _getNearestPlaceAddress(
      places,
      lat,
      lon,
      distance,
      limit,
    );

    if (nearestPlace == null) {
      return null;
    }

    await _sqliteStorage.updatePlaceAddressCache(
      nearestPlace.id,
      nearestPlace.usageFrequency + 1,
    );

    return nearestPlace;
  }

  Future<PlaceAddressCM?> _getNearestPlaceAddress(
    List<PlaceAddressCM> cachedPlaceList,
    double lat,
    double lon,
    double distance,
    double limit,
  ) async {
    double minDistance = distance;
    PlaceAddressCM? nearestPlaceAddress;

    for (var place in cachedPlaceList) {
      double dist = _calculateDistance(
        lat,
        lon,
        place.latitude,
        place.longitude,
      );

      if (dist <= minDistance) {
        minDistance = dist;
        nearestPlaceAddress = place;
      }
    }

    return nearestPlaceAddress;
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

  /// Delete all cache entries older than [maxAge].
  ///
  /// Returns number of rows affected.
  Future<int> clearCache() async =>
      await _sqliteStorage.deleteOldCacheEntries(maxAge: _cacheMaxAge);
}

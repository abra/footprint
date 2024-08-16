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

  Future<int> addPlaceAddress(PlaceAddressCM placeAddress) async {
    return await _sqliteStorage.addPlaceAddressToCache(placeAddress);
  }

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
    List<Map<String, dynamic>> cachedPlaces,
    double lat,
    double lon,
    double distance,
    double limit,
  ) async {
    List<Map<String, dynamic>> filteredPlaces = [];

    for (var place in cachedPlaces) {
      double eLat = place['latitude'] as double;
      double eLon = place['longitude'] as double;
      double dist = _calculateDistance(lat, lon, eLat, eLon);

      if (dist <= distance) {
        Map<String, dynamic> e = <String, dynamic>{
          ...place,
          'distance': dist,
        };

        filteredPlaces.add(e);
      }
    }

    if (filteredPlaces.isEmpty) {
      return null;
    }

    filteredPlaces.sort(
      (a, b) => (a['distance'] as double).compareTo((b['distance'] as double)),
    );

    return PlaceAddressCM.fromMap(filteredPlaces.first);
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
      await _sqliteStorage.deleteOldCacheEntries(maxAge: _cacheMaxAge);
}

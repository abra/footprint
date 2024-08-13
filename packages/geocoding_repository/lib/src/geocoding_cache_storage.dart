import 'package:sqlite_storage/sqlite_storage.dart';

class GeocodingCacheStorage {
  const GeocodingCacheStorage({
    required this.sqliteStorage,
    Duration? cacheMaxAge,
  }) : _cacheMaxAge = cacheMaxAge ?? const Duration(days: 7);

  final SqliteStorage sqliteStorage;
  final Duration _cacheMaxAge;

  Future<int> addAddressToCache(LocationAddressCM locationAddress) async {
    return await sqliteStorage.addAddressToCache(locationAddress);
  }

  Future<LocationAddressCM?> getAddressFromCache({
    required double lat,
    required double lon,
  }) async {
    return await sqliteStorage.getAddressFromCache(
      latitude: lat,
      longitude: lon,
    );
  }

  Future<int> clearCache() async =>
      await sqliteStorage.clearGeocodingCache(_cacheMaxAge);
}

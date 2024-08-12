import 'package:sqlite_storage/sqlite_storage.dart';

class GeocodingCacheStorage {
  const GeocodingCacheStorage({
    required this.sqliteStorage,
    Duration? cacheMaxAge,
  }) : _cacheMaxAge = cacheMaxAge ?? const Duration(days: 7);

  final SqliteStorage sqliteStorage;
  final Duration _cacheMaxAge;

  Future<int> addAddressToCache(Map<String, dynamic> locationAddress) async =>
      await sqliteStorage.addNewAddressToCache(locationAddress);


  Future<String?> getAddressFromCache(Map<String, dynamic> location) async =>
      await sqliteStorage.getAddressFromCache(location);


  Future<int> clearCache() async =>
      await sqliteStorage.clearGeocodingCache(_cacheMaxAge);

}
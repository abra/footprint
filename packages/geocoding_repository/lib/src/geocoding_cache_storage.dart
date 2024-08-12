import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class GeocodingCacheStorage {
  GeocodingCacheStorage({
    required this.sqliteStorage,
    Duration? cacheMaxAge,
  }) : _cacheMaxAge = cacheMaxAge ?? const Duration(days: 7);

  final SqliteStorage sqliteStorage;
  final Duration _cacheMaxAge;

  Future<int> addAddressToCache(Map<String, dynamic> locationAddress) async {
    return await sqliteStorage.addNewAddressToCache(locationAddress);
  }

  Future<String?> getAddressFromCache(Map<String, dynamic> location) async {
    return await sqliteStorage.getAddressFromCache(location);
  }

  Future<int> clearCache() async {
    return await sqliteStorage.clearGeocodingCache(_cacheMaxAge);
  }
}

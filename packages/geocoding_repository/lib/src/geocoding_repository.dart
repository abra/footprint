import 'package:domain_models/domain_models.dart';
import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'geocoding_cache_storage.dart';
import 'geocoding_service.dart';
import 'mappers/mappers.dart';

class GeocodingRepository {
  GeocodingRepository({
    required SqliteStorage sqliteStorage,
    @visibleForTesting GeocodingCacheStorage? cacheStorage,
    @visibleForTesting GeocodingService? geocodingService,
  })  : _geocodingService = geocodingService ?? GeocodingService(),
        _geocodingCacheStorage = cacheStorage ??
            GeocodingCacheStorage(
              sqliteStorage: sqliteStorage,
            );

  final GeocodingService _geocodingService;
  final GeocodingCacheStorage _geocodingCacheStorage;

  Future<PlaceAddressModel?> getAddressFromCoordinates(
    LocationModel location,
  ) async {
    final latitude = location.latitude;
    final longitude = location.longitude;

    try {
      final cachedAddress = await _geocodingCacheStorage.getPlaceAddress(
        lat: latitude,
        lon: longitude,
      );

      if (cachedAddress != null) {
        return cachedAddress.toDomainModel();
      }

      final geocodedAddress = await _geocodingService.reverseGeocoding(
        lat: latitude,
        lon: longitude,
      );

      if (geocodedAddress != null) {
        await _geocodingCacheStorage.addPlaceAddress(
          <String, dynamic>{
            'address': geocodedAddress,
            'latitude': latitude,
            'longitude': longitude,
          },
        );

        return PlaceAddressModel(
          address: geocodedAddress,
          latitude: latitude,
          longitude: longitude,
        );
      }
      return null;
    } catch (e, s) {
      throw CouldNotGetPlaceAddressException(
        message: 'Could not get place address from $latitude, $longitude: $e',
        stackTrace: s,
      );
    }
  }
}

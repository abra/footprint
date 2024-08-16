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

  Future<LocationAddressModel> getAddressFromCoordinates(
    LocationModel location,
  ) async {
    final latitude = location.latitude;
    final longitude = location.longitude;

    try {
      // log('0> GET ADDRESS FROM COORDINATES: $latitude, $longitude');

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

      final added = await _geocodingCacheStorage.addPlaceAddress(
        PlaceAddressCM.fromMap({
          'address': geocodedAddress,
          'latitude': latitude,
          'longitude': longitude,
        }),
      );

      // if (added > 0) {
      //   log('6> PUT ADDRESS TO CACHE: $geocodedAddress [$latitude, $longitude]');
      // }

      return LocationAddressModel(
        address: geocodedAddress,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      throw CouldNotGetLocationAddressException(
        message: 'Could not get place address from $latitude, $longitude: $e',
      );
    }
  }
}

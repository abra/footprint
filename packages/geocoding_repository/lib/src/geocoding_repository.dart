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
      // TODO: Implement an algorithm for location address retrieval policy

      // It is necessary to implement an algorithm to get the address
      // (LocationAddress) of a place by coordinates (latitude, longitude)
      // through GeocodingService or get it from GeocodingCacheStorage cache,
      // taking into account the requirements that Google and Apple have
      // for geocoding, but at the same time not to mislead the user when
      // the received address does not correspond to the real address.

      final cachedAddress = await _geocodingCacheStorage.getAddressFromCache(
        lat: latitude,
        lon: longitude,
      );

      if (cachedAddress != null) {
        return cachedAddress.toDomainModel();
      }

      final placemark = await _geocodingService.getPlacemark(
        lat: latitude,
        lon: longitude,
      );

      if (placemark != null) {
        final locationAddress = placemark.toDomainModel();

        if (locationAddress != null) {
          final address = locationAddress;
          await _geocodingCacheStorage.addAddressToCache(
            LocationAddressCM.fromMap({
              'address': address,
              'latitude': latitude,
              'longitude': longitude,
            }),
          );
          return LocationAddressModel(
            address: address,
            latitude: latitude,
            longitude: longitude,
          );
        }
      }

      // if failed to get address in cache or service
      // just return the coordinates
      return LocationAddressModel(
        address: '$latitude, $longitude',
        latitude: latitude,
        longitude: longitude,
      );
    } catch (e) {
      // TODO: Need to able to pass exception and stackTrace
      throw CouldNotGetLocationAddressException(
        message: 'Could not get place address from $latitude, $longitude: $e',
      );
    }
  }
}

import 'package:domain_models/domain_models.dart';
import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'geocoding_cache_storage.dart';
import 'geocoding_service.dart';
import 'mappers/placemark_to_domain.dart';

class GeocodingRepository {
  GeocodingRepository({
    required SqliteStorage sqliteStorage,
    @visibleForTesting GeocodingCacheStorage? cacheStorage,
    @visibleForTesting GeocodingService? geocodingService,
  })  : _geocodingService = geocodingService ?? const GeocodingService(),
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
      // TODO: Implement an algorithm to get the address of a place by latitude,
      // TODO: longitude
      // It is necessary to implement an algorithm to get the address
      // (LocationAddress) of a place by coordinates (latitude, longitude)
      // through GeocodingService or get it from GeocodingCacheStorage cache,
      // taking into account the requirements that Google and Apple have
      // for geocoding, but at the same time not to mislead the user when
      // the received address does not correspond to the real address.

      final cachedAddress = await _geocodingCacheStorage.getAddressFromCache(
        <String, dynamic>{
          'latitude': latitude,
          'longitude': longitude,
        },
      );

      if (cachedAddress != null) {
        return LocationAddressModel(address: cachedAddress);
      }

      final placemarkList = await _geocodingService.getPlacemarkList(
        latitude,
        longitude,
      );

      final locationAddress = placemarkList.first.toDomainModel();

      if (locationAddress.address != null) {
        final address = locationAddress.address;
        await _geocodingCacheStorage.addAddressToCache(
          <String, dynamic>{
            'latitude': latitude,
            'longitude': longitude,
            'address': address,
          },
        );
      }

      return locationAddress;
    } catch (e) {
      // TODO: Need to able to pass exception and stackTrace
      throw CouldNotGetLocationAddressException(
        message: 'Could not get place address from $latitude, $longitude: $e',
      );
    }
  }
}

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
        _cacheStorage = cacheStorage ??
            GeocodingCacheStorage(
              sqliteStorage: sqliteStorage,
            );

  final GeocodingService _geocodingService;
  final GeocodingCacheStorage _cacheStorage;

  Future<LocationAddress> getAddressFromCoordinates(Location location) async {
    final lat = location.latitude;
    final lon = location.longitude;
    try {
      // TODO: Implement an algorithm to get the address of a place by lat, lon
      // It is necessary to implement an algorithm to get the address
      // (LocationAddress) of a place by coordinates (lat, lon) through
      // GeocodingService or get it from GeocodingCacheStorage cache,
      // taking into account the requirements that Google and Apple have
      // for geocoding, but at the same time not to mislead the user when
      // the received address does not correspond to the real address.

      // TODO: Replace with proper handling for geocodingRepository
      final placemarkList = await _geocodingService.getPlacemarkList(lat, lon);
      final locationAddress = placemarkList.first.toDomainModel();

      return locationAddress;
    } catch (e) {
      // TODO: Need to able to pass exception and stackTrace
      throw CouldNotGetPlaceAddressException(
        message: 'Could not get place address from $lat, $lon: $e',
      );
    }
  }
}

import 'package:domain_models/domain_models.dart';
import 'package:geocoding_repository/src/mappers/placemark_to_domain.dart';
import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'geocoding_service.dart';

class GeocodingRepository {
  const GeocodingRepository({
    required this.storage,
    @visibleForTesting GeocodingService? geocodingService,
  }) : _geocodingService = geocodingService ?? const GeocodingService();

  final GeocodingService _geocodingService;
  final SqliteStorage storage;

  Future<LocationAddress> getLocationAddress(Location location) async {
    final lat = location.latitude;
    final lon = location.longitude;
    try {
      final placemarkList = await _geocodingService.getPlacemarkList(lat, lon);
      return placemarkList.first.toDomainModel(lat, lon);
    } catch (e) {
      throw CouldNotGetPlaceAddressException();
    }
  }
}

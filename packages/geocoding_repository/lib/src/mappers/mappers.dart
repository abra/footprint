import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

extension LocationAddressToDomain on PlaceAddressCM {
  LocationAddressModel toDomainModel() => LocationAddressModel(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
}

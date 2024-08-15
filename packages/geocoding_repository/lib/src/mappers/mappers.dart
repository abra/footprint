import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

extension LocationAddressToCM on LocationAddressModel {
  LocationAddressCM toCacheModel() => LocationAddressCM(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
}

extension LocationAddressToDomain on LocationAddressCM {
  LocationAddressModel toDomainModel() => LocationAddressModel(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
}

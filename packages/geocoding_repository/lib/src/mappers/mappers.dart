import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

extension PlaceAddressToDomain on PlaceAddressCM {
  PlaceAddressDM toDomainModel() => PlaceAddressDM(
        address: address,
        latitude: latitude,
        longitude: longitude,
      );
}

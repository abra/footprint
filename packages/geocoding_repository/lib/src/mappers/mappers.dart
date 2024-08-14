import 'package:domain_models/domain_models.dart';
import 'package:geocoding/geocoding.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

extension PlacemarkToAddress on Placemark {
  String? toDomainModel() {
    if (street != null) {
      return street;
    }
    if (subThoroughfare != null && thoroughfare != null) {
      return '$subThoroughfare, $thoroughfare';
    }
    if (subThoroughfare == null && thoroughfare != null) {
      return '$thoroughfare';
    }
    if (subLocality != null && locality != null) {
      return '$subLocality, $locality';
    }
    if (subLocality == null && locality != null) {
      return locality;
    }
    if (subAdministrativeArea != null && administrativeArea != null) {
      return '$subAdministrativeArea, $administrativeArea';
    }
    if (subAdministrativeArea == null && administrativeArea != null) {
      return administrativeArea;
    }
    if (country != null) {
      return country;
    }

    return null;
  }
}

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

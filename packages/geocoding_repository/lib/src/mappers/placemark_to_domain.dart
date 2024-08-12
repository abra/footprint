import 'package:domain_models/domain_models.dart';
import 'package:geocoding/geocoding.dart';

extension PlacemarkToDomain on Placemark {
  // TODO: Replace with a more thoughtful version of address drafting
  LocationAddressModel toDomainModel() {
    if (street != null) {
      return LocationAddressModel(address: street);
    }
    if (subThoroughfare != null && thoroughfare != null) {
      return LocationAddressModel(address: '$subThoroughfare, $thoroughfare');
    }
    if (subThoroughfare == null && thoroughfare != null) {
      return LocationAddressModel(address: '$thoroughfare');
    }
    if (subLocality != null && locality != null) {
      return LocationAddressModel(address: '$subLocality, $locality');
    }
    if (subLocality == null && locality != null) {
      return LocationAddressModel(address: locality);
    }
    if (subAdministrativeArea != null && administrativeArea != null) {
      return LocationAddressModel(
        address: '$subAdministrativeArea, $administrativeArea',
      );
    }
    if (subAdministrativeArea == null && administrativeArea != null) {
      return LocationAddressModel(address: administrativeArea);
    }
    if (country != null) {
      return LocationAddressModel(address: country);
    }

    return LocationAddressModel(address: null);
  }
}

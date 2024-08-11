import 'package:domain_models/domain_models.dart';
import 'package:geocoding/geocoding.dart';

extension PlacemarkToDomain on Placemark {
  // TODO: Replace with a more thoughtful version of address drafting
  LocationAddress toDomainModel() {
    if (street != null) {
      return LocationAddress(address: street);
    }
    if (subThoroughfare != null && thoroughfare != null) {
      return LocationAddress(address: '$subThoroughfare, $thoroughfare');
    }
    if (subThoroughfare == null && thoroughfare != null) {
      return LocationAddress(address: '$thoroughfare');
    }
    if (subLocality != null && locality != null) {
      return LocationAddress(address: '$subLocality, $locality');
    }
    if (subLocality == null && locality != null) {
      return LocationAddress(address: locality);
    }
    if (subAdministrativeArea != null && administrativeArea != null) {
      return LocationAddress(
        address: '$subAdministrativeArea, $administrativeArea',
      );
    }
    if (subAdministrativeArea == null && administrativeArea != null) {
      return LocationAddress(address: administrativeArea);
    }
    if (country != null) {
      return LocationAddress(address: country);
    }

    return LocationAddress(address: null);
  }
}

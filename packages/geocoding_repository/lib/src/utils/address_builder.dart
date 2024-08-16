import 'package:geocoding/geocoding.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

class AddressBuilder {
  AddressBuilder({
    this.maxAddressLength = 40,
  });

  final int maxAddressLength;

  /// Builds display name from Nominatim API [Place] object
  ///
  /// [place] - Nominatim API [Place] object
  ///
  /// Returns address string
  String buildAddressFromNominatim(Place place) {
    final address = place.address!;

    List<String> components = [];
    int currentLength = 0;

    void addIfContains(String key) {
      if (address.containsKey(key)) {
        String component = address[key] as String;
        int newLength = currentLength +
            component.length +
            (components.isEmpty ? 0 : 2); // 2 - , + space
        if (newLength <= maxAddressLength) {
          components.add(component);
          currentLength = newLength;
        }
      }
    }

    // Address details
    addIfContains('house_number');
    addIfContains('house_name');
    addIfContains('road');
    addIfContains('city_block');
    addIfContains('residential');
    addIfContains('farm');
    addIfContains('farmyard');
    addIfContains('industrial');
    addIfContains('commercial');
    addIfContains('retail');
    addIfContains('amenity');
    addIfContains('place');
    addIfContains('tourism');
    addIfContains('leisure');
    addIfContains('shop');
    addIfContains('office');

    // Lower level details
    addIfContains('hamlet');
    addIfContains('croft');
    addIfContains('isolated_dwelling');
    addIfContains('neighbourhood');
    addIfContains('allotments');
    addIfContains('quarter');

    // Middle level details
    addIfContains('subdivision');
    addIfContains('city_district');
    addIfContains('borough');
    addIfContains('district');
    addIfContains('suburb');
    addIfContains('village');
    addIfContains('town');
    addIfContains('city');
    addIfContains('municipality');

    // Higher level details
    addIfContains('county');
    addIfContains('state_district');
    addIfContains('state');
    addIfContains('region');
    addIfContains('country');
    addIfContains('continent');

    return components.join(', ');
  }

  /// Builds display name from [Placemark] object
  ///
  /// [placemark] - [Placemark] object
  ///
  /// Returns address string
  String buildAddressFromPlacemark(Placemark placemark) {
    List<String> components = [];
    int currentLength = 0;

    void addIfNotEmpty(String? component) {
      if (component != null && component.isNotEmpty) {
        int newLength =
            currentLength + component.length + (components.isEmpty ? 0 : 2);
        if (newLength <= maxAddressLength) {
          components.add(component);
          currentLength = newLength;
        }
      }
    }

    addIfNotEmpty(placemark.subThoroughfare);
    addIfNotEmpty(placemark.thoroughfare);
    addIfNotEmpty(placemark.subLocality);
    addIfNotEmpty(placemark.locality);
    addIfNotEmpty(placemark.subAdministrativeArea);
    addIfNotEmpty(placemark.administrativeArea);
    addIfNotEmpty(placemark.country);

    return components.join(', ');
  }
}

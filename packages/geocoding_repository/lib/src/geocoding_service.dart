import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:osm_nominatim/osm_nominatim.dart';

import 'utils/address_builder.dart';

/// [GeocodingService] class used as a wrapper for geocoding services
///
/// Provides platform geocoding services from [geocoding] package if available,
/// otherwise it provides services from [osm_nominatim] (Nominatim API) as a fallback
class GeocodingService {
  static DateTime? _lastNominatimCall;
  final _addressBuilder = AddressBuilder();

  /// Get address from coordinates
  ///
  /// [lat] - location latitude
  /// [lon] - location longitude
  ///
  /// Returns address as a [String]
  Future<String?> reverseGeocoding({
    required double lat,
    required double lon,
  }) async {
    try {
      final placemark = await _getPlacemark(lat, lon);
      if (placemark != null) {
        return _addressBuilder.buildAddressFromPlacemark(placemark);
      }

      final place = await _getPlace(lat, lon);
      if (place != null) {
        return _addressBuilder.buildAddressFromNominatim(place);
      }
      return '$lat, $lon';
    } on Exception {
      final place = await _getPlace(lat, lon);
      if (place != null) {
        return _addressBuilder.buildAddressFromNominatim(place);
      }
    }
    return null;
  }

  Future<Placemark?> _getPlacemark(double lat, double lon) async {
    final placemarkList = await placemarkFromCoordinates(lat, lon);
    return placemarkList.firstWhere(
      (placemark) => placemark.name != null,
    );
  }

  Future<Place?> _getPlace(double lat, double lon) async {
    final inRateLimit = (_lastNominatimCall != null &&
        DateTime.now().difference(_lastNominatimCall!).inMilliseconds >= 1200);
    final canCallNominatimAPI = inRateLimit || _lastNominatimCall == null;

    /// Delays Nominatim API call if it has been called less than
    /// 1200 milliseconds ago to avoid rate limiting
    if (!canCallNominatimAPI) {
      final timeSinceLastCall = DateTime.now().difference(_lastNominatimCall!);
      if (timeSinceLastCall.inMilliseconds <= 1200) {
        await Future.delayed(
          Duration(
            milliseconds: (1200 - timeSinceLastCall.inMilliseconds),
          ),
        );
      }
    }

    final reverseSearch = await Nominatim.reverseSearch(
      lat: lat,
      lon: lon,
      addressDetails: true,
      nameDetails: true,
    );

    _lastNominatimCall = DateTime.now();

    return reverseSearch;
  }
}

import 'package:geocoding/geocoding.dart';

class GeocodingService {
  const GeocodingService();

  Future<Placemark?> getPlacemark({
    required double lat,
    required double lon,
  }) async {
    final placemarkList= await placemarkFromCoordinates(lat, lon);
    if (placemarkList.isEmpty) return null;
    return placemarkList.first;
  }
}

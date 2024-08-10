import 'package:geocoding/geocoding.dart';

class GeocodingService {
  const GeocodingService();

  Future<List<Placemark>> getPlacemarkList(double lat, double lon) async {
    return await placemarkFromCoordinates(lat, lon);
  }
}

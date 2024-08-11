import 'package:domain_models/domain_models.dart';
import 'package:geocoding/geocoding.dart';

extension PlacemarkToDomain on Placemark {
  PlaceAddress toDomainModel(double lat, double lon, [DateTime? timeStamp]) =>
      PlaceAddress(
        timestamp: timeStamp ?? DateTime.now(),
        latitude: lat,
        longitude: lon,
        name: name ?? '',
        locality: locality ?? '',
        administrativeArea: administrativeArea ?? '',
        country: country ?? '',
        postalCode: postalCode ?? '',
        subAdministrativeArea: subAdministrativeArea ?? '',
        subLocality: subLocality ?? '',
        subThoroughfare: subThoroughfare ?? '',
        thoroughfare: thoroughfare ?? '',
      );
}
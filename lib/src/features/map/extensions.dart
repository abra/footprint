import 'package:footprint/src/domain_models/location.dart';
import 'package:latlong2/latlong.dart';

extension LocationToLatLng on Location {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

import 'package:domain_models/domain_models.dart';
import 'package:latlong2/latlong.dart';

extension LocationToLatLng on LocationDM {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

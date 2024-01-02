import 'package:geolocator/geolocator.dart';

import 'models/exceptions.dart';

class LocationService {
  LocationService();

  static bool _serviceEnabled = false;
  static LocationPermission _permission = LocationPermission.denied;

  Future<void> checkServiceAndPermissions() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_serviceEnabled) {
      throw LocationSrvcDisabledException();
    }

    if (_serviceEnabled) {
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();

        if (_permission == LocationPermission.denied) {
          throw LocationPermissionDeniedException();
        }
      }

      if (_permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately.
        throw LocationPermissionsPermanentlyDeniedException();
      }
    }
  }
}

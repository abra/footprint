import 'package:footprint/src/domain_models/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'models/exceptions.dart';

class LocationService {
  LocationService();

  static bool _serviceEnabled = false;
  static LocationPermission _permission = LocationPermission.denied;

  Future<void> checkServiceAndPermissions() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_serviceEnabled) {
      throw ServiceDisabledLocationServiceException();
    }

    if (_serviceEnabled) {
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        _permission = await Geolocator.requestPermission();

        if (_permission == LocationPermission.denied) {
          throw PermissionDeniedLocationServiceException();
        }
      }

      if (_permission == LocationPermission.deniedForever) {
        // Permissions are denied forever, handle appropriately,
        // until the user updates the permission in the App settings.
        throw PermissionsPermanentlyDeniedLocationServiceException();
      }
    }
  }

  Stream<Location> getLocationUpdatesStream() async* {
    await checkServiceAndPermissions();

    await for (final Position position in Geolocator.getPositionStream()) {
      yield Location(
        id: const Uuid().v1(),
        timestamp: position.timestamp,
        latitude: position.latitude,
        longitude: position.longitude,
      );
    }
  }

  Future<Location> determineLocation() async {
    await checkServiceAndPermissions();

    final Position position = await Geolocator.getCurrentPosition();

    return Location(
      id: const Uuid().v1(),
      timestamp: position.timestamp,
      latitude: position.latitude,
      longitude: position.longitude,
    );
  }

  Future<double> calculateDistance(
    Location start,
    Location end,
  ) async {
    final double distance = Geolocator.distanceBetween(
      start.latitude,
      start.longitude,
      end.latitude,
      end.longitude,
    );

    return distance;
  }
}

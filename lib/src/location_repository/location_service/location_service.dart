import 'package:footprint/src/domain_models/location.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import 'models/exceptions.dart';

class LocationService {
  LocationService({
    Duration? updateInterval,
  }) : _updateInterval = updateInterval ?? const Duration(seconds: 2);

  static bool _serviceEnabled = false;
  static LocationPermission _permission = LocationPermission.denied;
  final Duration _updateInterval;

  Future<void> _checkServiceAndPermissions() async {
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

  Stream<Position> getLocationUpdatesStream() async* {
    await _checkServiceAndPermissions();

    try {
      await for (final Position position in Geolocator.getPositionStream(
        locationSettings: LocationSettings(timeLimit: _updateInterval),
      )) {
        yield position;
      }
    } catch (e) {
      throw ServiceDisabledLocationServiceException();
    }
  }

  Future<Position> determineLocation() async {
    await _checkServiceAndPermissions();

    try {
      final Position position = await Geolocator.getCurrentPosition(
        timeLimit: _updateInterval,
      );

      return position;
    } catch (e) {
      throw ServiceDisabledLocationServiceException();
    }
  }

  Future<double> calculateDistance(
    Location start,
    Location end,
  ) async {
    try {
      final double distance = Geolocator.distanceBetween(
        start.latitude,
        start.longitude,
        end.latitude,
        end.longitude,
      );

      return distance;
    } catch (e) {
      throw UnableCalculateDistanceLocationServiceException();
    }
  }
}

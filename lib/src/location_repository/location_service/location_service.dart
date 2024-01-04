import 'package:geolocator/geolocator.dart';

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
    } on PermissionDeniedException {
      throw PermissionDeniedLocationServiceException();
    } on LocationServiceDisabledException {
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
    } on PermissionDeniedException {
      throw PermissionDeniedLocationServiceException();
    } on LocationServiceDisabledException {
      throw ServiceDisabledLocationServiceException();
    }
  }

  Future<double> calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async {
    try {
      final double distance = Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );

      return distance;
    } catch (e) {
      throw UnableCalculateDistanceLocationServiceException();
    }
  }
}

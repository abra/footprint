import 'package:geolocator/geolocator.dart';

import 'models/exceptions.dart';

/// Provides access to the device's location.
class LocationService {
  const LocationService({
    Duration? timeLimit,
  }) : _timeLimit = timeLimit ?? const Duration(seconds: 0);

  /// Whether location service is enabled on the device.
  static bool _serviceEnabled = false;

  /// The current location permission status.
  static LocationPermission _permission = LocationPermission.denied;

  /// The location service update interval.
  final Duration _timeLimit;

  /// Checks if location services are enabled and location permission is granted.
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

  /// Gets a stream of location updates based on the desired update interval.
  Stream<Position> getLocationUpdatesStream() async* {
    await _checkServiceAndPermissions();

    final locationSettings = LocationSettings(
      timeLimit: _timeLimit,
    );

    try {
      await for (final Position position in Geolocator.getPositionStream(
        locationSettings: locationSettings,
      )) {
        yield position;
      }
    } on PermissionDeniedException {
      throw PermissionDeniedLocationServiceException();
    } on LocationServiceDisabledException {
      throw ServiceDisabledLocationServiceException();
    }
  }

  /// Gets the current location of the device.
  Future<Position> determineLocation() async {
    await _checkServiceAndPermissions();

    try {
      final Position position = await Geolocator.getCurrentPosition(
        timeLimit: _timeLimit,
      );

      return position;
    } on PermissionDeniedException {
      throw PermissionDeniedLocationServiceException();
    } on LocationServiceDisabledException {
      throw ServiceDisabledLocationServiceException();
    }
  }

  /// Calculates the distance between two locations in meters.
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

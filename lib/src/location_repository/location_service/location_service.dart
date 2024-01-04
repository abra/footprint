import 'package:geolocator/geolocator.dart';

import 'models/exceptions.dart';

/// Provides access to the device's location.
class LocationService {
  /// Creates a [LocationService] with the given update interval.
  ///
  /// The [updateInterval] determines the desired update interval when
  /// requesting continuous location updates using [getLocationUpdatesStream].
  /// The default is 2 seconds if not specified.
  LocationService({
    Duration? updateInterval,
  }) : _updateInterval = updateInterval ?? const Duration(seconds: 2);

  /// Whether location service is enabled on the device.
  static bool _serviceEnabled = false;

  /// The current location permission status.
  static LocationPermission _permission = LocationPermission.denied;

  /// The location service update interval.
  final Duration _updateInterval;

  /// Checks if location services are enabled and location permission is granted.
  ///
  /// Throws a [ServiceDisabledLocationServiceException] if location services
  /// are disabled.
  /// Throws a [PermissionDeniedLocationServiceException] if location permission
  /// is denied.
  /// Throws a [PermissionsPermanentlyDeniedLocationServiceException] if
  /// location permissions are permanently denied.
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
  ///
  /// The update interval is set in the constructor.
  /// Can throw a [PermissionDeniedLocationServiceException] or
  /// [ServiceDisabledLocationServiceException].
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

  /// Gets the current location of the device.
  ///
  /// Can throw a [PermissionDeniedLocationServiceException] or
  /// [ServiceDisabledLocationServiceException].
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

  /// Calculates the distance between two locations in meters.
  ///
  /// Throws [UnableCalculateDistanceLocationServiceException] on failure.
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

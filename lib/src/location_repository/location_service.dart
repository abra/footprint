import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'models/exceptions.dart';

/// Provides access to the device's location.
class LocationService {
  const LocationService({
    int? distanceFilter,
  }) : _distanceFilter = distanceFilter ?? 5;

  /// Whether location service is enabled on the device.
  static bool _serviceEnabled = false;

  /// The current location permission status.
  static LocationPermission _permission = LocationPermission.denied;

  /// The distance between each location update.
  final int _distanceFilter;

  /// Checks if location service is enabled
  Future<void> ensureLocationServiceEnabled() async {
    // throw ServiceDisabledLocationServiceException();
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_serviceEnabled) {
      throw ServiceDisabledLocationServiceException();
    }
  }

  /// Checks if location service permission is granted.
  Future<void> ensurePermissionGranted() async {
    if (_serviceEnabled) {
      _permission = await Geolocator.checkPermission();

      if (_permission == LocationPermission.denied) {
        try {
          _permission = await Geolocator.requestPermission();
        } on PermissionRequestInProgressException catch (_) {
          throw PermissionRequestInProgressLocationServiceException();
        }

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

  /// Gets a stream of location updates
  Stream<Position> positionUpdateStream() async* {
    final locationSettings = LocationSettings(
      distanceFilter: _distanceFilter,
    );

    try {
      final positionStream = Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );

      await for (Position position in positionStream) {
        yield position;
        // TODO: Remove it
        // throw const LocationServiceDisabledException();
      }
    } catch (e) {
      if (e is LocationServiceDisabledException) {
        throw ServiceDisabledLocationServiceException();
      }
    }
  }

  /// Gets the current location of the device.
  Future<Position> determinePosition() async {
    try {
      return await Geolocator.getCurrentPosition();
    } on LocationServiceDisabledException catch (_) {
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
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'models/exceptions.dart';

/// Provides access to the device's location.
class LocationService {
  const LocationService({
    int? distanceFilter,
  })  : _distanceFilter = distanceFilter ?? 5;

  /// Whether location service is enabled on the device.
  static bool _serviceEnabled = false;

  /// The current location permission status.
  static LocationPermission _permission = LocationPermission.denied;

  /// The distance between each location update.
  final int _distanceFilter;

  /// Checks if location service is enabled
  Future<void> checkLocationServiceEnabled() async {
    _serviceEnabled = await Geolocator.isLocationServiceEnabled();

    if (!_serviceEnabled) {
      throw ServiceDisabledLocationServiceException();
    }
  }

  /// Checks if location service permission is granted.
  Future<void> checkPermissionGranted() async {
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

  /// Gets a stream of location updates
  Stream<Position> getLocationUpdatesStream() async* {
    try {
      final locationSettings = LocationSettings(
        distanceFilter: _distanceFilter,
      );

      yield* Geolocator.getPositionStream(
        locationSettings: locationSettings,
      );
    } on LocationServiceDisabledException catch (_) {
      throw ServiceDisabledLocationServiceException();
    }
  }

  /// Gets the current location of the device.
  Future<Position> determineLocation() async {
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

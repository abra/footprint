import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'permissions.dart';

/// Provides access to the device's location
class LocationService {
  const LocationService({
    int? distanceFilter,
  }) : _distanceFilter = distanceFilter ?? 5;

  /// The distance between each location update
  final int _distanceFilter;

  /// Checks if location service is enabled
  Future<bool> ensureLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Checks if location service permission is granted
  Future<Permission> ensurePermissionGranted() async {
    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();

      if (permission == LocationPermission.denied) {
        return Permission.denied;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately,
      // until the user updates the permission in the App settings
      return Permission.deniedForever;
    }

    return Permission.granted;
  }

  /// Gets a stream of location updates
  Stream<Position> positionUpdateStream() async* {
    final locationSettings = LocationSettings(
      distanceFilter: _distanceFilter,
    );

    final positionStream = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    );

    await for (Position position in positionStream) {
      yield position;
      // TODO: Remove it
      // throw const LocationServiceDisabledException();
    }
  }

  /// Gets the current location of the device.
  Future<Position> determinePosition() async {
    return await Geolocator.getCurrentPosition();
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

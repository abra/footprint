import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'permissions.dart';

class LocationService {
  const LocationService({
    int? distanceFilter,
  }) : _distanceFilter = distanceFilter ?? 5;

  final int _distanceFilter;

  Future<bool> ensureLocationServiceEnabled() async =>
      await Geolocator.isLocationServiceEnabled();

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

  Future<Position> determinePosition() async =>
      await Geolocator.getCurrentPosition();

  Future<double> calculateDistance({
    required double startLatitude,
    required double startLongitude,
    required double endLatitude,
    required double endLongitude,
  }) async =>
      Geolocator.distanceBetween(
        startLatitude,
        startLongitude,
        endLatitude,
        endLongitude,
      );
}

import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'mappers/position_to_domain.dart';

/// Location service wrapper for [Geolocator]
class LocationService {
  const LocationService._();

  static const LocationService _instance = LocationService._();

  factory LocationService() => _instance;

  static Stream<Position>? _stream;

  Future<void> ensureServiceEnabled() async {
    final serviceStatus = await Permission.location.serviceStatus;

    if (!serviceStatus.isEnabled) {
      throw LocationServiceDisabledException();
    }
  }

  Future<void> ensurePermissionsGranted() async {
    var status = await Permission.location.status;

    if (status.isDenied) {
      status = await Permission.location.request();

      if (status.isDenied) {
        throw LocationServicePermissionDeniedException();
      } else if (status.isPermanentlyDenied) {
        throw LocationServicePermanentlyDeniedException();
      }
    }

    if (status.isPermanentlyDenied) {
      final result = await openAppSettings();
      if (result) {
        status = await Permission.location.status;
        if (status.isDenied) {
          throw LocationServicePermissionDeniedException();
        } else if (status.isPermanentlyDenied) {
          throw LocationServicePermanentlyDeniedException();
        }
      }
    }
  }

  Stream<LocationDM> getLocationUpdateStream({
    LocationSettings? settings,
  }) async* {
    _stream ??= Geolocator.getPositionStream(
      locationSettings: settings ?? LocationSettings(distanceFilter: 5),
    );

    await for (final position in _stream!) {
      yield position.toDomainModel();
      // TODO: Remove it
      // throw const LocationServiceDisabledException();
    }
  }

  Future<LocationDM> determineLocation() async {
    final position = await Geolocator.getCurrentPosition();
    return position.toDomainModel();
  }

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

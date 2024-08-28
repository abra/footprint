import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

/// Location service wrapper for [Geolocator]
class LocationService {
  const LocationService._();

  static const LocationService _instance = LocationService._();

  factory LocationService() => _instance;

  static Stream<Position>? _stream;
  static Position? _lastPosition;
  static DateTime? _lastPositionTimestamp;

  static Future<void> ensureServiceEnabled() async {
    final serviceStatus = await Permission.location.serviceStatus;

    if (!serviceStatus.isEnabled) {
      throw LocationServiceDisabledStateException();
    }
  }

  static Future<void> ensurePermissionsGranted() async {
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

  static Stream<Position> getLocationUpdateStream() async* {
    var settings = const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _stream ??= Geolocator.getPositionStream(
      locationSettings: settings,
    );

    await for (final position in _stream!) {
      yield position;

      if (_lastPosition != null && _lastPositionTimestamp != null) {
        final speed = await _calculateSpeed(
          startPosition: _lastPosition!,
          startTimestamp: _lastPositionTimestamp!,
          endPosition: position,
          endTimestamp: DateTime.now(),
        );
        settings = await _getSettings(speed);
        _stream = Geolocator.getPositionStream(
          locationSettings: settings,
        );
      }
      _lastPosition = position;
      _lastPositionTimestamp = DateTime.now();
      // TODO: Remove it
      // throw const LocationServiceDisabledException();
    }
  }

  // TODO: Rewrite it
  static Future<LocationSettings> _getSettings(double speed) async {
    return switch (speed) {
      // Walk (to 5 км/ч)
      <= 1.39 => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      // Run (from 5 km/h to 15 km/h)
      <= 4.17 => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      // Bicycle (from 15 km/h to 30 km/h)
      <= 8.33 => const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      // Scooter (from 30 km/h to 50 km/h)
      <= 13.89 => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 20,
        ),
      // Car in city (from 50 km/h to 80 km/h)
      <= 22.22 => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 25,
        ),
      // Car in highway (from 80 km/h to 120 km/h)
      <= 33.33 => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 50,
        ),
      // Train (from 120 km/h to 300 km/h)
      <= 83.33 => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 100,
        ),
      // Airplane (from 300 km/h)
      > 83.33 => const LocationSettings(
          accuracy: LocationAccuracy.low,
          distanceFilter: 500,
        ),
      _ => const LocationSettings(
          accuracy: LocationAccuracy.medium,
          distanceFilter: 10,
        ),
    };
  }

  static Future<Position> determineLocation() async {
    final position = await Geolocator.getCurrentPosition();
    return position;
  }

  static Future<double> _calculateSpeed({
    required Position startPosition,
    required DateTime startTimestamp,
    required Position endPosition,
    required DateTime endTimestamp,
  }) async {
    final distance = await _calculateDistance(
      startLatitude: startPosition.latitude,
      startLongitude: startPosition.longitude,
      endLatitude: endPosition.latitude,
      endLongitude: endPosition.longitude,
    );

    // log('start: $startPosition, end: $endPosition, distance: $distance');

    final duration = endTimestamp.difference(startTimestamp);
    return distance / duration.inSeconds;
  }

  static Future<double> _calculateDistance({
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

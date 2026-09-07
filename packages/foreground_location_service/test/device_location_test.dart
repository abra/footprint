import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geolocator/geolocator.dart';

class _Platform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  LocationPermission requested = LocationPermission.whileInUse;
  int requests = 0;
  int permissionRequests = 0;
  LocationSettings? settings;
  Object? error;
  final position = Position.fromMap({
    'latitude': 56.0,
    'longitude': 60.0,
    'timestamp': DateTime.utc(2026, 9, 8).millisecondsSinceEpoch,
    'accuracy': 8.0,
    'speed': 0.0,
    'speed_accuracy': 0.2,
  });

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requested;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    requests++;
    settings = locationSettings;
    if (error case final failure?) throw failure;
    return position;
  }
}

void main() {
  late GeolocatorPlatform previous;
  late _Platform platform;
  setUp(() {
    previous = GeolocatorPlatform.instance;
    platform = _Platform();
    GeolocatorPlatform.instance = platform;
  });
  tearDown(() => GeolocatorPlatform.instance = previous);

  test(
    'one-shot asks for high accuracy with a deadline and retains measured data',
    () async {
      final fix = await DeviceLocation().currentLocation();
      expect(platform.requests, 1);
      expect(platform.settings!.accuracy, LocationAccuracy.high);
      expect(platform.settings!.timeLimit, const Duration(seconds: 15));
      expect(platform.permissionRequests, 0);
      expect(fix.timestamp, platform.position.timestamp);
      expect(fix.latitude, platform.position.latitude);
      expect(fix.longitude, platform.position.longitude);
      expect(fix.accuracy, 8);
      expect(fix.speed, 0);
    },
  );

  test('disabled GPS does not request a fix', () async {
    platform.enabled = false;
    await expectLater(
      DeviceLocation().currentLocation(),
      throwsA(isA<LocationServiceDisabledStateException>()),
    );
    expect(platform.requests, 0);
  });

  test('denied permission can be granted before requesting a fix', () async {
    platform.permission = LocationPermission.denied;
    await DeviceLocation().currentLocation();
    expect(platform.permissionRequests, 1);
    expect(platform.requests, 1);
  });

  test('denied and permanently denied permissions stay explicit', () async {
    platform.permission = LocationPermission.denied;
    platform.requested = LocationPermission.denied;
    await expectLater(
      DeviceLocation().currentLocation(),
      throwsA(isA<LocationServicePermissionDeniedException>()),
    );
    platform.permission = LocationPermission.deniedForever;
    await expectLater(
      DeviceLocation().currentLocation(),
      throwsA(isA<LocationServicePermanentlyDeniedException>()),
    );
    expect(platform.requests, 0);
    expect(platform.permissionRequests, 1);
  });

  test('native acquisition timeout reaches the caller', () async {
    platform.error = TimeoutException('No fix');
    await expectLater(
      DeviceLocation().currentLocation(),
      throwsA(isA<TimeoutException>()),
    );
  });
}

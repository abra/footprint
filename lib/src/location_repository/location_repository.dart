import 'package:geolocator/geolocator.dart';
import 'package:meta/meta.dart';

import '../domain_models/exceptions.dart';
import '../domain_models/location.dart';
import 'location_service.dart';
import 'mappers/position_to_domain.dart';
import 'permissions.dart';

class LocationRepository {
  const LocationRepository({
    @visibleForTesting LocationService? locationService,
  }) : _locationService = locationService ?? const LocationService();

  final LocationService _locationService;

  Future<void> ensureLocationServiceEnabled() async {
    final isEnabled = await _locationService.ensureLocationServiceEnabled();

    if (!isEnabled) {
      throw ServiceDisabledException();
    }
  }

  Future<void> ensurePermissionGranted() async {
    Permission? permission;

    try {
      permission = await _locationService.ensurePermissionGranted();
    } on PermissionRequestInProgressException catch (_) {
      throw RequestForPermissionInProgressException();
    } on PermissionDefinitionsNotFoundException catch (_) {
      throw DefinitionsForPermissionNotFoundException();
    }

    if (permission == Permission.denied) {
      throw ServicePermissionDeniedException();
    } else if (permission == Permission.deniedForever) {
      throw PermissionsPermanentlyDeniedException();
    }
  }

  Stream<Location> locationUpdateStream() async* {
    try {
      final positionUpdateStream = _locationService.positionUpdateStream();

      await for (final position in positionUpdateStream) {
        yield position.toDomainModel();
      }
    } catch (e) {
      if (e is LocationServiceDisabledException) {
        throw ServiceDisabledException();
      }
    }
  }

  Future<Location> determineLocation() async {
    try {
      final position = await _locationService.determinePosition();
      return position.toDomainModel();
    } on LocationServiceDisabledException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<double> calculateDistance({
    required Location from,
    required Location to,
  }) async {
    return await _locationService.calculateDistance(
      startLatitude: from.latitude,
      startLongitude: from.longitude,
      endLatitude: to.latitude,
      endLongitude: to.longitude,
    );
  }

  Future<double> calculateSpeed({
    required Location from,
    required Location to,
  }) async {
    final timeDifference = to.timestamp.difference(from.timestamp);
    final distance = await calculateDistance(
      from: from,
      to: to,
    );
    final speed = distance / timeDifference.inSeconds;
    return speed;
  }
}

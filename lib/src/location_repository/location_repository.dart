import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:meta/meta.dart';

import 'location_service.dart';
import 'mappers/position_to_domain.dart';
import 'models/exceptions.dart';

class LocationRepository {
  const LocationRepository({
    @visibleForTesting LocationService? locationService,
  }) : _locationService = locationService ?? const LocationService();

  final LocationService _locationService;

  Future<void> ensureLocationServiceEnabled() async {
    try {
      await _locationService.ensureLocationServiceEnabled();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<void> ensurePermissionGranted() async {
    try {
      await _locationService.ensurePermissionGranted();
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on PermissionsPermanentlyDeniedLocationServiceException catch (_) {
      throw PermissionsPermanentlyDeniedException();
    } on PermissionRequestInProgressLocationServiceException catch (_) {
      throw PermissionRequestInProgressException();
    }
  }

  Stream<Location> locationUpdateStream() async* {
    try {
      final positionUpdateStream = _locationService.positionUpdateStream();

      await for (final position in positionUpdateStream) {
        yield position.toDomainModel();
      }
    } catch (e) {
      if (e is ServiceDisabledLocationServiceException) {
        throw ServiceDisabledException();
      }
    }
  }

  Future<Location> determineLocation() async {
    try {
      final position = await _locationService.determinePosition();
      return position.toDomainModel();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<double> calculateDistance({
    required Location from,
    required Location to,
  }) {
    return _locationService.calculateDistance(
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

import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/domain_models/location.dart';

import 'location_service.dart';
import 'mappers/position_to_domain.dart';
import 'models/exceptions.dart';

class LocationRepository {
  const LocationRepository({
    LocationService? locationService,
  }) : _locationService = locationService ?? const LocationService();

  final LocationService _locationService;

  Future<void> checkLocationServiceEnabled() async {
    try {
      await _locationService.checkLocationServiceEnabled();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<void> checkPermissionGranted() async {
    try {
      await _locationService.checkPermissionGranted();
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on PermissionsPermanentlyDeniedLocationServiceException catch (_) {
      throw PermissionsPermanentlyDeniedException();
    } on PermissionDefinitionsNotFoundLocationServiceException catch (_) {
      throw PermissionDefinitionsNotFoundException();
    } on PermissionRequestInProgressLocationServiceException catch (_) {
      throw PermissionRequestInProgressException();
    }
  }

  Stream<Location> getLocationUpdatesStream() {
    try {
      return _locationService
          .getLocationUpdatesStream()
          .map((position) => position.toDomainModel());
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<Location> determineLocation() {
    try {
      return _locationService
          .determineLocation()
          .then((position) => position.toDomainModel());
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
}

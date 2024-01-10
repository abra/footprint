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

  Stream<Location> getLocationUpdatesStream() {
    try {
      return _locationService
          .getLocationUpdatesStream()
          .map((position) => position.toDomainModel());
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    } on UpdateTimeoutLocationServiceException catch (_) {
      throw LocationUpdateTimeoutException();
    }
  }

  Future<Location> determineLocation() {
    try {
      return _locationService
          .determineLocation()
          .then((position) => position.toDomainModel());
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    } on UpdateTimeoutLocationServiceException catch (_) {
      throw LocationUpdateTimeoutException();
    }
  }

  Future<double> calculateDistance({
    required Location from,
    required Location to,
  }) {
    try {
      return _locationService.calculateDistance(
        startLatitude: from.latitude,
        startLongitude: from.longitude,
        endLatitude: to.latitude,
        endLongitude: to.longitude,
      );
    } on UnableCalculateDistanceLocationServiceException catch (_) {
      throw UnableCalculateDistanceException();
    }
  }
}

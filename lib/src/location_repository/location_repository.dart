import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_service/models/exceptions.dart';
import 'package:footprint/src/location_repository/mappers/position_to_domain.dart';

import 'location_service/location_service.dart';

class LocationRepository {
  LocationRepository({
    required this.locationService,
  });

  final LocationService locationService;

  Stream<Location> getLocationUpdatesStream() {
    try {
      return locationService
          .getLocationUpdatesStream()
          .map((position) => position.toDomainModel());
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<Location> determineLocation() {
    try {
      return locationService
          .determineLocation()
          .then((position) => position.toDomainModel());
    } on PermissionDeniedLocationServiceException catch (_) {
      throw PermissionDeniedException();
    } on ServiceDisabledLocationServiceException catch (_) {
      throw ServiceDisabledException();
    }
  }

  Future<double> calculateDistance({
    required Location from,
    required Location to,
  }) {
    try {
      return locationService.calculateDistance(
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

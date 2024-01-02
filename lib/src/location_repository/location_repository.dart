import 'package:flutter/foundation.dart';

import '/src/local_database/local_database.dart';
import 'location_local_storage.dart';
import 'location_service.dart';

class LocationRepository {
  LocationRepository({
    required LocalDatabase localDatabase,
    required this.locationService,
    @visibleForTesting LocationLocalStorage? locationLocalStorage,
  }) : _locationLocalStorage = locationLocalStorage ??
      LocationLocalStorage(
        localDatabase: localDatabase,
      );

  final LocationService locationService;
  final LocationLocalStorage _locationLocalStorage;
}

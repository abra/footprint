import 'package:flutter/foundation.dart';

import '/src/local_database/local_database.dart';
import 'geocoding_local_storage.dart';
import 'geocoding_service.dart';

class GeocodingRepository {
  GeocodingRepository({
    required LocalDatabase localDatabase,
    required this.geocodingService,
    @visibleForTesting GeocodingLocalStorage? geocodingLocalStorage,
  }) : _geocodingLocalStorage = geocodingLocalStorage ??
            GeocodingLocalStorage(
              localDatabase: localDatabase,
            );

  final GeocodingService geocodingService;
  final GeocodingLocalStorage _geocodingLocalStorage;
}

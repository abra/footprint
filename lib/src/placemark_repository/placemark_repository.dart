import 'package:flutter/foundation.dart';
import 'package:footprint/src/local_storage/local_storage.dart';

import 'placemark_local_storage.dart';
import 'placemark_service.dart';

class PlacemarkRepository {
  PlacemarkRepository({
    required LocalStorage localStorage,
    required this.placemarkService,
    @visibleForTesting PlacemarkLocalStorage? placemarkLocalStorage,
  }) : _placemarkLocalStorage = placemarkLocalStorage ??
            PlacemarkLocalStorage(
              localStorage: localStorage,
            );

  final PlacemarkService placemarkService;
  final PlacemarkLocalStorage _placemarkLocalStorage;
}

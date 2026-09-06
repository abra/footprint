import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'geocoding_cache_storage.dart';
import 'geocoding_service.dart';
import 'mappers/mappers.dart';

class GeocodingManager {
  GeocodingManager({
    required SqliteStorage sqliteStorage,
    @visibleForTesting GeocodingCacheStorage? cacheStorage,
    @visibleForTesting GeocodingService? geocodingService,
  }) : _service = geocodingService ?? GeocodingService(),
       _cache =
           cacheStorage ?? GeocodingCacheStorage(sqliteStorage: sqliteStorage);

  final GeocodingService _service;
  final GeocodingCacheStorage _cache;
  final _requests = <Future<PlaceAddressDM?>>{};
  Future<void>? _disposal;

  Future<PlaceAddressDM?> getAddressFromCoordinates(LocationDM location) {
    if (_disposal != null) return Future.value();
    final request = _getAddress(location);
    _requests.add(request);
    request.then<void>(
      (_) => _requests.remove(request),
      onError: (Object _, StackTrace _) => _requests.remove(request),
    );
    return request;
  }

  Future<PlaceAddressDM?> _getAddress(LocationDM location) async {
    try {
      final cached = await _cache.getPlaceAddress(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (cached != null) return cached.toDomainModel();
    } on Object catch (error, stack) {
      log(
        'Address cache read failed',
        name: 'GeocodingManager',
        error: error,
        stackTrace: stack,
      );
    }

    if (_disposal != null) return null;
    final address = await _service.reverseGeocoding(
      latitude: location.latitude,
      longitude: location.longitude,
    );
    if (_disposal != null || address == null || address.isEmpty) return null;
    try {
      await _cache.addPlaceAddress(
        address: address,
        latitude: location.latitude,
        longitude: location.longitude,
      );
    } on Object catch (error, stack) {
      log(
        'Address cache write failed',
        name: 'GeocodingManager',
        error: error,
        stackTrace: stack,
      );
    }
    return PlaceAddressDM(
      address: address,
      latitude: location.latitude,
      longitude: location.longitude,
    );
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    await _service.dispose();
    await Future.wait([
      for (final request in _requests.toList())
        request.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
    ]);
  }
}

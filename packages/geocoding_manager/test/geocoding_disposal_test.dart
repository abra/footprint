import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:geocoding_manager/src/geocoding_cache_storage.dart';
import 'package:geocoding_manager/src/geocoding_service.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:test/test.dart';

class UnusedStorage implements SqliteStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('Unexpected storage access');
}

class ControlledCache extends GeocodingCacheStorage {
  ControlledCache() : super(sqliteStorage: UnusedStorage());
  final writeStarted = Completer<void>();
  Completer<void>? writeGate;
  bool failRead = false;
  int writes = 0;

  @override
  Future<PlaceAddressCM?> getPlaceAddress({
    required double latitude,
    required double longitude,
    double distance = 20,
  }) async {
    if (failRead) throw StateError('Cache unavailable');
    return null;
  }

  @override
  Future<int> addPlaceAddress({
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    writes++;
    if (!writeStarted.isCompleted) writeStarted.complete();
    await writeGate?.future;
    return 1;
  }
}

void main() {
  final location = LocationDM(
    id: '1',
    latitude: 56,
    longitude: 60,
    timestamp: DateTime.utc(2026),
  );

  test(
    'dispose joins in-flight cache writes before storage can close',
    () async {
      final cache = ControlledCache()..writeGate = Completer<void>();
      final manager = GeocodingManager(
        sqliteStorage: UnusedStorage(),
        cacheStorage: cache,
        geocodingService: GeocodingService(
          platformLookup: (_, _) async => 'Address',
        ),
      );
      final lookup = manager.getAddressFromCoordinates(location);
      await cache.writeStarted.future;
      var closed = false;
      final closing = manager.dispose();
      unawaited(closing.then((_) => closed = true));
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      cache.writeGate!.complete();
      await lookup;
      await closing;
      expect(await manager.getAddressFromCoordinates(location), isNull);
      expect(cache.writes, 1);
    },
  );

  test(
    'late network completion after dispose cannot write to SQLite',
    () async {
      final cache = ControlledCache();
      final started = Completer<void>();
      final result = Completer<String?>();
      final manager = GeocodingManager(
        sqliteStorage: UnusedStorage(),
        cacheStorage: cache,
        geocodingService: GeocodingService(
          platformLookup: (_, _) {
            started.complete();
            return result.future;
          },
        ),
      );
      final lookup = manager.getAddressFromCoordinates(location);
      await started.future;
      await manager.dispose();
      result.complete('Late address');
      expect(await lookup, isNull);
      expect(cache.writes, 0);
    },
  );

  test('cache read failure still allows a platform address', () async {
    final cache = ControlledCache()..failRead = true;
    final manager = GeocodingManager(
      sqliteStorage: UnusedStorage(),
      cacheStorage: cache,
      geocodingService: GeocodingService(
        platformLookup: (_, _) async => 'Address',
      ),
    );
    expect(
      (await manager.getAddressFromCoordinates(location))!.address,
      'Address',
    );
    await manager.dispose();
  });
}

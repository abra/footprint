import 'dart:async';

import 'package:geocoding_manager/src/geocoding_service.dart';
import 'package:test/test.dart';

void main() {
  test('waiting coordinates coalesce to the latest request', () async {
    final gate = Completer<String?>();
    final calls = <double>[];
    final service = GeocodingService(
      platformLookup: (_, _) async => null,
      fallbackInterval: Duration.zero,
      fallbackLookup: (latitude, _) {
        calls.add(latitude);
        return latitude == 0 ? gate.future : Future.value('Latest');
      },
    );
    addTearDown(service.dispose);
    final first = service.reverseGeocoding(latitude: 0, longitude: 0);
    await Future<void>.delayed(Duration.zero);
    final obsolete = [
      for (var i = 1; i < 8; i++)
        service.reverseGeocoding(latitude: i.toDouble(), longitude: 0),
    ];
    final latest = service.reverseGeocoding(latitude: 8, longitude: 0);
    expect(await Future.wait(obsolete), everyElement(isNull));
    gate.complete('First');
    expect(await first, 'First');
    expect(await latest, 'Latest');
    expect(calls, [0.0, 8.0]);
  });

  test('hung fallback times out and the newest request still runs', () async {
    final hung = Completer<String?>();
    final service = GeocodingService(
      platformLookup: (_, _) async => null,
      fallbackInterval: Duration.zero,
      lookupTimeout: const Duration(milliseconds: 20),
      fallbackLookup: (latitude, _) =>
          latitude == 0 ? hung.future : Future.value('Recovered'),
    );
    addTearDown(service.dispose);
    final first = service.reverseGeocoding(latitude: 0, longitude: 0);
    final failed = expectLater(first, throwsA(isA<TimeoutException>()));
    final latest = service.reverseGeocoding(latitude: 1, longitude: 0);
    await failed;
    expect(await latest, 'Recovered');
    hung.complete('Stale');
  });

  test('hung platform geocoder has a bounded fallback', () async {
    final hung = Completer<String?>();
    final service = GeocodingService(
      platformLookup: (_, _) => hung.future,
      lookupTimeout: const Duration(milliseconds: 20),
      fallbackLookup: (_, _) async => 'Fallback',
    );
    addTearDown(service.dispose);
    expect(
      await service.reverseGeocoding(latitude: 0, longitude: 0),
      'Fallback',
    );
    hung.complete(null);
  });

  test(
    'dispose cancels active and queued lookups without waiting for timeout',
    () async {
      final hung = Completer<String?>();
      var calls = 0;
      final service = GeocodingService(
        platformLookup: (_, _) {
          calls++;
          return hung.future;
        },
      );
      final first = service.reverseGeocoding(latitude: 0, longitude: 0);
      final last = service.reverseGeocoding(latitude: 1, longitude: 0);
      await service.dispose();
      expect(await Future.wait([first, last]), [null, null]);
      expect(await service.reverseGeocoding(latitude: 2, longitude: 0), isNull);
      expect(calls, 1);
      hung.complete(null);
    },
  );

  test('platform address avoids fallback', () async {
    var fallbackCalls = 0;
    final service = GeocodingService(
      platformLookup: (_, _) async => 'Address',
      fallbackLookup: (_, _) async {
        fallbackCalls++;
        return 'Fallback';
      },
    );
    expect(
      await service.reverseGeocoding(latitude: 0, longitude: 0),
      'Address',
    );
    expect(fallbackCalls, 0);
  });

  test('empty result and platform failure both use fallback', () async {
    for (final fails in [true, false]) {
      final service = GeocodingService(
        platformLookup: (_, _) async {
          if (fails) throw Exception('Platform unavailable');
          return null;
        },
        fallbackLookup: (_, _) async => 'Fallback',
      );
      expect(
        await service.reverseGeocoding(latitude: 0, longitude: 0),
        'Fallback',
      );
    }
  });

  test(
    'concurrent fallback calls are serialized and failures do not poison queue',
    () async {
      final gate = Completer<void>();
      var calls = 0;
      var active = 0;
      var maxActive = 0;
      final service = GeocodingService(
        platformLookup: (_, _) async => null,
        fallbackInterval: Duration.zero,
        fallbackLookup: (_, _) async {
          final call = ++calls;
          active++;
          if (active > maxActive) maxActive = active;
          try {
            if (call == 1) {
              await gate.future;
              throw Exception('Network unavailable');
            }
            return 'Recovered';
          } finally {
            active--;
          }
        },
      );
      final first = service.reverseGeocoding(latitude: 0, longitude: 0);
      final failure = expectLater(first, throwsException);
      final second = service.reverseGeocoding(latitude: 1, longitude: 1);
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      gate.complete();
      await failure;
      expect(await second, 'Recovered');
      expect(maxActive, 1);
    },
  );

  test('fallback start times obey configured minimum interval', () async {
    final starts = <DateTime>[];
    final service = GeocodingService(
      platformLookup: (_, _) async => null,
      fallbackInterval: const Duration(milliseconds: 30),
      fallbackLookup: (_, _) async {
        starts.add(DateTime.now());
        return 'Address';
      },
    );
    await Future.wait([
      service.reverseGeocoding(latitude: 0, longitude: 0),
      service.reverseGeocoding(latitude: 1, longitude: 1),
    ]);
    expect(
      starts.last.difference(starts.first).inMilliseconds,
      greaterThanOrEqualTo(30),
    );
  });
}

import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';

class FakeBackend implements LocationBackend {
  StreamController<LocationDM> controller = StreamController.broadcast();
  final calls = <String>[];
  final seeds = <LocationDM?>[];
  Completer<void>? startGate;
  bool failStart = false;
  bool failStop = false;
  Completer<LocationDM>? locationGate;
  @override
  Future<LocationDM> currentLocation() {
    calls.add('current');
    return locationGate!.future;
  }

  @override
  Stream<LocationDM> get locations => controller.stream;
  @override
  Future<void> start({
    required bool background,
    LocationDM? initialLocation,
  }) async {
    seeds.add(initialLocation);
    calls.add(background ? 'recording' : 'preview');
    await startGate?.future;
    if (failStart) throw StateError('Permission denied');
  }

  @override
  Future<void> stop() async {
    calls.add('stop');
    if (failStop) throw StateError('Stop failed');
  }

  @override
  Future<void> dispose() async {
    calls.add('dispose');
    await controller.close();
  }
}

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeBackend backend;
  late ForegroundLocationService service;
  late StreamSubscription<LocationDM> subscription;
  late List<Object> errors;
  setUp(() {
    backend = FakeBackend();
    service = ForegroundLocationService(backend: backend);
    errors = [];
    subscription = service.locations.listen((_) {}, onError: errors.add);
  });
  tearDown(() async {
    await subscription.cancel();
    await service.dispose();
  });

  test(
    'mode transitions serialize and repeated requests are idempotent',
    () async {
      await Future.wait([
        service.setMode(LocationMode.preview),
        service.setMode(LocationMode.preview),
        service.setMode(LocationMode.recording),
        service.setMode(LocationMode.stopped),
      ]);
      expect(backend.calls, ['preview', 'stop', 'recording', 'stop']);
    },
  );

  test(
    'one-shot requests are shared without restarting or publishing to tracking',
    () async {
      await service.setMode(LocationMode.recording);
      backend.locationGate = Completer<LocationDM>();
      final fixes = <LocationDM>[];
      final listener = service.locations.listen(fixes.add);
      final first = service.currentLocation();
      expect(service.currentLocation(), same(first));
      await service.setMode(LocationMode.stopped);
      final fix = LocationDM(
        id: 'fresh',
        latitude: 56,
        longitude: 60,
        timestamp: DateTime.now(),
      );
      backend.locationGate!.complete(fix);
      expect(await first, fix);
      await tick();
      expect(backend.calls, ['recording', 'current', 'stop']);
      expect(fixes, isEmpty);
      expect(service.lastLocation, isNull);
      await listener.cancel();
    },
  );

  testWidgets('one-shot timeout releases the request so it can be retried', (
    tester,
  ) async {
    backend.locationGate = Completer<LocationDM>();
    final first = service.currentLocation();
    final failure = expectLater(first, throwsA(isA<TimeoutException>()));
    await tester.pump(DeviceLocation.acquisitionTimeout);
    await failure;
    final late = backend.locationGate!;
    backend.locationGate = Completer<LocationDM>();
    final retry = service.currentLocation();
    final fix = LocationDM(
      id: 'fresh',
      latitude: 56,
      longitude: 60,
      timestamp: DateTime.now(),
    );
    late.complete(fix);
    backend.locationGate!.complete(fix);
    expect(await retry, fix);
    expect(backend.calls, ['current', 'current']);
  });

  test('disposal rejects new and late one-shot results', () async {
    backend.locationGate = Completer<LocationDM>();
    final request = service.currentLocation();
    final failure = expectLater(request, throwsStateError);
    await service.dispose();
    backend.locationGate!.complete(
      LocationDM(
        id: 'late',
        latitude: 56,
        longitude: 60,
        timestamp: DateTime.now(),
      ),
    );
    await failure;
    await expectLater(service.currentLocation(), throwsStateError);
    expect(service.lastLocation, isNull);
  });

  test('startup failure can be retried with the same mode', () async {
    backend.failStart = true;
    await expectLater(service.setMode(LocationMode.preview), throwsStateError);
    backend.failStart = false;
    await service.setMode(LocationMode.preview);
    expect(backend.calls, ['preview', 'stop', 'preview']);
  });

  test('stream error invalidates previous successful startup', () async {
    await service.setMode(LocationMode.preview);
    backend.controller.addError(StateError('GPS disabled'));
    await tick();
    expect(errors, hasLength(1));
    await service.setMode(LocationMode.preview);
    expect(backend.calls, ['preview', 'stop', 'preview']);
  });

  test('error emitted during startup cannot be reported as success', () async {
    backend.startGate = Completer<void>();
    final starting = service.setMode(LocationMode.preview);
    final failed = expectLater(starting, throwsStateError);
    await tick();
    backend.controller.addError(StateError('GPS failed during startup'));
    await tick();
    backend.startGate!.complete();
    await failed;
    expect(errors, hasLength(1));
    await service.setMode(LocationMode.preview);
    expect(backend.calls, ['preview', 'stop', 'preview']);
  });

  test(
    'stream completion is visible and a new stream is subscribed on retry',
    () async {
      await service.setMode(LocationMode.preview);
      await backend.controller.close();
      await tick();
      expect(errors, hasLength(1));
      backend.controller = StreamController.broadcast();
      await service.setMode(LocationMode.preview);
      final point = LocationDM(
        id: '1',
        latitude: 56,
        longitude: 60,
        timestamp: DateTime.now(),
      );
      backend.controller.add(point);
      await tick();
      expect(service.lastLocation, point);
      expect(backend.calls, ['preview', 'stop', 'preview']);
    },
  );

  test('explicit retry restarts even without a stream error', () async {
    await service.setMode(LocationMode.preview);
    await service.setMode(LocationMode.preview, restart: true);
    expect(backend.calls, ['preview', 'stop', 'preview']);
  });

  test(
    'mode changes and retries seed from the newest filtered location',
    () async {
      final restored = LocationDM(
        id: 'saved',
        latitude: 56,
        longitude: 60,
        timestamp: DateTime.utc(2026, 9, 7),
        accuracy: 5,
        rawLatitude: 56.00001,
        rawLongitude: 60,
        isStationary: true,
      );
      await service.setMode(LocationMode.preview, initialLocation: restored);
      expect(backend.seeds.last, restored);
      final latest = LocationDM(
        id: 'live',
        latitude: 56.0001,
        longitude: 60,
        timestamp: restored.timestamp.add(const Duration(seconds: 10)),
        accuracy: 5,
      );
      backend.controller.add(latest);
      await tick();
      await service.setMode(LocationMode.recording, initialLocation: restored);
      expect(backend.seeds.last, latest);
      await service.setMode(LocationMode.recording, restart: true);
      expect(backend.seeds.last, latest);
      expect(service.lastLocation, latest);
    },
  );

  test('failed stop does not falsely commit the requested new mode', () async {
    await service.setMode(LocationMode.recording);
    backend.failStop = true;
    await expectLater(service.setMode(LocationMode.preview), throwsStateError);
    backend.failStop = false;
    await service.setMode(LocationMode.preview);
    expect(backend.calls, ['recording', 'stop', 'stop', 'preview']);
  });

  test(
    'disposal waits for startup and never restarts from queued commands',
    () async {
      backend.startGate = Completer<void>();
      final starting = service.setMode(LocationMode.preview);
      await tick();
      final queued = service.setMode(LocationMode.recording);
      final closing = service.dispose();
      expect(service.dispose(), same(closing));
      backend.startGate!.complete();
      await Future.wait([starting, queued, closing]);
      expect(backend.calls, ['preview', 'stop', 'dispose']);
      await expectLater(
        service.setMode(LocationMode.preview),
        throwsStateError,
      );
    },
  );
}

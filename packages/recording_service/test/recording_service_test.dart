import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeLocationService locationService;
  late FakeRoutesRepository repository;
  late RecordingService service;

  setUp(() {
    locationService = FakeLocationService();
    repository = FakeRoutesRepository();
    service = RecordingService(
      locationService: locationService,
      routesRepository: repository,
    );
  });
  tearDown(() async {
    await service.dispose();
    await locationService.dispose();
  });

  Future<void> prepare() async {
    await service.attachPreview();
    locationService.send(location(1));
    await tick();
  }

  test(
    'initialization opens no GPS permissions or background service',
    () async {
      await Future.wait([service.initialize(), service.initialize()]);
      expect(locationService.starts, 0);
    },
  );

  test(
    'preview follows app lifecycle and recording survives hidden UI',
    () async {
      await prepare();
      expect(locationService.mode, LocationMode.preview);
      await service.setForeground(false);
      expect(locationService.mode, LocationMode.stopped);
      await service.setForeground(true);
      await service.start();
      expect(locationService.mode, LocationMode.recording);
      await service.setForeground(false);
      await service.detachPreview();
      locationService.send(location(2));
      await tick();
      expect(service.state.points, hasLength(2));
      expect(locationService.mode, LocationMode.recording);
      await service.stop();
      expect(locationService.mode, LocationMode.stopped);
    },
  );

  test('multiple previews release independently', () async {
    await service.attachPreview();
    await service.attachPreview();
    await service.detachPreview();
    expect(locationService.mode, LocationMode.preview);
    await service.detachPreview();
    expect(locationService.mode, LocationMode.stopped);
  });

  test(
    'start and incoming points serialize without duplicate sessions',
    () async {
      await prepare();
      repository.startGate = Completer<int>();
      final start = service.start();
      await service.start();
      locationService.send(location(2));
      await tick();
      repository.startGate!.complete(1);
      await start;
      await service.stop();
      expect(service.state.points, [location(1), location(2)]);
      expect(repository.finished, 1);
      expect(service.state.phase, RecordingPhase.idle);
    },
  );

  test(
    'failed start is retryable without a fictitious active session',
    () async {
      await prepare();
      repository.failStart = true;
      await service.start();
      expect(service.state.isRecording, isFalse);
      expect(service.state.isBusy, isFalse);
      expect(service.state.failure!.operation, RecordingOperation.start);
      repository.failStart = false;
      await service.retry();
      expect(service.state.isRecording, isTrue);
      expect(service.state.failure, isNull);
    },
  );

  test(
    'failed transition to background mode keeps a recoverable route',
    () async {
      await prepare();
      locationService.failStart = true;
      await service.start();
      expect(service.state.routeId, 1);
      expect(service.state.failure!.operation, RecordingOperation.start);
      locationService.failStart = false;
      await service.retry();
      expect(service.state.routeId, 1);
      expect(locationService.mode, LocationMode.recording);
      expect(service.state.failure, isNull);
    },
  );

  test('failed point remains queued and Retry persists it once', () async {
    await prepare();
    await service.start();
    repository.failPoint = true;
    locationService.send(location(2));
    await tick();
    expect(service.state.failure!.operation, RecordingOperation.savePoint);
    repository.failPoint = false;
    await service.retry();
    expect(repository.added, [location(2)]);
    expect(service.state.failure, isNull);
    expect(service.state.points, [location(1), location(2)]);
  });

  test('Retry after failed Stop actually completes the route', () async {
    await prepare();
    await service.start();
    repository.failFinish = true;
    await service.stop();
    expect(service.state.phase, RecordingPhase.stopping);
    expect(service.state.isBusy, isFalse);
    expect(service.state.failure!.operation, RecordingOperation.stop);
    repository.failFinish = false;
    await service.retry();
    expect(repository.finishAttempts, 2);
    expect(repository.finished, 1);
    expect(service.state.isRecording, isFalse);
    expect(service.state.failure, isNull);
    expect(locationService.mode, LocationMode.preview);
  });

  test(
    'failed Stop due to queued points retries flush before finish',
    () async {
      await prepare();
      await service.start();
      repository.failPoint = true;
      locationService.send(location(2));
      await tick();
      await service.stop();
      expect(repository.finished, 0);
      expect(service.state.failure!.operation, RecordingOperation.stop);
      repository.failPoint = false;
      await service.retry();
      expect(repository.added, [location(2)]);
      expect(repository.finished, 1);
    },
  );

  test(
    'backend stop failure is not reported as a completed recording',
    () async {
      await prepare();
      await service.start();
      locationService.failStop = true;
      await service.stop();
      expect(repository.finished, 0);
      locationService.failStop = false;
      await service.retry();
      expect(repository.finished, 1);
    },
  );

  test('late samples after Stop intent do not extend the route', () async {
    await prepare();
    await service.start();
    repository.finishGate = Completer<void>();
    final stopping = service.stop();
    locationService.send(location(2));
    await tick();
    repository.finishGate!.complete();
    await stopping;
    expect(repository.added, isEmpty);
  });

  test('duplicate samples are not appended to presentation state', () async {
    await prepare();
    await service.start();
    locationService.send(location(1));
    await tick();
    expect(service.state.points, [location(1)]);
    expect(repository.added, isEmpty);
  });

  test('invalid GPS values never enter route storage', () async {
    await prepare();
    await service.start();
    locationService.send(
      LocationDM(
        id: 'bad',
        latitude: double.nan,
        longitude: 0,
        timestamp: DateTime.now(),
      ),
    );
    await tick();
    expect(service.state.locationError, isA<FormatException>());
    expect(repository.added, isEmpty);
  });

  test('dispose waits for accepted writes and rejects new points', () async {
    await prepare();
    await service.start();
    repository.pointGate = Completer<void>();
    locationService.send(location(2));
    await tick();
    var disposed = false;
    final closing = service.dispose();
    unawaited(closing.then((_) => disposed = true));
    expect(service.dispose(), same(closing));
    locationService.send(location(3));
    await tick();
    expect(disposed, isFalse);
    repository.pointGate!.complete();
    await closing;
    expect(repository.added, [location(2)]);
    expect(locationService.mode, LocationMode.stopped);
  });

  test(
    'restore loads the existing session without creating a new route',
    () async {
      await repository.startRoute(location(1));
      await repository.addPoint(1, location(2));
      await service.initialize();
      expect(service.state.routeId, 1);
      expect(service.state.points, [location(1), location(2)]);
      expect(locationService.starts, 0);
    },
  );

  test(
    'resume reloads points persisted by an independent background writer',
    () async {
      await prepare();
      await service.start();
      await service.setForeground(false);
      await repository.addPoint(1, location(2));
      await repository.addPoint(1, location(3));
      await service.setForeground(true);
      expect(service.state.points, [location(1), location(2), location(3)]);
    },
  );
}

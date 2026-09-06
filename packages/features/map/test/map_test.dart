import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:map/src/map_cubit.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  late FakeLocationService service;
  late FakeRoutesRepository repository;
  late FakeGeocodingManager geocoding;
  late RecordingService recording;
  late MapCubit cubit;

  setUp(() {
    service = FakeLocationService();
    repository = FakeRoutesRepository();
    geocoding = FakeGeocodingManager();
    recording = RecordingService(
      locationService: service,
      routesRepository: repository,
    );
    cubit = MapCubit(recordingService: recording, geocodingManager: geocoding);
  });
  tearDown(() async {
    await cubit.close();
    await recording.dispose();
    await service.dispose();
  });

  test('permission denial is displayed and Retry restarts tracking', () async {
    service.failStart = true;
    await cubit.initialize();
    await tick();
    expect(cubit.state.error, contains('denied'));
    expect(cubit.state.locationLoading, isFalse);
    service.failStart = false;
    await cubit.retry();
    service.send(location(1));
    await tick();
    expect(cubit.state.location, location(1));
    expect(cubit.state.error, isNull);
  });

  test('initialization attaches a single preview', () async {
    await Future.wait([cubit.initialize(), cubit.initialize()]);
    expect(service.starts, 1);
    await cubit.close();
    await tick();
    expect(service.mode, LocationMode.stopped);
    expect(service.disposed, isFalse);
  });

  test(
    'recording continues between map mounts with all intermediate points',
    () async {
      await cubit.initialize();
      service.send(location(1));
      await tick();
      await cubit.startRecording();
      await cubit.close();
      for (var index = 2; index <= 4; index++) {
        service.send(location(index));
        await tick();
      }
      expect(service.mode, LocationMode.recording);
      cubit = MapCubit(
        recordingService: recording,
        geocodingManager: geocoding,
      );
      await cubit.initialize();
      expect(cubit.state.points, [
        location(1),
        location(2),
        location(3),
        location(4),
      ]);
      await cubit.stopRecording();
      expect(repository.finished, 1);
      expect(cubit.state.isRecording, isFalse);
    },
  );

  test('late address response cannot emit after screen disposal', () async {
    final result = Completer<PlaceAddressDM?>();
    geocoding.lookup = (_) => result.future;
    await cubit.initialize();
    service.send(location(1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    await cubit.close();
    result.complete(
      PlaceAddressDM(address: 'Late', latitude: 56, longitude: 60),
    );
    await tick();
    expect(cubit.isClosed, isTrue);
  });

  test(
    'screen closes during restore without starting a discarded preview',
    () async {
      repository.activeGate = Completer<RouteDM?>();
      final initialization = cubit.initialize();
      await cubit.close();
      repository.activeGate!.complete(null);
      await initialization;
      await tick();
      expect(service.starts, 0);
    },
  );

  test('older address result cannot overwrite a newer location', () async {
    final result = Completer<PlaceAddressDM?>();
    geocoding.lookup = (value) async => value.id == '1'
        ? result.future
        : PlaceAddressDM(address: 'Current', latitude: 56, longitude: 60);
    await cubit.initialize();
    service.send(location(1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    service.send(location(2));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    result.complete(
      PlaceAddressDM(address: 'Old', latitude: 56, longitude: 60),
    );
    await tick();
    expect(cubit.state.address, 'Current');
  });

  test('background recording does not launch address lookups', () async {
    var lookups = 0;
    geocoding.lookup = (_) async {
      lookups++;
      return null;
    };
    await cubit.initialize();
    await recording.setForeground(false);
    service.send(location(1));
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(lookups, 0);
  });

  test('GPS-only changes preserve polyline state identity', () async {
    await cubit.initialize();
    final points = cubit.state.points;
    service.send(location(1));
    await tick();
    expect(cubit.state.points, same(points));
  });

  test('tile failures can be retried without affecting recording', () {
    cubit.tilesFailed();
    expect(cubit.state.tileError, isTrue);
    cubit.retryTiles();
    expect(cubit.state.tileError, isFalse);
    expect(cubit.state.tileGeneration, 1);
  });
}

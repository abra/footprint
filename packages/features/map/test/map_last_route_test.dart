import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_state.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

void main() {
  late FakeLocationService locationService;
  late FakeRoutesRepository routes;
  late RecordingService recording;
  late MapCubit cubit;

  Future<void> tick() => Future<void>.delayed(Duration.zero);

  setUp(() async {
    locationService = FakeLocationService()..lastLocation = location(1);
    routes = FakeRoutesRepository();
    recording = RecordingService(
      locationService: locationService,
      routesRepository: routes,
    );
    cubit = MapCubit(
      recordingService: recording,
      photosRepository: FakeRoutePhotosRepository(),
      geocodingManager: FakeGeocodingManager(),
    );
    await cubit.initialize();
  });

  tearDown(() async {
    await cubit.close();
    await recording.dispose();
    await locationService.dispose();
  });

  Future<void> recordRoute() async {
    await cubit.startRecording();
    locationService.send(location(2));
    await tick();
    await cubit.stopRecording();
  }

  test(
    'hiding is presentation-only and survives GPS and lifecycle updates',
    () async {
      expect(cubit.state.showsLastRoute, isFalse);
      await recordRoute();
      expect(cubit.state.showsLastRoute, isTrue);
      final saved = routes.saved[1]!;
      final points = cubit.state.points;
      cubit.hideLastRoute();
      expect(cubit.state.showsRoute, isFalse);
      expect(cubit.state.points, same(points));
      expect(cubit.state.completedRouteId, 1);

      locationService.send(location(3));
      await tick();
      await recording.setForeground(false);
      await recording.setForeground(true);
      expect(cubit.state.location, location(3));
      expect(cubit.state.showsRoute, isFalse);
      expect(cubit.state.points, same(points));
      expect(routes.saved[1], same(saved));

      await cubit.startRecording();
      expect(cubit.state.lastRouteHidden, isFalse);
      expect(cubit.state.showsRoute, isTrue);
      expect(cubit.state.showsLastRoute, isFalse);
      expect(cubit.state.points, [location(3)]);
      cubit.hideLastRoute();
      expect(cubit.state.lastRouteHidden, isFalse);
      await cubit.stopRecording();
      expect(cubit.state.showsLastRoute, isTrue);
      expect(cubit.state.completedRouteId, 2);
      expect(routes.saved[1], same(saved));
    },
  );

  for (final hidden in [false, true]) {
    test(
      'pending start hides old geometry and failure restores visibility (hidden: $hidden)',
      () async {
        await recordRoute();
        if (hidden) cubit.hideLastRoute();
        final points = cubit.state.points;
        routes.startGate = Completer<int>();
        final start = cubit.startRecording();
        await tick();
        expect(cubit.state.points, isEmpty);
        expect(cubit.state.metrics.distance, 0);
        expect(cubit.state.showsLastRoute, isFalse);
        routes.startGate!.completeError(StateError('Disk full'));
        await start;
        await tick();
        expect(cubit.state.isRecording, isFalse);
        expect(cubit.state.lastRouteHidden, hidden);
        expect(cubit.state.showsLastRoute, !hidden);
        expect(cubit.state.points, points);
        expect(cubit.state.completedRouteId, 1);
        expect(routes.saved.keys, [1]);
      },
    );
  }

  test('a failed stop remains an active route until saving succeeds', () async {
    await cubit.startRecording();
    routes.failFinish = true;
    await cubit.stopRecording();
    expect(cubit.state.showsLastRoute, isFalse);
    expect(cubit.state.isRecording, isTrue);
    cubit.hideLastRoute();
    expect(cubit.state.lastRouteHidden, isFalse);
    routes.failFinish = false;
    await cubit.retry();
    expect(cubit.state.showsLastRoute, isTrue);
  });

  test('empty traces and closed screens cannot be dismissed', () async {
    cubit.hideLastRoute();
    expect(cubit.state.lastRouteHidden, isFalse);
    expect(
      MapState(
        points: [
          LocationDM(
            id: 'invalid',
            latitude: double.nan,
            longitude: 60,
            timestamp: DateTime(2026),
          ),
        ],
      ).showsLastRoute,
      isFalse,
    );
    await recordRoute();
    final state = cubit.state;
    await cubit.close();
    cubit.hideLastRoute();
    expect(cubit.state, state);
  });
}

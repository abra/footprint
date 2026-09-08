import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_planning/route_planning.dart';

import 'fakes.dart';

void main() {
  late FakeLocationService location;
  late FakeRoutesRepository routes;
  late RecordingService recording;
  late FakePlanner planner;
  late FakeWalks walks;
  late ExploreCubit cubit;
  setUp(() async {
    location = FakeLocationService()
      ..lastLocation = walkFix(loopPlan().points.first, 0);
    routes = FakeRoutesRepository();
    recording = RecordingService(
      locationService: location,
      routesRepository: routes,
    );
    planner = FakePlanner();
    walks = FakeWalks();
    cubit = ExploreCubit(
      planner: planner,
      walks: walks,
      recording: recording,
      now: () => walkEpoch.add(const Duration(seconds: 1)),
    );
    await cubit.initialize();
  });
  tearDown(() async {
    await cubit.close();
    planner.dispose();
    await recording.dispose();
    await location.dispose();
  });

  for (final fails in [false, true]) {
    test(
      'regeneration preserves the preview after ${fails ? 'failure' : 'cancellation'}',
      () async {
        await cubit.generate();
        final before = cubit.state;
        planner.pending = Completer<RoutePlan>();
        final generating = cubit.generate();
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.generating, isTrue);
        expect(cubit.state.plan, same(before.plan));
        expect(cubit.state.newAreas, before.newAreas);
        await cubit.start();
        expect(recording.state.isRecording, isFalse);
        if (fails) {
          planner.pending!.completeError(
            const RoutePlanningException('Offline'),
          );
        } else {
          cubit.cancelGeneration();
          planner.pending!.complete(loopPlan(start: const GeoPoint(0.0001, 0)));
        }
        expect(await generating, isFalse);
        expect(cubit.state.generating, isFalse);
        expect(cubit.state.plan, same(before.plan));
        expect(cubit.state.newAreas, before.newAreas);
        expect(cubit.state.previousPreview, isNull);
        expect(cubit.state.error, fails ? 'Offline' : null);
      },
    );
  }

  test('location refresh is single-flight and blocks overlapping plan/start commands', () async {
    await cubit.generate();
    final plan = cubit.state.plan;
    location.currentLocationGate = Completer<LocationDM>();
    final refresh = cubit.refreshStartLocation();
    await Future<void>.delayed(Duration.zero);
    await cubit.refreshStartLocation();
    expect(await cubit.generate(), isFalse);
    await cubit.start();
    expect(location.currentLocationRequests, 1);
    expect(planner.calls, 1);
    expect(recording.state.isRecording, isFalse);
    location.currentLocationGate!.complete(walkFix(plan!.points.first, 1));
    await refresh;
    expect(cubit.state.locating, isFalse);
    expect(cubit.state.plan, same(plan));
  });

  test('previous preview restores its geometry and estimate without another request', () async {
    expect(await cubit.generate(), isTrue);
    final before = cubit.state;
    walks.cells = [ExplorationCell.at(loopPlan().points.first)];
    planner.pending = Completer<RoutePlan>()
      ..complete(loopPlan(start: const GeoPoint(0.0001, 0)));
    await cubit.generate();
    expect(cubit.state.plan, isNot(same(before.plan)));
    expect(cubit.state.previousPreview!.plan, same(before.plan));
    cubit.restorePreviousPreview();
    expect(cubit.state.plan, same(before.plan));
    expect(cubit.state.newAreas, before.newAreas);
    expect(cubit.state.previousPreview, isNull);
    expect(planner.calls, 2);
    cubit.restorePreviousPreview();
    expect(cubit.state.plan, same(before.plan));
  });

  test(
    'undo cancels a replacement in flight and rejects the late result',
    () async {
      await cubit.generate();
      final first = cubit.state.plan;
      await cubit.generate();
      planner.pending = Completer<RoutePlan>();
      final generating = cubit.generate();
      await Future<void>.delayed(Duration.zero);
      cubit.restorePreviousPreview();
      planner.pending!.complete(loopPlan(start: const GeoPoint(0.0001, 0)));
      await generating;
      expect(cubit.state.plan, same(first));
      expect(cubit.state.previousPreview, isNull);
      expect(cubit.state.generating, isFalse);
    },
  );

  for (final change in ['distance', 'mode', 'start', 'end', 'clear']) {
    test('$change invalidates both the preview and its undo history', () async {
      await cubit.generate();
      await cubit.generate();
      expect(cubit.state.previousPreview, isNotNull);
      switch (change) {
        case 'distance':
          cubit.selectDistance(5000);
        case 'mode':
          cubit.selectMode(RoutePlanMode.pointToPoint);
        case 'start':
          cubit.selectStart(const GeoPoint(1, 1));
        case 'end':
          cubit.selectEnd(const GeoPoint(2, 2));
        case 'clear':
          cubit.clearPlan();
      }
      cubit.restorePreviousPreview();
      expect(cubit.state.plan, isNull);
      expect(cubit.state.previousPreview, isNull);
      expect(cubit.state.newAreas, 0);
    });
  }

  test('start distance follows valid fixes and expires without polling', () {
    fakeAsync((clock) {
      final service = FakeLocationService()
        ..lastLocation = walkFix(loopPlan().points.first, 0);
      final recorder = RecordingService(
        locationService: service,
        routesRepository: FakeRoutesRepository(),
      );
      final subject = ExploreCubit(
        planner: FakePlanner(),
        walks: FakeWalks(),
        recording: recorder,
        now: () => walkEpoch.add(clock.elapsed),
      );
      unawaited(subject.initialize());
      clock.flushMicrotasks();
      unawaited(subject.generate());
      clock.flushMicrotasks();
      expect(subject.state.distanceToStart, closeTo(0, 0.01));
      service.send(walkFix(const GeoPoint(0.01, 0), 1));
      clock.flushMicrotasks();
      expect(subject.state.startTooFar, isTrue);
      clock.elapse(const Duration(seconds: 32));
      expect(subject.state.hasRecentLocation, isFalse);
      expect(subject.state.distanceToStart, isNull);
      expect(subject.state.startTooFar, isFalse);
      service.send(walkFix(loopPlan().points.first, 32));
      clock.flushMicrotasks();
      expect(subject.state.distanceToStart, closeTo(0, 0.01));
      unawaited(subject.close());
      clock.flushMicrotasks();
      unawaited(recorder.dispose());
      unawaited(service.dispose());
      clock.flushMicrotasks();
      expect(clock.nonPeriodicTimerCount, 0);
    });
  });

  test('refresh at a distant start obtains a new fix without changing the plan or starting', () async {
    await cubit.generate();
    final plan = cubit.state.plan;
    location.send(walkFix(const GeoPoint(1, 1), 1));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.startTooFar, isTrue);
    location.currentFix = walkFix(plan!.points.first, 2);
    await cubit.refreshStartLocation();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.startTooFar, isFalse);
    expect(cubit.state.plan, same(plan));
    expect(location.currentLocationRequests, 1);
    expect(recording.state.isRecording, isFalse);
    expect(planner.calls, 1);
  });

  test('manual A to B plans without GPS and cannot start far from A', () async {
    cubit.selectMode(RoutePlanMode.pointToPoint);
    const start = GeoPoint(49.4, 8.67);
    const end = GeoPoint(49.41, 8.69);
    cubit.selectStart(start);
    cubit.selectEnd(end);
    location.currentLocationError = LocationServiceDisabledStateException();
    await cubit.generate();
    expect(cubit.state.plan!.mode, RoutePlanMode.pointToPoint);
    expect(cubit.state.plan!.points, [start, end]);
    expect(location.currentLocationRequests, 0);
    expect(cubit.state.visibleError, isNull);
    expect(recording.state.isRecording, isFalse);
    final feedback = await cubit.start();
    expect(recording.state.isRecording, isFalse);
    expect(cubit.state.visibleError, contains('Go to the route start'));
    expect(feedback, contains('100 m'));
    location.send(walkFix(start, 1));
    await Future<void>.delayed(Duration.zero);
    expect(await cubit.start(), isNull);
    expect(recording.state.isRecording, isTrue);
    expect(routes.startedPlan!.mode, RoutePlanMode.pointToPoint);
  });

  test('screen closure does not dispose the shared planner', () async {
    await cubit.close();
    expect(planner.disposals, 0);
    cubit = ExploreCubit(
      planner: planner,
      walks: walks,
      recording: recording,
      now: () => walkEpoch,
    );
    await cubit.initialize();
    await cubit.generate();
    expect(planner.calls, 1);
    expect(cubit.state.plan, isNotNull);
  });

  test(
    'A to B uses fresh GPS only when current location is the start',
    () async {
      cubit.selectMode(RoutePlanMode.pointToPoint);
      cubit.selectEnd(pointToPointPlan().points.last);
      location.send(walkFix(loopPlan().points.first, -600));
      await Future<void>.delayed(Duration.zero);
      location.currentFix = walkFix(loopPlan().points.first, 1);
      await cubit.generate();
      expect(cubit.state.plan!.points.first, loopPlan().points.first);
      expect(location.currentLocationRequests, 1);
    },
  );

  test(
    'missing destination is reported before acquiring GPS or generating',
    () async {
      cubit.selectMode(RoutePlanMode.pointToPoint);
      await cubit.generate();
      expect(cubit.state.error, contains('Choose a destination'));
      expect(location.currentLocationRequests, 0);
      expect(planner.calls, 0);
    },
  );

  test(
    'endpoints can be swapped, cleared and retained across mode changes',
    () async {
      final plan = pointToPointPlan();
      cubit.selectDistance(5000);
      cubit.selectMode(RoutePlanMode.pointToPoint);
      cubit.selectStart(plan.points.first);
      cubit.selectEnd(plan.points.last);
      await cubit.generate();
      cubit.swapEndpoints();
      expect(cubit.state.plan, isNull);
      expect(cubit.state.start, plan.points.last);
      expect(cubit.state.end, plan.points.first);
      cubit.selectMode(RoutePlanMode.loop);
      expect(cubit.state.distance, 5000);
      await cubit.generate();
      expect(cubit.state.plan!.isLoop, isTrue);
      expect(cubit.state.plan!.points.first, loopPlan().points.first);
      cubit.selectMode(RoutePlanMode.pointToPoint);
      expect(cubit.state.start, plan.points.last);
      cubit.selectStart(null);
      expect(cubit.state.start, isNull);
      cubit.selectEnd(null);
      expect(cubit.state.end, isNull);
    },
  );

  test(
    'editing endpoints cancels generation and ignores a late response',
    () async {
      final plan = pointToPointPlan();
      cubit.selectMode(RoutePlanMode.pointToPoint);
      cubit.selectStart(plan.points.first);
      cubit.selectEnd(plan.points.last);
      planner.pending = Completer<RoutePlan>();
      final generating = cubit.generate();
      await Future<void>.delayed(Duration.zero);
      cubit.selectEnd(const GeoPoint(0.02, 0.0005));
      planner.pending!.complete(plan);
      await generating;
      expect(cubit.state.generating, isFalse);
      expect(cubit.state.plan, isNull);
      expect(cubit.state.end, const GeoPoint(0.02, 0.0005));
    },
  );

  test(
    'mode switch cancels GPS wait and a manual route ignores its late error',
    () async {
      location.send(walkFix(loopPlan().points.first, -600));
      await Future<void>.delayed(Duration.zero);
      location.currentLocationGate = Completer<LocationDM>();
      final pending = cubit.generate();
      cubit.selectMode(RoutePlanMode.pointToPoint);
      await pending;
      cubit.selectStart(pointToPointPlan().points.first);
      cubit.selectEnd(pointToPointPlan().points.last);
      await cubit.generate();
      location.currentLocationGate!.completeError(TimeoutException('Late GPS'));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.plan!.mode, RoutePlanMode.pointToPoint);
      expect(cubit.state.visibleError, isNull);
    },
  );

  test('active recordings and invalid coordinates cannot be edited', () async {
    cubit.selectStart(const GeoPoint(double.nan, 0));
    cubit.selectEnd(const GeoPoint(91, 0));
    expect(cubit.state.start, isNull);
    expect(cubit.state.end, isNull);
    await cubit.generate();
    await cubit.start();
    final active = cubit.state;
    cubit.selectMode(RoutePlanMode.pointToPoint);
    cubit.selectStart(const GeoPoint(1, 1));
    cubit.selectEnd(const GeoPoint(2, 2));
    cubit.swapEndpoints();
    expect(cubit.state, active);
  });

  test('generates a plan without recording; starts it once and leaves ownership to recording service', () async {
    await cubit.generate();
    expect(cubit.state.plan, isNotNull);
    expect(location.currentLocationRequests, 0);
    expect(recording.state.isRecording, isFalse);
    final plan = cubit.state.plan;
    await Future.wait([cubit.start(), cubit.start()]);
    expect(recording.state.isRecording, isTrue);
    expect(routes.startedPlan, plan);
    expect(cubit.state.startedRouteId, recording.state.routeId);
    await cubit.close();
    expect(recording.state.isRecording, isTrue);
    expect(location.disposed, isFalse);
  });

  test(
    'changing distance cancels generation and ignores its late result',
    () async {
      planner.pending = Completer<RoutePlan>();
      final generating = cubit.generate();
      await Future<void>.delayed(Duration.zero);
      expect(planner.calls, 1);
      cubit.selectDistance(5000);
      planner.pending!.complete(loopPlan(distance: 3000));
      await generating;
      expect(cubit.state.plan, isNull);
      expect(cubit.state.distance, 5000);
      expect(cubit.state.generating, isFalse);
    },
  );

  test('clearing a preview preserves distance, location, discoveries and saved routes', () async {
    routes.saved[9] = RouteDM(
      id: 9,
      startTime: walkEpoch,
      endTime: walkEpoch.add(const Duration(minutes: 10)),
      status: Status.completed,
      routePoints: const [],
    );
    final saved = Map.of(routes.saved);
    walks.profile = const ExplorationProfile(cells: 12, completedWalks: 1);
    walks.cells = [ExplorationCell.at(loopPlan().points.first)];
    await cubit.refreshProfile();
    cubit.loadCells(south: -1, north: 1, west: -1, east: 1);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    cubit.selectDistance(5000);
    await cubit.generate();
    final before = cubit.state;
    expect(before.newAreas, greaterThan(0));
    cubit.clearPlan();
    expect(cubit.state.plan, isNull);
    expect(cubit.state.newAreas, 0);
    expect(cubit.state.distance, before.distance);
    expect(cubit.state.location, before.location);
    expect(cubit.state.profile, before.profile);
    expect(cubit.state.cells, walks.cells);
    expect(routes.saved, saved);
    expect(routes.active, isNull);
    expect(recording.state.isRecording, isFalse);
    await cubit.start();
    expect(routes.startedPlan, isNull);
    await cubit.generate();
    expect(cubit.state.plan!.requestedDistance, 5000);
  });

  for (final fails in [false, true]) {
    test(
      'clear cancels generation and ignores a late ${fails ? 'error' : 'result'}',
      () async {
        planner.pending = Completer<RoutePlan>();
        final generation = cubit.generate();
        await Future<void>.delayed(Duration.zero);
        expect(planner.calls, 1);
        cubit.clearPlan();
        expect(planner.cancellations, 1);
        expect(cubit.state.generating, isFalse);
        if (fails) {
          planner.pending!.completeError(
            const RoutePlanningException('Late error'),
          );
        } else {
          planner.pending!.complete(loopPlan(distance: 3000));
        }
        await generation;
        expect(cubit.state.plan, isNull);
        expect(cubit.state.error, isNull);
        expect(cubit.state.newAreas, 0);
      },
    );
  }

  test(
    'clear cannot alter a starting or active recording, or emit after closure',
    () async {
      await cubit.generate();
      final plan = cubit.state.plan;
      routes.startGate = Completer<int>();
      final starting = cubit.start();
      try {
        expect(cubit.state.starting, isTrue);
        cubit.clearPlan();
        expect(cubit.state.plan, same(plan));
      } finally {
        routes.startGate!.complete(1);
        await starting;
      }
      final recordingState = recording.state;
      final active = cubit.state;
      cubit.clearPlan();
      expect(cubit.state, active);
      expect(recording.state, recordingState);
      expect(routes.startedPlan, same(plan));
      expect(routes.active, isNotNull);
      await cubit.close();
      cubit.clearPlan();
      expect(cubit.state, active);
    },
  );

  test(
    'rapid duplicate generation and closing cancel only presentation work',
    () async {
      planner.pending = Completer<RoutePlan>();
      final generation = cubit.generate();
      await cubit.generate();
      await Future<void>.delayed(Duration.zero);
      expect(planner.calls, 1);
      await cubit.close();
      planner.pending!.complete(loopPlan(distance: 3000));
      await generation;
      expect(cubit.isClosed, isTrue);
      expect(location.disposed, isFalse);
    },
  );

  test(
    'missing configuration, network and database failures are explicit',
    () async {
      planner.available = false;
      await cubit.generate();
      expect(cubit.state.error, 'Route planning is not configured.');
      expect(planner.calls, 0);
      planner.available = true;
      planner.error = const RoutePlanningException('Network unavailable');
      await cubit.generate();
      expect(cubit.state.error, 'Network unavailable');
      planner.error = null;
      walks.failure = StateError('database unavailable');
      await cubit.generate();
      expect(cubit.state.generating, isFalse);
      expect(cubit.state.error, isNotNull);
    },
  );

  test(
    'stale or inaccurate location cannot generate or start a planned walk',
    () async {
      await cubit.generate();
      location.send(walkFix(loopPlan().points.first, -50));
      await Future<void>.delayed(Duration.zero);
      await cubit.start();
      expect(recording.state.isRecording, isFalse);
      await cubit.generate();
      expect(cubit.state.visibleError, contains('accurate'));
      location.send(walkFix(loopPlan().points.first, 0, accuracy: null));
      await Future<void>.delayed(Duration.zero);
      await cubit.generate();
      expect(planner.calls, 1);
    },
  );

  test(
    'stationary stale preview is refreshed and generation continues once',
    () async {
      final start = loopPlan().points.first;
      location.send(walkFix(start, -600));
      await Future<void>.delayed(Duration.zero);
      location.currentLocationGate = Completer<LocationDM>();
      final generating = cubit.generate();
      await cubit.generate();
      expect(cubit.state.generating, isTrue);
      expect(cubit.state.locating, isTrue);
      expect(cubit.state.visibleError, isNull);
      expect(planner.calls, 0);
      expect(location.currentLocationRequests, 1);
      location.currentLocationGate!.complete(walkFix(start, 1));
      await generating;
      expect(cubit.state.plan!.points.first, start);
      expect(planner.calls, 1);
      expect(cubit.state.generating, isFalse);
      expect(cubit.state.locating, isFalse);
      expect(recording.state.isRecording, isFalse);
      expect(
        recording.state.location!.timestamp,
        walkEpoch.add(const Duration(seconds: 1)),
      );
    },
  );

  test(
    'a newly requested fix is used when there has been no preview fix',
    () async {
      await cubit.close();
      await recording.dispose();
      await location.dispose();
      location = FakeLocationService()
        ..currentFix = walkFix(loopPlan().points.first, 1);
      recording = RecordingService(
        locationService: location,
        routesRepository: routes,
      );
      cubit = ExploreCubit(
        planner: planner,
        walks: walks,
        recording: recording,
        now: () => walkEpoch,
      );
      await cubit.initialize();
      expect(cubit.state.location, isNull);
      await cubit.generate();
      expect(cubit.state.plan, isNotNull);
      expect(location.currentLocationRequests, 1);
    },
  );

  test(
    'Start walk refreshes an expired preview without regenerating the plan',
    () async {
      await cubit.generate();
      final plan = cubit.state.plan;
      location.send(walkFix(plan!.points.first, -600));
      await Future<void>.delayed(Duration.zero);
      location.currentFix = walkFix(plan.points.first, 1);
      await cubit.start();
      expect(recording.state.isRecording, isTrue);
      expect(recording.state.points.first, location.currentFix);
      expect(routes.startedPlan, same(plan));
      expect(planner.calls, 1);
      expect(cubit.state.locating, isFalse);
    },
  );

  for (final fix in [
    walkFix(loopPlan().points.first, -30),
    walkFix(loopPlan().points.first, 7),
    walkFix(loopPlan().points.first, 1, accuracy: null),
    walkFix(loopPlan().points.first, 1, accuracy: 0),
    walkFix(loopPlan().points.first, 1, accuracy: 40),
  ]) {
    test(
      'one-shot fix with invalid quality/time is not trusted: ${fix.timestamp}, ${fix.accuracy}',
      () async {
        location.send(walkFix(loopPlan().points.first, -600));
        await Future<void>.delayed(Duration.zero);
        location.currentFix = fix;
        await cubit.generate();
        expect(planner.calls, 0);
        expect(cubit.state.visibleError, contains('accurate, recent'));
        expect(cubit.state.generating, isFalse);
        expect(cubit.state.locating, isFalse);
      },
    );
  }

  for (final (failure, message) in [
    (TimeoutException('No fix'), 'did not respond in time'),
    (LocationServiceDisabledStateException(), 'Location services are off'),
    (LocationServicePermissionDeniedException(), 'permission is required'),
    (LocationServicePermanentlyDeniedException(), 'device settings'),
  ]) {
    test(
      'location failure is actionable and can be retried: $failure',
      () async {
        location.send(walkFix(loopPlan().points.first, -600));
        await Future<void>.delayed(Duration.zero);
        location.currentLocationError = failure;
        await cubit.generate();
        expect(cubit.state.visibleError, contains(message));
        expect(planner.calls, 0);
        expect(cubit.state.generating, isFalse);
        expect(cubit.state.locating, isFalse);
        location.currentLocationError = null;
        location.currentFix = walkFix(loopPlan().points.first, 1);
        await cubit.generate();
        expect(cubit.state.plan, isNotNull);
        expect(cubit.state.visibleError, isNull);
      },
    );
  }

  for (final (failure, message) in [
    (TimeoutException('No fix'), 'did not respond in time'),
    (LocationServiceDisabledStateException(), 'Location services are off'),
    (LocationServicePermissionDeniedException(), 'permission is required'),
    (LocationServicePermanentlyDeniedException(), 'device settings'),
  ]) {
    test(
      'manual start returns GPS failure feedback and can be retried: $failure',
      () async {
        final plan = pointToPointPlan();
        cubit.selectMode(RoutePlanMode.pointToPoint);
        cubit.selectStart(plan.points.first);
        cubit.selectEnd(plan.points.last);
        await cubit.generate();
        final generated = cubit.state.plan;
        location.send(walkFix(plan.points.first, -600));
        await Future<void>.delayed(Duration.zero);
        location.currentLocationError = failure;
        final feedback = await cubit.start();
        expect(feedback, contains(message));
        expect(cubit.state.starting, isFalse);
        expect(cubit.state.locating, isFalse);
        expect(cubit.state.plan, same(generated));
        expect(recording.state.isRecording, isFalse);
        expect(routes.saved, isEmpty);
        location.currentLocationError = null;
        location.send(walkFix(plan.points.first, 1));
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.visibleError, isNull);
        expect(feedback, contains(message));
        expect(await cubit.start(), isNull);
        expect(recording.state.isRecording, isTrue);
        expect(routes.startedPlan, same(generated));
        expect(planner.calls, 1);
      },
    );
  }

  for (final close in [false, true]) {
    test(
      '${close ? 'closing' : 'cancel'} stops waiting and ignores late GPS',
      () async {
        location.send(walkFix(loopPlan().points.first, -600));
        await Future<void>.delayed(Duration.zero);
        location.currentLocationGate = Completer<LocationDM>();
        final generating = cubit.generate();
        if (close) {
          await cubit.close();
        } else {
          cubit.cancelGeneration();
          expect(cubit.state.generating, isFalse);
          expect(cubit.state.locating, isFalse);
        }
        await generating;
        location.currentLocationGate!.complete(
          walkFix(loopPlan().points.first, 1),
        );
        await Future<void>.delayed(Duration.zero);
        expect(planner.calls, 0);
        expect(cubit.state.plan, isNull);
        expect(cubit.state.visibleError, isNull);
        expect(recording.state.isRecording, isFalse);
      },
    );
  }

  test(
    'GPS recovery clears location errors but preserves routing errors',
    () async {
      location.send(walkFix(loopPlan().points.first, -600));
      await Future<void>.delayed(Duration.zero);
      location.currentLocationError = TimeoutException('No fix');
      await cubit.generate();
      expect(cubit.state.locationError, isNotNull);
      location.send(walkFix(loopPlan().points.first, 1));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.visibleError, isNull);
      planner.error = const RoutePlanningException('Network unavailable');
      await cubit.generate();
      location.send(walkFix(loopPlan().points.first, 2));
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.visibleError, 'Network unavailable');
    },
  );

  test('moving away from the start prevents starting a stale plan', () async {
    await cubit.generate();
    location.send(walkFix(const GeoPoint(1, 1), 1));
    await Future<void>.delayed(Duration.zero);
    await cubit.start();
    expect(cubit.state.error, contains('no longer nearby'));
    expect(recording.state.isRecording, isFalse);
  });

  test(
    'failed recording start remains visible and never announces success',
    () async {
      await cubit.generate();
      routes.failStart = true;
      final feedback = await cubit.start();
      expect(cubit.state.startedRouteId, isNull);
      expect(feedback, contains('could not be started'));
      expect(cubit.state.error, contains('could not be started'));
      expect(cubit.state.starting, isFalse);
    },
  );
}

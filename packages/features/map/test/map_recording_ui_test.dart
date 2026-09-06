import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/map.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:map/src/recording_indicator.dart';
import 'package:map/src/route_speed_chart.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';
import 'pump_recording_ui.dart';

class StreamRecording extends Fake implements RecordingService {
  final controller = StreamController<RecordingState>.broadcast(sync: true);
  @override
  RecordingState state = const RecordingState();
  @override
  Stream<RecordingState> get states => controller.stream;
  @override
  Future<void> attachPreview() async {}
  @override
  Future<void> detachPreview() async {}
  void send(RecordingState value) {
    state = value;
    controller.add(value);
  }
}

void main() {
  testWidgets(
    'recording transitions keep a readable button without loading spinners',
    (tester) async {
      final recording = StreamRecording();
      final cubit = MapCubit(
        recordingService: recording,
        photosRepository: FakeRoutePhotosRepository(),
        geocodingManager: FakeGeocodingManager(),
      );
      await cubit.initialize();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BlocProvider.value(
            value: cubit,
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      );
      for (final phase in [RecordingPhase.starting, RecordingPhase.stopping]) {
        recording.send(
          RecordingState(
            phase: phase,
            routeId: 1,
            location: location(1),
            points: [location(1)],
          ),
        );
        await tester.pump();
        final label = phase == RecordingPhase.starting
            ? 'Stop recording'
            : 'Saving route...';
        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, label),
        );
        expect(button.onPressed, isNull);
        final states = {WidgetState.disabled};
        expect(button.style!.backgroundColor!.resolve(states), Colors.white);
        final foreground = button.style!.foregroundColor!.resolve(states)!;
        expect(foreground.a, 1);
        expect(
          find.descendant(
            of: find.byType(FilledButton),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsNothing,
        );
        expect(
          tester
              .widget<RecordingIndicator>(find.byType(RecordingIndicator))
              .pulsing,
          isFalse,
        );
        expect(find.byIcon(Icons.stop_circle_outlined), findsNothing);
      }
      recording.send(
        RecordingState(
          phase: RecordingPhase.stopping,
          routeId: 1,
          location: location(1),
          failure: RecordingFailure(
            RecordingOperation.stop,
            StateError('Disk full'),
            StackTrace.current,
          ),
        ),
      );
      await pumpRecordingUi(tester);
      expect(find.text('Saving route...'), findsNothing);
      expect(
        tester
            .widget<RecordingIndicator>(find.byType(RecordingIndicator))
            .pulsing,
        isTrue,
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Stop recording'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        find.text('Recording could not be stopped. Please try again.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.runAsync(() async {
        await cubit.close();
        await recording.controller.close();
      });
      expect(tester.takeException(), isNull);
    },
  );

  test('stats mode survives updates and resets for a new recording', () async {
    final recording = StreamRecording();
    final cubit = MapCubit(
      recordingService: recording,
      photosRepository: FakeRoutePhotosRepository(),
      geocodingManager: FakeGeocodingManager(),
    );
    await cubit.initialize();
    cubit.toggleStats();
    expect(cubit.state.statsExpanded, isFalse);
    recording.send(
      RecordingState(
        phase: RecordingPhase.recording,
        routeId: 1,
        points: [location(1)],
        location: location(1),
      ),
    );
    cubit.toggleStats();
    expect(cubit.state.statsExpanded, isTrue);
    recording.send(
      recording.state.copyWith(
        points: [location(1), location(2)],
        location: location(2),
      ),
    );
    expect(cubit.state.statsExpanded, isTrue);
    expect(cubit.state.metrics.speedHistory, hasLength(1));
    recording.send(recording.state.copyWith(foreground: false));
    expect(cubit.state.statsExpanded, isTrue);
    recording.send(const RecordingState());
    expect(cubit.state.statsExpanded, isFalse);
    recording.send(
      RecordingState(
        phase: RecordingPhase.recording,
        routeId: 2,
        points: [location(3)],
        location: location(3),
      ),
    );
    expect(cubit.state.statsExpanded, isFalse);
    await cubit.close();
    cubit.toggleStats();
    await recording.controller.close();
  });
  test(
    'live duration ticks without GPS and stops when hidden or closed',
    () async {
      final recording = StreamRecording();
      late MapCubit cubit;
      late FakeAsync timerClock;
      fakeAsync((clock) {
        timerClock = clock;
        var now = location(1).timestamp;
        cubit = MapCubit(
          photosRepository: FakeRoutePhotosRepository(),
          recordingService: recording,
          geocodingManager: FakeGeocodingManager(),
          now: () => now,
        );
        unawaited(cubit.initialize());
        clock.flushMicrotasks();
        recording.send(
          RecordingState(
            phase: RecordingPhase.recording,
            routeId: 1,
            points: [location(1)],
            location: location(1),
          ),
        );
        now = now.add(const Duration(seconds: 5));
        clock.elapse(const Duration(seconds: 1));
        expect(cubit.state.metrics.duration, const Duration(seconds: 5));
        expect(cubit.state.metrics.distance, 0);
        recording.send(recording.state.copyWith(foreground: false));
        now = now.add(const Duration(seconds: 5));
        clock.elapse(const Duration(seconds: 2));
        expect(cubit.state.metrics.duration, const Duration(seconds: 5));
        recording.send(recording.state.copyWith(foreground: true));
        clock.flushMicrotasks();
        expect(cubit.state.metrics.duration, const Duration(seconds: 10));
      });
      await cubit.close();
      await recording.controller.close();
      expect(cubit.isClosed, isTrue);
      expect(timerClock.periodicTimerCount, 0);
    },
  );
  testWidgets(
    'save screen is requested only once after stop successfully retries',
    (tester) async {
      final service = FakeLocationService()..lastLocation = location(1);
      final repository = FakeRoutesRepository();
      final recording = RecordingService(
        locationService: service,
        routesRepository: repository,
      );
      final completed = <int>[];
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () {},
            onRouteCompleted: completed.add,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
      await tester.tap(find.text('Record route'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('recording-stats-panel')));
      await tester.pumpAndSettle();
      expect(cubit.state.statsExpanded, isTrue);
      expect(find.byType(RouteSpeedChart), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('recording-stats-panel')));
      await tester.pumpAndSettle();
      expect(cubit.state.statsExpanded, isFalse);
      expect(find.byType(RouteSpeedChart), findsNothing);
      repository.failFinish = true;
      await tester.tap(find.text('Stop recording'));
      await tester.pumpAndSettle();
      expect(completed, isEmpty);
      repository.failFinish = false;
      final retry = cubit.retry();
      await tester.pump();
      await retry;
      await tester.pumpAndSettle();
      expect(completed, [1]);
      service.send(location(2));
      await tester.pumpAndSettle();
      expect(completed, [1]);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await recording.dispose();
        await service.dispose();
      });
    },
  );
}

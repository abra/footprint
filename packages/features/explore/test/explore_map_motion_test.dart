import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:explore/src/planning_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:recording_service/recording_service.dart';

import '../../../component_library/test/load_fonts.dart';
import '../../../component_library/test/pump_map_ui.dart';
import 'fakes.dart' hide location;

LocationDM location(int index) =>
    walkFix(GeoPoint(56 + index * 0.00002, 60), index);

LatLng markerPoint(WidgetTester tester) => tester
    .widget<MarkerLayer>(find.byKey(const ValueKey('current-location-layer')))
    .markers
    .single
    .point;

RouteEndpointMarker endpoint(WidgetTester tester, String letter) => tester
    .widgetList<MarkerLayer>(find.byType(MarkerLayer))
    .expand((layer) => layer.markers)
    .whereType<RouteEndpointMarker>()
    .singleWhere((marker) => marker.letter == letter);

class _Harness {
  _Harness() {
    recording = RecordingService(
      locationService: service,
      routesRepository: repository,
    );
    cubit = ExploreCubit(
      planner: planner,
      walks: FakeWalks(),
      recording: recording,
      now: () => location(1).timestamp,
    );
  }

  final service = FakeLocationService()..lastLocation = location(1);
  final repository = FakeRoutesRepository();
  final planner = FakePlanner();
  final visible = ValueNotifier(true);
  final reducedMotion = ValueNotifier(false);
  late final RecordingService recording;
  late final ExploreCubit cubit;
  int states = 0;

  Future<void> mount(WidgetTester tester) async {
    await cubit.initialize();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: ValueListenableBuilder<bool>(
            valueListenable: reducedMotion,
            builder: (context, reduced, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: reduced),
              child: child!,
            ),
            child: BlocProvider(
              create: (_) => cubit,
              child: BlocListener<ExploreCubit, ExploreState>(
                listener: (_, _) => states++,
                child: ExploreView(
                  config: const MapTileConfig(),
                  onBack: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await pumpMapUi(tester);
  }

  Future<void> send(WidgetTester tester, int index) async {
    service.send(location(index));
    await tester.pump();
    await tester.pump();
  }

  MapController map(WidgetTester tester) =>
      tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    visible.dispose();
    reducedMotion.dispose();
    await tester.runAsync(() async {
      planner.dispose();
      await recording.dispose();
      await service.dispose();
    });
    expect(tester.takeException(), isNull);
  }
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('GPS playback stays local and does not follow or mutate fixes', (
    tester,
  ) async {
    final harness = _Harness();
    try {
      await harness.mount(tester);
      expect(find.byType(CurrentLocationLayer), findsOneWidget);
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      expect(markerPoint(tester).latitude, location(1).latitude);
      final map = harness.map(tester);
      map.move(const LatLng(56.001, 60.001), map.camera.zoom);
      await pumpMapUi(tester);
      final camera = map.camera.center;
      final panelBounds = tester.getRect(
        find.byKey(const ValueKey('explore-panel')),
      );
      await harness.send(tester, 2);
      expect(markerPoint(tester).latitude, location(1).latitude);
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump();
      final moving = markerPoint(tester);
      expect(
        moving.latitude,
        inExclusiveRange(location(1).latitude, location(2).latitude),
      );
      expect(harness.cubit.state.location, location(2));
      expect(harness.recording.state.location, location(2));
      expect(harness.repository.added, isEmpty);

      harness.states = 0;
      final rebuilt = <Type>[];
      final previousObserver = debugOnRebuildDirtyWidget;
      debugOnRebuildDirtyWidget = (element, builtOnce) {
        previousObserver?.call(element, builtOnce);
        rebuilt.add(element.widget.runtimeType);
      };
      try {
        for (var frame = 0; frame < 20; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(markerPoint(tester).latitude, greaterThan(moving.latitude));
        expect(rebuilt, contains(MarkerLayer));
        for (final type in [ExploreView, PlanningSettings, AppBar, AppButton]) {
          expect(rebuilt, isNot(contains(type)));
        }
        expect(harness.states, 0);
        expect(map.camera.center, camera);
        expect(
          tester.getRect(find.byKey(const ValueKey('explore-panel'))),
          panelBounds,
        );
      } finally {
        debugOnRebuildDirtyWidget = previousObserver;
      }
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(markerPoint(tester).latitude, location(2).latitude);
      expect(map.camera.center, camera);
      expect(tester.binding.transientCallbackCount, 0);
      // Dispose during the next segment, not only after playback has drained.
      await harness.send(tester, 3);
      await tester.pump(const Duration(milliseconds: 400));
    } finally {
      await harness.dispose(tester);
    }
  });

  for (final reducedInitially in [false, true]) {
    testWidgets('reduced motion snaps the planner marker ($reducedInitially)', (
      tester,
    ) async {
      final harness = _Harness()..reducedMotion.value = reducedInitially;
      try {
        await harness.mount(tester);
        await harness.send(tester, 2);
        if (!reducedInitially) {
          await tester.pump(const Duration(milliseconds: 400));
          expect(markerPoint(tester).latitude, lessThan(location(2).latitude));
          harness.reducedMotion.value = true;
          await tester.pump();
        }
        expect(markerPoint(tester).latitude, location(2).latitude);
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
        harness.reducedMotion.value = false;
        await pumpMapUi(tester);
        await harness.send(tester, 3);
        await tester.pump(const Duration(milliseconds: 400));
        expect(
          markerPoint(tester).latitude,
          inExclusiveRange(location(2).latitude, location(3).latitude),
        );
      } finally {
        await harness.dispose(tester);
      }
    });
  }

  testWidgets('hidden planner stops playback and resumes from the latest fix', (
    tester,
  ) async {
    final harness = _Harness();
    try {
      await harness.mount(tester);
      await harness.send(tester, 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(markerPoint(tester).latitude, lessThan(location(2).latitude));
      harness.visible.value = false;
      await tester.pumpAndSettle();
      expect(markerPoint(tester).latitude, location(2).latitude);
      await harness.send(tester, 3);
      await tester.pumpAndSettle();
      expect(markerPoint(tester).latitude, location(3).latitude);
      expect(tester.binding.transientCallbackCount, 0);
      harness.visible.value = true;
      await pumpMapUi(tester);
      expect(markerPoint(tester).latitude, location(3).latitude);
      await harness.send(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        markerPoint(tester).latitude,
        inExclusiveRange(location(3).latitude, location(4).latitude),
      );
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets('only automatic A follows playback, routing uses actual fixes', (
    tester,
  ) async {
    final harness = _Harness();
    try {
      await harness.mount(tester);
      final cubit = harness.cubit;
      cubit.selectMode(RoutePlanMode.pointToPoint);
      cubit.selectEnd(const GeoPoint(56.001, 60.001));
      await pumpMapUi(tester);
      final destination = endpoint(tester, 'B').point;
      await harness.send(tester, 2);
      await tester.pump(const Duration(milliseconds: 400));
      expect(endpoint(tester, 'A').point, markerPoint(tester));
      expect(endpoint(tester, 'B').point, destination);
      expect(markerPoint(tester).latitude, lessThan(location(2).latitude));
      final map = harness.map(tester);
      map.move(const LatLng(56.001, 60.001), map.camera.zoom);
      await tester.pump();
      await tester.tap(find.byTooltip('Center map'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));
      expect(harness.map(tester).camera.zoom, 15);
      expect(
        harness.map(tester).camera.center.longitude,
        closeTo(60, 0.000001),
      );
      // Generating while the marker lags must not submit its visual coordinates.
      expect(await cubit.generate(), isTrue);
      await tester.pump();
      final plan = cubit.state.plan!;
      expect(plan.points.first.latitude, location(2).latitude);
      expect(plan.points.first.longitude, location(2).longitude);
      await harness.send(tester, 3);
      await tester.pump(const Duration(milliseconds: 400));
      expect(cubit.state.plan, same(plan));
      expect(endpoint(tester, 'A').point, plan.points.first.latLng);

      cubit.clearPlan();
      cubit.selectStart(const GeoPoint(56, 60.001));
      await pumpMapUi(tester);
      final start = endpoint(tester, 'A').point;
      await harness.send(tester, 4);
      await tester.pump(const Duration(milliseconds: 400));
      expect(endpoint(tester, 'A').point, start);
      expect(endpoint(tester, 'B').point, destination);
      expect(markerPoint(tester).latitude, lessThan(location(4).latitude));
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
    } finally {
      await harness.dispose(tester);
    }
  });
}

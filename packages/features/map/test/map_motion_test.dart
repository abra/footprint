import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/map.dart';
import 'package:map/src/center_location_icon.dart';
import 'package:map/src/map_app_bar.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_state.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';
import '../../../component_library/test/pump_map_ui.dart';
import '../../../foreground_location_service/test/gps_fixtures.dart';

LatLng markerPoint(WidgetTester tester) => tester
    .widget<MarkerLayer>(find.byKey(const ValueKey('current-location-layer')))
    .markers
    .single
    .point;

class _UnusedRecordingService extends Fake implements RecordingService {}

void main() {
  testWidgets(
    'follow UX toggles, releases on gestures and restores the chosen mode',
    (tester) async {
      final cubit = MapCubit(
        recordingService: _UnusedRecordingService(),
        photosRepository: FakeRoutePhotosRepository(),
        geocodingManager: FakeGeocodingManager(),
      )..emit(MapState(location: location(1), locationLoading: false));
      final visible = ValueNotifier(true);
      var states = 0;
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: AppTheme.builder,
            home: ValueListenableBuilder<bool>(
              valueListenable: visible,
              builder: (context, enabled, child) =>
                  TickerMode(enabled: enabled, child: child!),
              child: BlocProvider.value(
                value: cubit,
                child: BlocListener<MapCubit, MapState>(
                  listener: (_, _) => states++,
                  child: MapView(
                    config: const MapConfig(),
                    onRoutesRequested: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
        final controller = map.mapController!;
        final bounds = tester.getRect(
          find.byKey(const ValueKey('map-follow-button')),
        );
        expect(find.byTooltip('Follow direction of travel'), findsOneWidget);
        await tester.tap(find.byTooltip('Follow direction of travel'));
        await tester.pumpAndSettle();
        expect(cubit.state.orientation, MapOrientation.courseUp);
        expect(find.byTooltip('Keep north up'), findsOneWidget);
        expect(find.byIcon(Icons.navigation), findsOneWidget);
        cubit.emit(
          cubit.state.copyWith(
            location: location(2).withFilteredPosition(
              latitude: location(1).latitude,
              longitude: 60.0002,
              isStationary: false,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(controller.camera.rotation, closeTo(-90, 0.01));
        final zoom = controller.camera.zoom;
        await tester.tap(find.byTooltip('Zoom in'));
        await tester.pumpAndSettle();
        expect(controller.camera.zoom, zoom + 1);
        expect(cubit.state.centered, isTrue);
        expect(cubit.state.orientation, MapOrientation.courseUp);
        expect(
          tester.getRect(find.byKey(const ValueKey('map-follow-button'))),
          bounds,
        );

        await tester.drag(find.byType(FlutterMap), const Offset(80, 60));
        await tester.pumpAndSettle();
        expect(cubit.state.centered, isFalse);
        expect(find.byTooltip('Center on location'), findsOneWidget);
        await tester.tap(find.byTooltip('Center on location'));
        await tester.pumpAndSettle();
        expect(cubit.state.orientation, MapOrientation.courseUp);
        expect(controller.camera.center, markerPoint(tester));
        // Pure rotation has no onPositionChanged callback in flutter_map.
        map.options.onMapEvent!(
          MapEventRotate(
            id: null,
            source: MapEventSource.onMultiFinger,
            oldCamera: controller.camera,
            camera: controller.camera.withRotation(45),
          ),
        );
        await tester.pumpAndSettle();
        expect(cubit.state.centered, isFalse);
        await tester.tap(find.byTooltip('Center on location'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Keep north up'));
        await tester.pumpAndSettle();
        expect(controller.camera.rotation, 0);
        expect(cubit.state.orientation, MapOrientation.northUp);

        await tester.tap(find.byTooltip('Follow direction of travel'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        visible.value = false;
        await tester.pumpAndSettle();
        expect(controller.camera.rotation, closeTo(-90, 0.01));
        expect(tester.binding.transientCallbackCount, 0);
        visible.value = true;
        await tester.pumpAndSettle();
        states = 0;
        final oldObserver = debugOnRebuildDirtyWidget;
        final rebuilt = <Type>[];
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          oldObserver?.call(element, builtOnce);
          rebuilt.add(element.widget.runtimeType);
        };
        try {
          cubit.emit(
            cubit.state.copyWith(
              location: location(3).withFilteredPosition(
                latitude: location(1).latitude + 0.0001,
                longitude: 60.0002,
                isStationary: false,
              ),
            ),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          rebuilt.clear();
          states = 0;
          for (var frame = 0; frame < 60; frame++) {
            await tester.pump(const Duration(milliseconds: 16));
            final box = tester.renderObject<RenderBox>(
              find.byIcon(Icons.navigation_rounded),
            );
            final localCenter = box.size.center(Offset.zero);
            final direction =
                box.localToGlobal(Offset(localCenter.dx, 0)) -
                box.localToGlobal(localCenter);
            expect(
              (direction - Offset(0, -localCenter.dy)).distance,
              lessThan(0.001),
            );
          }
          expect(states, 0);
          for (final type in [MapView, MapAppBar, AppButton, AppIconButton]) {
            expect(rebuilt, isNot(contains(type)));
          }
        } finally {
          debugOnRebuildDirtyWidget = oldObserver;
        }
        await tester.pumpAndSettle();
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await cubit.close();
        visible.dispose();
      }
    },
  );

  testWidgets(
    'stationary fixes keep the marker, camera and route still while time advances',
    (tester) async {
      final filter = LocationFilter();
      final service = FakeLocationService()
        ..lastLocation = filter.add(fix(0, 0));
      final repository = FakeRoutesRepository();
      final recording = RecordingService(
        locationService: service,
        routesRepository: repository,
      );
      var lookups = 0;
      var now = gpsEpoch;
      final cubit = MapCubit(
        recordingService: recording,
        photosRepository: FakeRoutePhotosRepository(),
        geocodingManager: FakeGeocodingManager()
          ..lookup = (_) async {
            lookups++;
            return null;
          },
        now: () => now,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: AppTheme.builder,
          home: BlocProvider(
            create: (_) => cubit..initialize(),
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      );
      await pumpMapUi(tester);
      await tester.tap(find.text('Record route'));
      await pumpMapUi(tester);
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final marker = markerPoint(tester);
      final camera = controller.camera.center;
      final originalLookups = lookups;
      for (var second = 30; second <= 600; second += 30) {
        now = gpsEpoch.add(Duration(seconds: second));
        service.send(filter.add(fix(second, second % 60 == 0 ? 1 : -1))!);
        await pumpMapUi(tester);
        expect(markerPoint(tester), marker);
        expect(controller.camera.center, camera);
        expect(cubit.state.metrics.distance, 0);
        expect(cubit.state.metrics.currentSpeed, 0);
        expect(cubit.state.isRecording, isTrue);
      }
      expect(cubit.state.metrics.duration, const Duration(minutes: 10));
      expect(lookups, originalLookups);
      final vertices = tester
          .widgetList<PolylineLayer>(find.byType(PolylineLayer))
          .expand((layer) => layer.polylines)
          .expand((line) => line.points);
      expect(vertices, isNotEmpty);
      expect(vertices.every((point) => point == marker), isTrue);
      expect(repository.active!.metrics.distance, 0);
      expect(repository.active!.endPoint!.isStationary, isTrue);
      expect(repository.active!.endPoint!.rawLongitude, fix(600, 1).longitude);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await tester.runAsync(() async {
        await recording.dispose();
        await service.dispose();
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'camera follows the animated marker while storage retains GPS samples',
    (tester) async {
      final service = FakeLocationService()..lastLocation = location(1);
      final repository = FakeRoutesRepository();
      final recording = RecordingService(
        locationService: service,
        routesRepository: repository,
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: AppTheme.builder,
          home: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () {},
          ),
        ),
      );
      await pumpMapUi(tester);
      final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final first = markerPoint(tester);
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      await tester.tap(find.text('Record route'));
      await pumpMapUi(tester);
      final fix = location(2);
      service.send(fix);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final moving = markerPoint(tester);
      expect(moving.latitude, inExclusiveRange(first.latitude, fix.latitude));
      expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
      expect(
        const DistanceHaversine(roundResult: false)(
          moving,
          controller.camera.center,
        ),
        lessThan(0.01),
      );
      expect(cubit.state.location, fix);
      expect(repository.added, [fix]);
      expect(cubit.state.points, [location(1), fix]);
      final tail = tester
          .widget<PolylineLayer>(find.byKey(const ValueKey('route-tail-layer')))
          .polylines
          .single
          .points;
      expect(tail.first, first);
      expect(tail.last, moving);
      expect(tail, isNot(contains(LatLng(fix.latitude, fix.longitude))));
      await pumpMapUi(tester);
      expect(markerPoint(tester).latitude, fix.latitude);

      await tester.drag(find.byType(FlutterMap), const Offset(100, 80));
      await pumpMapUi(tester);
      expect(cubit.state.centered, isFalse);
      expect(
        tester
            .widget<CenterLocationIcon>(find.byType(CenterLocationIcon))
            .centered,
        isFalse,
      );
      final cameraAfterPan = controller.camera.center;
      service.send(location(3));
      await pumpMapUi(tester);
      expect(markerPoint(tester).latitude, location(3).latitude);
      expect(controller.camera.center, cameraAfterPan);
      await tester.tap(find.byTooltip('Center on location'));
      await tester.pump();
      expect(cubit.state.centered, isTrue);
      expect(
        tester
            .widget<CenterLocationIcon>(find.byType(CenterLocationIcon))
            .centered,
        isTrue,
      );
      final iconOpacity = tester
          .widget<FadeTransition>(
            find.byKey(const ValueKey('follow-active-opacity')),
          )
          .opacity;
      expect(iconOpacity.value, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(iconOpacity.value, inExclusiveRange(0, 1));
      await pumpMapUi(tester);
      expect(iconOpacity.value, 1);
      expect(
        controller.camera.center.latitude,
        closeTo(location(3).latitude, 0.000001),
      );

      service.send(location(4));
      await tester.pump();
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        await recording.dispose();
        await service.dispose();
      });
    },
  );

  testWidgets('system reduced-motion setting disables marker interpolation', (
    tester,
  ) async {
    final service = FakeLocationService()..lastLocation = location(1);
    final recording = RecordingService(
      locationService: service,
      routesRepository: FakeRoutesRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: AppTheme.builder(context, child),
        ),
        home: MapScreen(
          photosRepository: FakeRoutePhotosRepository(),
          recordingService: recording,
          geocodingManager: FakeGeocodingManager(),
          onPageChangeRequested: () {},
        ),
      ),
    );
    await pumpMapUi(tester);
    service.send(location(2));
    await tester.pump();
    await tester.pump();
    expect(markerPoint(tester).latitude, location(2).latitude);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      await recording.dispose();
      await service.dispose();
    });
  });

  testWidgets('playback frames stay local to the marker and map camera', (
    tester,
  ) async {
    final cubit =
        MapCubit(
          recordingService: _UnusedRecordingService(),
          photosRepository: FakeRoutePhotosRepository(),
          geocodingManager: FakeGeocodingManager(),
        )..emit(
          MapState(
            location: location(1),
            locationLoading: false,
            isRecording: true,
          ),
        );
    var states = 0;
    await tester.pumpWidget(
      MaterialApp(
        builder: AppTheme.builder,
        home: BlocProvider.value(
          value: cubit,
          child: BlocListener<MapCubit, MapState>(
            listener: (context, state) => states++,
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      ),
    );
    await pumpMapUi(tester);
    cubit.emit(cubit.state.copyWith(location: location(2)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();
    final visible = markerPoint(tester);
    states = 0;
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
      expect(markerPoint(tester).latitude, greaterThan(visible.latitude));
      expect(rebuilt, contains(MarkerLayer));
      expect(rebuilt, isNot(contains(MapView)));
      expect(rebuilt, isNot(contains(MapAppBar)));
      expect(rebuilt, isNot(contains(MapSurface)));
      expect(rebuilt, isNot(contains(AppButton)));
      expect(rebuilt, isNot(contains(AppIconButton)));
      expect(states, 0);
    } finally {
      debugOnRebuildDirtyWidget = previousObserver;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await cubit.close();
    }
  });

  testWidgets('a hidden map cancels playback and resumes at the latest fix', (
    tester,
  ) async {
    final visible = ValueNotifier(true);
    final service = FakeLocationService()..lastLocation = location(1);
    final recording = RecordingService(
      locationService: service,
      routesRepository: FakeRoutesRepository(),
    );
    await tester.pumpWidget(
      MaterialApp(
        builder: AppTheme.builder,
        home: ValueListenableBuilder<bool>(
          valueListenable: visible,
          builder: (context, enabled, child) =>
              TickerMode(enabled: enabled, child: child!),
          child: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () {},
          ),
        ),
      ),
    );
    await pumpMapUi(tester);
    service.send(location(2));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(markerPoint(tester).latitude, lessThan(location(2).latitude));
    visible.value = false;
    await tester.pumpAndSettle();
    expect(markerPoint(tester).latitude, location(2).latitude);
    service.send(location(3));
    await tester.pumpAndSettle();
    expect(markerPoint(tester).latitude, location(3).latitude);
    expect(tester.binding.transientCallbackCount, 0);
    visible.value = true;
    await pumpMapUi(tester);
    expect(markerPoint(tester).latitude, location(3).latitude);
    service.send(location(4));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      markerPoint(tester).latitude,
      inExclusiveRange(location(3).latitude, location(4).latitude),
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    visible.dispose();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      await recording.dispose();
      await service.dispose();
    });
  });
}

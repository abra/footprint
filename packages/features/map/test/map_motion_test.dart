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
import 'pump_recording_ui.dart';
import '../../../foreground_location_service/test/gps_fixtures.dart';

LatLng markerPoint(WidgetTester tester) => tester
    .widget<MarkerLayer>(find.byKey(const ValueKey('current-location-layer')))
    .markers
    .single
    .point;

class _UnusedRecordingService extends Fake implements RecordingService {}

void main() {
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
          home: BlocProvider(
            create: (_) => cubit..initialize(),
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Record route'));
      await pumpRecordingUi(tester);
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final marker = markerPoint(tester);
      final camera = controller.camera.center;
      final originalLookups = lookups;
      for (var second = 30; second <= 600; second += 30) {
        now = gpsEpoch.add(Duration(seconds: second));
        service.send(filter.add(fix(second, second % 60 == 0 ? 1 : -1))!);
        await pumpRecordingUi(tester);
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
          home: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final first = markerPoint(tester);
      await tester.tap(find.text('Record route'));
      await pumpRecordingUi(tester);
      final fix = location(2);
      service.send(fix);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      final moving = markerPoint(tester);
      expect(moving.latitude, inExclusiveRange(first.latitude, fix.latitude));
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
      await pumpRecordingUi(tester);
      expect(markerPoint(tester).latitude, fix.latitude);

      await tester.drag(find.byType(FlutterMap), const Offset(100, 80));
      await pumpRecordingUi(tester);
      expect(cubit.state.centered, isFalse);
      expect(
        tester
            .widget<CenterLocationIcon>(find.byType(CenterLocationIcon))
            .centered,
        isFalse,
      );
      final cameraAfterPan = controller.camera.center;
      service.send(location(3));
      await pumpRecordingUi(tester);
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
            find
                .ancestor(
                  of: find.byIcon(Icons.navigation),
                  matching: find.byType(FadeTransition),
                )
                .first,
          )
          .opacity;
      expect(iconOpacity.value, 0);
      await tester.pump(const Duration(milliseconds: 100));
      expect(iconOpacity.value, inExclusiveRange(0, 1));
      await pumpRecordingUi(tester);
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
          child: child!,
        ),
        home: MapScreen(
          photosRepository: FakeRoutePhotosRepository(),
          recordingService: recording,
          geocodingManager: FakeGeocodingManager(),
          onPageChangeRequested: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();
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
        home: BlocProvider.value(
          value: cubit,
          child: BlocListener<MapCubit, MapState>(
            listener: (context, state) => states++,
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      ),
    );
    await pumpRecordingUi(tester);
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
      expect(rebuilt, isNot(contains(FilledButton)));
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
    await tester.pumpAndSettle();
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
    await tester.pumpAndSettle();
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

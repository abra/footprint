import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/map.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

LatLng markerPoint(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single.point;

void main() {
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
      await tester.pumpAndSettle();
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
      await tester.pumpAndSettle();
      expect(markerPoint(tester).latitude, fix.latitude);

      await tester.drag(find.byType(FlutterMap), const Offset(100, 80));
      await tester.pumpAndSettle();
      expect(cubit.state.centered, isFalse);
      final cameraAfterPan = controller.camera.center;
      service.send(location(3));
      await tester.pumpAndSettle();
      expect(markerPoint(tester).latitude, location(3).latitude);
      expect(controller.camera.center, cameraAfterPan);
      await tester.tap(find.byTooltip('Center on location'));
      await tester.pumpAndSettle();
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
}

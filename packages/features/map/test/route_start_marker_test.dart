import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/map.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_state.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

class _UnusedRecordingService extends Fake implements RecordingService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  for (final direction in TextDirection.values) {
    testWidgets('flag pole anchors to the route start in $direction', (
      tester,
    ) async {
      final points = [location(1), location(2)];
      final cubit =
          MapCubit(
            recordingService: _UnusedRecordingService(),
            photosRepository: FakeRoutePhotosRepository(),
            geocodingManager: FakeGeocodingManager(),
          )..emit(
            MapState(
              location: points.last,
              locationLoading: false,
              points: points,
              isRecording: true,
              centered: false,
            ),
          );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Directionality(
              textDirection: direction,
              child: IconTheme(
                data: const IconThemeData(applyTextScaling: true),
                child: child!,
              ),
            ),
          ),
          home: BlocProvider.value(
            value: cubit,
            child: MapView(config: const MapConfig(), onRoutesRequested: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final map = find.byType(FlutterMap);
      final controller = tester.widget<FlutterMap>(map).mapController!;
      final lineStart = tester
          .widget<PolylineLayer>(find.byType(PolylineLayer))
          .polylines
          .single
          .points
          .first;
      final marker = tester
          .widget<MarkerLayer>(find.byKey(const ValueKey('route-start-layer')))
          .markers
          .single;
      expect(marker.point, lineStart);
      expect(lineStart, LatLng(points.first.latitude, points.first.longitude));

      for (final zoom in [14.0, 17.0, 20.0]) {
        for (final rotation in [0.0, 45.0, 135.0]) {
          controller.move(lineStart, zoom);
          controller.rotate(rotation);
          await tester.pumpAndSettle();
          final glyph = tester.renderObject<RenderBox>(
            find.descendant(
              of: find.byIcon(Icons.flag),
              matching: find.byType(RichText),
            ),
          );
          expect(glyph.size.width, closeTo(30, 0.01));
          final poleBase = glyph.localToGlobal(const Offset(7.5, 26.25));
          final mapBox = tester.renderObject<RenderBox>(map);
          final projectedStart = mapBox.localToGlobal(
            controller.camera.latLngToScreenOffset(lineStart),
          );
          expect(
            (poleBase - projectedStart).distance,
            lessThan(0.01),
            reason: 'Pole base at zoom $zoom, rotation $rotation',
          );
          final poleTop = glyph.localToGlobal(const Offset(7.5, 5));
          expect(poleTop.dx, closeTo(poleBase.dx, 0.01));
          expect(poleTop.dy, lessThan(poleBase.dy));
          expect(tester.takeException(), isNull);
        }
      }
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      await cubit.close();
    });
  }
}

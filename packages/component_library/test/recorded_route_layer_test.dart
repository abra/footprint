import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  testWidgets('route layers handle empty paths and update their cached style', (
    tester,
  ) async {
    const points = [LatLng(56, 60), LatLng(56.001, 60)];
    Future<void> show(
      List<LatLng> coordinates, {
      double width = 7,
      bool muted = false,
    }) => tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          options: const MapOptions(initialCenter: LatLng(56, 60)),
          children: [
            RecordedRouteLayer(
              points: coordinates,
              strokeWidth: width,
              muted: muted,
            ),
          ],
        ),
      ),
    );

    await show(const []);
    expect(find.byType(PolylineLayer), findsNothing);
    await show(const [LatLng(56, 60)]);
    expect(find.byType(PolylineLayer), findsNothing);
    for (final width in [7.0, 5.0]) {
      await show(points, width: width);
      final line = tester
          .widget<PolylineLayer>(
            find.byKey(const ValueKey('route-history-layer')),
          )
          .polylines
          .single;
      expect(line.points, same(points));
      expect(line.strokeWidth, width);
      expect(line.color, AppTheme.route);
      expect(line.strokeCap, StrokeCap.round);
      expect(line.strokeJoin, StrokeJoin.round);
      expect(find.byKey(const ValueKey('route-history-outline')), findsNothing);
      final shadow = tester.widget<PolylineLayer>(
        find.byKey(const ValueKey('route-history-shadow')),
      );
      expect(shadow.polylines, hasLength(2));
      expect(shadow.polylines.every((line) => line.color.a < 0.04), isTrue);
      // Transparent lines with a native border require saveLayer in flutter_map.
      final passes = tester.widgetList<PolylineLayer>(
        find.byType(PolylineLayer),
      );
      for (final pass in passes) {
        expect(
          pass.polylines.every((line) => line.borderStrokeWidth == 0),
          isTrue,
        );
        expect(
          pass.polylines.every((line) => line.color != Colors.white),
          isTrue,
        );
      }
    }
    await show(points, width: 4, muted: true);
    final muted = tester
        .widget<PolylineLayer>(
          find.byKey(const ValueKey('route-history-layer')),
        )
        .polylines
        .single;
    expect(muted.points, same(points));
    expect(muted.strokeWidth, 4);
    expect(muted.color, AppTheme.route.withValues(alpha: 0.25));
    expect(find.byKey(const ValueKey('route-history-shadow')), findsNothing);
    expect(find.byType(Opacity), findsNothing);
    await show(points);
    final active = tester
        .widget<PolylineLayer>(
          find.byKey(const ValueKey('route-history-layer')),
        )
        .polylines
        .single;
    expect(active.color, AppTheme.route);
    expect(active.strokeWidth, 7);
    expect(find.byKey(const ValueKey('route-history-shadow')), findsOneWidget);
    await show(const []);
    expect(find.byType(PolylineLayer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

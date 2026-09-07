import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final rotation in [0.0, 90.0]) {
    testWidgets('coincident endpoints stay anchored and legible at $rotation', (
      tester,
    ) async {
      const point = GeoPoint(51.5, -0.1);
      final start = RouteEndpointMarker(point: point, letter: 'A');
      final end = RouteEndpointMarker(point: point, letter: 'B');
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FlutterMap(
              options: MapOptions(
                initialCenter: point.latLng,
                initialZoom: 16,
                initialRotation: rotation,
              ),
              children: [
                MarkerLayer(
                  markers: [
                    start,
                    end,
                    Marker(
                      point: point.latLng,
                      width: 28,
                      height: 28,
                      child: const Icon(
                        Icons.my_location,
                        key: ValueKey('gps'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      Rect badgeRect(String letter) => tester.getRect(
        find.byWidgetPredicate(
          (widget) => widget is RouteEndpointBadge && widget.letter == letter,
        ),
      );

      final a = badgeRect('A');
      final b = badgeRect('B');
      final gps = tester.getRect(find.byKey(const ValueKey('gps')));
      expect(start.point, point.latLng);
      expect(end.point, point.latLng);
      expect(a.center.dx, closeTo(gps.center.dx, 0.01));
      expect(b.center.dx, closeTo(gps.center.dx, 0.01));
      expect(a.bottom + 24, closeTo(gps.center.dy, 0.01));
      expect(b.top - 24, closeTo(gps.center.dy, 0.01));
      expect(a.overlaps(b), isFalse);
      expect(a.overlaps(gps), isFalse);
      expect(b.overlaps(gps), isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}

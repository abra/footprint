import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/route_trace.dart';

const start = LatLng(56, 60);
const corner = LatLng(56.001, 60);
const end = LatLng(56.001, 60.001);
final epoch = DateTime.utc(2026, 9, 6);

LocationDM sample(LatLng point, int second) => LocationDM(
  id: '$second',
  latitude: point.latitude,
  longitude: point.longitude,
  timestamp: epoch.add(Duration(seconds: second)),
);

List<LatLng> visiblePath(WidgetTester tester) {
  final points = <LatLng>[];
  for (final key in ['route-history-layer', 'route-tail-layer']) {
    final finder = find.byKey(ValueKey(key));
    if (finder.evaluate().isEmpty) continue;
    final line = tester.widget<PolylineLayer>(finder).polylines.single.points;
    points.addAll(points.isEmpty ? line : line.skip(1));
  }
  return points;
}

void main() {
  late LocationMotion motion;
  setUp(() => motion = LocationMotion(vsync: const TestVSync()));
  tearDown(() => motion.dispose());

  void move(LatLng point, int second, {bool animate = true}) => motion.moveTo(
    point,
    timestamp: epoch.add(Duration(seconds: second)),
    animate: animate,
  );

  Future<void> showTrace(
    WidgetTester tester,
    List<LocationDM> points, {
    bool isRecording = true,
    bool muted = false,
  }) => tester.pumpWidget(
    MaterialApp(
      builder: AppTheme.builder,
      home: FlutterMap(
        options: const MapOptions(initialCenter: start, initialZoom: 16),
        children: [
          RouteTrace(
            points: points,
            isRecording: isRecording,
            motion: motion,
            muted: muted,
          ),
        ],
      ),
    ),
  );

  testWidgets('the active line ends at the marker rather than the newest fix', (
    tester,
  ) async {
    move(start, 0);
    await showTrace(tester, [sample(start, 0)]);
    expect(visiblePath(tester), isEmpty);
    move(corner, 1);
    final points = [sample(start, 0), sample(corner, 1)];
    await showTrace(tester, points);
    await tester.pump(const Duration(milliseconds: 700));
    expect(visiblePath(tester), [start, motion.value]);
    expect(visiblePath(tester), isNot(contains(corner)));
    expect(points.last.latitude, corner.latitude);
    await tester.pumpAndSettle();
    expect(visiblePath(tester), [start, corner]);
    expect(find.byKey(const ValueKey('route-tail-layer')), findsNothing);
  });

  testWidgets(
    'buffered corners are revealed only after the marker passes them',
    (tester) async {
      move(start, 0);
      move(corner, 1);
      await showTrace(tester, [sample(start, 0), sample(corner, 1)]);
      await tester.pump(const Duration(milliseconds: 500));
      move(end, 2);
      await showTrace(tester, [
        sample(start, 0),
        sample(corner, 1),
        sample(end, 2),
      ]);
      await tester.pump(const Duration(milliseconds: 400));
      expect(visiblePath(tester), [start, motion.value]);
      expect(motion.value!.longitude, closeTo(start.longitude, 0.000001));
      await tester.pump(const Duration(milliseconds: 500));
      expect(visiblePath(tester), [start, corner, motion.value]);
      expect(visiblePath(tester), isNot(contains(end)));
      await tester.pumpAndSettle();
      expect(visiblePath(tester), [start, corner, end]);
    },
  );

  testWidgets(
    'playback before recording start does not draw a backwards line',
    (tester) async {
      move(start, 0);
      move(corner, 1);
      await showTrace(tester, [sample(corner, 1)]);
      await tester.pump(const Duration(milliseconds: 500));
      expect(visiblePath(tester), isEmpty);
      await tester.pumpAndSettle();
      move(end, 2);
      await showTrace(tester, [sample(corner, 1), sample(end, 2)]);
      await tester.pump(const Duration(milliseconds: 700));
      expect(visiblePath(tester), [corner, motion.value]);
      expect(visiblePath(tester), isNot(contains(start)));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('completed routes stay complete while the preview marker moves', (
    tester,
  ) async {
    move(start, 0);
    move(corner, 1);
    final points = [sample(start, 0), sample(corner, 1)];
    await showTrace(tester, points);
    await tester.pump(const Duration(milliseconds: 500));
    expect(visiblePath(tester).last, isNot(corner));
    await showTrace(tester, points, isRecording: false, muted: true);
    expect(visiblePath(tester), [start, corner]);
    final history = tester.widget<PolylineLayer>(
      find.byKey(const ValueKey('route-history-layer')),
    );
    expect(
      history.polylines.single.color,
      AppTheme.route.withValues(alpha: 0.25),
    );
    expect(history.polylines.single.strokeWidth, 4);
    expect(find.byKey(const ValueKey('route-history-shadow')), findsNothing);
    move(end, 2);
    await tester.pumpAndSettle();
    expect(motion.value, end);
    expect(visiblePath(tester), [start, corner]);
    expect(
      tester.widget<PolylineLayer>(
        find.byKey(const ValueKey('route-history-layer')),
      ),
      same(history),
    );
  });

  testWidgets('snapping motion also completes the visible route', (
    tester,
  ) async {
    move(start, 0);
    move(corner, 1);
    await showTrace(tester, [sample(start, 0), sample(corner, 1)]);
    await tester.pump(const Duration(milliseconds: 500));
    move(corner, 1, animate: false);
    await tester.pumpAndSettle();
    expect(visiblePath(tester), [start, corner]);
    expect(visiblePath(tester).last, motion.value);
  });

  testWidgets(
    'a loop uses playback time instead of the nearest route position',
    (tester) async {
      move(start, 0);
      move(corner, 1);
      move(start, 2);
      await showTrace(tester, [
        sample(start, 0),
        sample(corner, 1),
        sample(start, 2),
      ]);
      await tester.pump(const Duration(seconds: 3));
      expect(motion.value, start);
      expect(visiblePath(tester), [start, corner, start]);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'late recorded samples do not make future geometry appear early',
    (tester) async {
      move(start, 0);
      move(corner, 2);
      await showTrace(tester, [
        sample(start, 0),
        sample(corner, 2),
        sample(end, 1),
      ]);
      await tester.pump(const Duration(milliseconds: 1700));
      expect(visiblePath(tester), [start, motion.value]);
      expect(visiblePath(tester), isNot(contains(end)));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'long route history is reused between playback sample boundaries',
    (tester) async {
      final points = [
        for (var i = 0; i < 2000; i++) sample(LatLng(56 + i * 0.000001, 60), i),
      ];
      final previous = LatLng(points[1998].latitude, points[1998].longitude);
      final latest = LatLng(points.last.latitude, points.last.longitude);
      move(previous, 1998);
      move(latest, 1999);
      await showTrace(tester, points);
      await tester.pump(const Duration(milliseconds: 500));
      final historyFinder = find.byKey(const ValueKey('route-history-layer'));
      final history = tester.widget<PolylineLayer>(historyFinder);
      expect(history.polylines.single.points, hasLength(1999));
      final cachedLayers = {
        for (final suffix in ['shadow', 'layer'])
          suffix: tester.widget<PolylineLayer>(
            find.byKey(ValueKey('route-history-$suffix')),
          ),
      };
      for (final layer in cachedLayers.values) {
        for (final line in layer.polylines) {
          expect(line.points, same(history.polylines.single.points));
        }
      }
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.widget<PolylineLayer>(historyFinder), same(history));
        for (final entry in cachedLayers.entries) {
          expect(
            tester.widget<PolylineLayer>(
              find.byKey(ValueKey('route-history-${entry.key}')),
            ),
            same(entry.value),
          );
        }
        final tail = tester
            .widget<PolylineLayer>(
              find.byKey(const ValueKey('route-tail-layer')),
            )
            .polylines
            .single
            .points;
        expect(tail, [previous, motion.value]);
      }
      await tester.pumpAndSettle();
    },
  );
}

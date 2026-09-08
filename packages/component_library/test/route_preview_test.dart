import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'load_fonts.dart';

late MemoryImage _tile;

class _TestTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      _tile;
}

const _points = [LatLng(56, 60), LatLng(56.0005, 60), LatLng(56.0005, 60.001)];

RouteDM _route(List<LatLng> points) {
  final start = DateTime(2026, 9, 10);
  return RouteDM(
    id: 1,
    startTime: start,
    endTime: start.add(const Duration(minutes: 10)),
    status: Status.completed,
    routePoints: [
      for (final (index, point) in points.indexed)
        RoutePointDM(
          id: index,
          routeId: 1,
          latitude: point.latitude,
          longitude: point.longitude,
          address: '',
          timestamp: start.add(Duration(minutes: index)),
        ),
    ],
  );
}

Future<void> _show(
  WidgetTester tester, {
  List<LatLng> points = _points,
  bool interactive = false,
  TextDirection direction = TextDirection.ltr,
  VoidCallback? onTap,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(3)),
        child: Directionality(
          textDirection: direction,
          child: IconTheme(
            data: const IconThemeData(applyTextScaling: true),
            child: AppTheme.builder(context, child),
          ),
        ),
      ),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            height: 180,
            child: RoutePreview(
              route: _route(points),
              interactive: interactive,
              onTap: onTap,
              config: MapTileConfig(
                urlTemplate: 'https://fixture.example/{z}/{x}/{y}.png',
                attribution: 'Fixture',
                tileProviderFactory: _TestTiles.new,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.runAsync(
    () => precacheImage(_tile, tester.element(find.byType(Scaffold))),
  );
  await tester.pumpAndSettle();
}

MapController _controller(WidgetTester tester) =>
    MapController.of(tester.element(find.byType(MapTiles)));

List<Marker> _markers(WidgetTester tester) =>
    tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;

void _expectAnchor(
  WidgetTester tester, {
  required String label,
  required IconData icon,
  required LatLng point,
  required Offset tip,
}) {
  final finder = find.descendant(
    of: find.byTooltip(label),
    matching: find.byIcon(icon),
  );
  expect(finder, findsOneWidget);
  final glyph = tester.renderObject<RenderBox>(
    find.descendant(of: finder, matching: find.byType(RichText)),
  );
  expect(glyph.size, const Size.square(30));
  final map = tester.renderObject<RenderBox>(find.byType(FlutterMap));
  final projected = map.localToGlobal(
    _controller(tester).camera.latLngToScreenOffset(point),
  );
  final anchor = glyph.localToGlobal(tip);
  expect((anchor - projected).distance, lessThan(0.01));
  final above = glyph.localToGlobal(tip - const Offset(0, 5));
  expect(above.dx, closeTo(anchor.dx, 0.01));
  expect(above.dy, lessThan(anchor.dy));
}

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(Colors.white, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(1, 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    _tile = MemoryImage(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });

  for (final interactive in [false, true]) {
    for (final direction in TextDirection.values) {
      testWidgets(
        'preview endpoints follow the line at all zooms and rotations '
        '(interactive: $interactive, $direction)',
        (tester) async {
          await _show(tester, interactive: interactive, direction: direction);
          final points = tester
              .widget<PolylineLayer>(
                find.byKey(const ValueKey('route-history-layer')),
              )
              .polylines
              .single
              .points;
          expect(points, _points);
          final markers = _markers(tester);
          expect(markers.first.point, points.first);
          expect(markers.last.point, points.last);
          expect(
            tester.widget<Icon>(find.byIcon(Icons.flag)).color,
            AppTheme.coral,
          );
          expect(
            tester.widget<Icon>(find.byIcon(Icons.location_on)).color,
            AppTheme.success,
          );
          final controller = _controller(tester);
          for (final (label, icon, point, tip) in [
            ('Route start', Icons.flag, points.first, const Offset(7.5, 26.25)),
            (
              'Route end',
              Icons.location_on,
              points.last,
              const Offset(15, 27.5),
            ),
          ]) {
            _expectAnchor(
              tester,
              label: label,
              icon: icon,
              point: point,
              tip: tip,
            );
            for (final zoom in [8.0, 16.0, 19.0]) {
              for (final rotation in [0.0, 45.0, 135.0, 270.0]) {
                controller.moveAndRotate(point, zoom, rotation);
                await tester.pumpAndSettle();
                _expectAnchor(
                  tester,
                  label: label,
                  icon: icon,
                  point: point,
                  tip: tip,
                );
              }
            }
            controller.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(points),
                padding: const EdgeInsets.all(36),
              ),
            );
            controller.rotate(0);
            await tester.pumpAndSettle();
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'markers use the same valid endpoints as the line after updates',
    (tester) async {
      await _show(tester);
      final element = tester.element(find.byType(RoutePreview));
      final reversed = _points.reversed.toList();
      await _show(
        tester,
        points: [
          const LatLng(double.nan, 60),
          ...reversed,
          const LatLng(56, 181),
        ],
      );
      expect(tester.element(find.byType(RoutePreview)), same(element));
      final points = tester
          .widget<PolylineLayer>(
            find.byKey(const ValueKey('route-history-layer')),
          )
          .polylines
          .single
          .points;
      expect(points, reversed);
      expect(_markers(tester).map((marker) => marker.point), [
        points.first,
        points.last,
      ]);
      expect(find.byTooltip('Route start'), findsOneWidget);
      expect(find.byTooltip('Route end'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('empty and single-point routes do not invent a finish', (
    tester,
  ) async {
    await _show(tester, points: []);
    expect(find.text('No route points'), findsOneWidget);
    expect(find.byType(FlutterMap), findsNothing);
    await _show(tester, points: [_points.first]);
    expect(_markers(tester).single.point, _points.first);
    expect(find.byTooltip('Route start'), findsOneWidget);
    expect(find.byTooltip('Route end'), findsNothing);
    expect(find.byType(RecordedRouteLayer), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'a loop keeps both geographic endpoints at their recorded point',
    (tester) async {
      await _show(tester, points: [..._points, _points.first]);
      _expectAnchor(
        tester,
        label: 'Route start',
        icon: Icons.flag,
        point: _points.first,
        tip: const Offset(7.5, 26.25),
      );
      _expectAnchor(
        tester,
        label: 'Route end',
        icon: Icons.location_on,
        point: _points.first,
        tip: const Offset(15, 27.5),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('tapping a compact preview still opens its route', (
    tester,
  ) async {
    var opened = false;
    await _show(tester, onTap: () => opened = true);
    await tester.tapAt(tester.getCenter(find.byType(FlutterMap)));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

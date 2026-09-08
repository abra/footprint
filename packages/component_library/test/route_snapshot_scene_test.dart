import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RouteDM snapshotRoute({
  int id = 1,
  String? name,
  List<(double, double)>? points,
}) {
  final start = DateTime(2026, 9, 10);
  return RouteDM(
    id: id,
    name: name,
    startTime: start,
    status: Status.completed,
    routePoints: [
      for (final (index, (lat, lon))
          in (points ?? [(56.0, 60.0), (56.01, 60.0), (56.01, 60.02)]).indexed)
        RoutePointDM(
          id: index,
          routeId: id,
          latitude: lat,
          longitude: lon,
          address: '',
          timestamp: start.add(Duration(seconds: index)),
        ),
    ],
  );
}

void main() {
  for (final (name, points) in <(String, List<(double, double)>)>[
    ('vertical', [(56, 60), (57, 60)]),
    ('horizontal', [(56, 60), (56, 61)]),
    ('loop', [(56, 60), (56.01, 60), (56.01, 60.02), (56, 60)]),
    ('single', [(56, 60)]),
    ('stationary', [(56, 60), (56, 60)]),
    ('short', [(56, 60), (56.0000001, 60)]),
    ('long', [(-70, -160), (70, 160)]),
    ('polar', [(89, 60), (89.1, 61)]),
  ]) {
    test('$name route and marker tips fit completely inside the snapshot', () {
      final scene = RouteSnapshotScene(snapshotRoute(points: points));
      final inner = RouteSnapshotScene.padding
          .deflateRect(Offset.zero & RouteSnapshotScene.size)
          .inflate(0.01);
      expect(scene.camera.zoom.isFinite, isTrue);
      for (final point in scene.projected) {
        expect(inner.contains(point), isTrue, reason: '$point outside $inner');
      }
      for (final (point, style) in [
        (scene.projected.first, RecordedEndpointStyle.start),
        (scene.projected.last, RecordedEndpointStyle.end),
      ]) {
        final rect = (point - style.tip * 2.5) & const Size.square(60);
        final viewport = Offset.zero & RouteSnapshotScene.size;
        expect(viewport.contains(rect.topLeft), isTrue);
        expect(viewport.contains(rect.bottomRight), isTrue);
      }
    });
  }

  test('invalid points are excluded without changing endpoint order', () {
    final scene = RouteSnapshotScene(
      snapshotRoute(
        points: [(double.nan, 60), (56, 60), (56.01, 60), (91, 60)],
      ),
    );
    expect(scene.points.length, 2);
    expect(scene.points.first.latitude, 56);
    expect(scene.points.last.latitude, 56.01);
  });

  test('empty scene has finite camera and no path points', () {
    final scene = RouteSnapshotScene(snapshotRoute(points: []));
    expect(scene.projected, isEmpty);
    expect(scene.camera.zoom.isFinite, isTrue);
  });
}

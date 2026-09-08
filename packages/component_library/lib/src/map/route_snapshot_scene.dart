import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' show LatLng;

import '../theme/app_theme.dart';
import 'recorded_route_marker.dart';

/// Fixed-format thumbnail geometry, shared by the PNG renderer and placeholder.
class RouteSnapshotScene {
  RouteSnapshotScene(RouteDM route)
    : routeId = route.id,
      points = List.unmodifiable([
        for (final point in route.routePoints)
          if (point.latitude.isFinite &&
              point.longitude.isFinite &&
              point.latitude.abs() <= 90 &&
              point.longitude.abs() <= 180)
            LatLng(point.latitude, point.longitude),
      ]);

  static const size = Size(720, 400);
  static const aspectRatio = 1.8;
  static const padding = EdgeInsets.fromLTRB(72, 72, 72, 72);
  final int routeId;
  final List<LatLng> points;

  late final MapCamera camera = _fit();
  late final List<Offset> projected = List.unmodifiable(
    points.map(camera.latLngToScreenOffset),
  );
  late final Path path = Path()..addPolygon(projected, false);

  MapCamera _fit() {
    final initial = MapCamera(
      crs: const Epsg3857(),
      center: points.firstOrNull ?? const LatLng(0, 0),
      zoom: 17,
      rotation: 0,
      nonRotatedSize: size,
    );
    if (points.isEmpty) return initial;
    return CameraFit.coordinates(
      coordinates: points,
      padding: padding,
      minZoom: 0,
      maxZoom: 18,
    ).fit(initial);
  }

  void paintRoute(Canvas canvas) {
    if (points.isEmpty) return;
    if (points.length > 1) {
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.save();
      canvas.translate(0, 4);
      canvas.drawPath(
        path,
        paint
          ..color = const Color(0x031F1837)
          ..strokeWidth = 30,
      );
      canvas.drawPath(
        path,
        paint
          ..color = const Color(0x0A1F1837)
          ..strokeWidth = 22,
      );
      canvas.restore();
      canvas.drawPath(
        path,
        paint
          ..color = AppTheme.route
          ..strokeWidth = 10,
      );
    }
    _paintMarker(canvas, projected.first, RecordedEndpointStyle.start);
    if (points.length > 1) {
      _paintMarker(canvas, projected.last, RecordedEndpointStyle.end);
    }
  }

  void _paintMarker(Canvas canvas, Offset point, RecordedEndpointStyle style) {
    const size = 60.0;
    final text = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(style.icon.codePoint),
        style: TextStyle(
          color: style.color,
          fontFamily: style.icon.fontFamily,
          package: style.icon.fontPackage,
          fontSize: size,
          height: 1,
        ),
      ),
    )..layout();
    text.paint(canvas, point - style.tip * (size / 24));
    text.dispose();
  }
}

class RouteSnapshotPlaceholder extends CustomPainter {
  const RouteSnapshotPlaceholder(this.scene);
  final RouteSnapshotScene scene;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.scale(size.width / RouteSnapshotScene.size.width);
    canvas.drawColor(AppTheme.surface, BlendMode.src);
    scene.paintRoute(canvas);
    canvas.restore();
  }

  @override
  bool shouldRepaint(RouteSnapshotPlaceholder oldDelegate) =>
      oldDelegate.scene != scene;
}

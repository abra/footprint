import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

class RouteSpeedChart extends StatelessWidget {
  const RouteSpeedChart({super.key, required this.samples});

  final List<RouteSpeedSample> samples;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Speed over time',
    value: samples.isEmpty ? 'No speed samples yet' : null,
    image: true,
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _SpeedPainter(samples),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _SpeedPainter extends CustomPainter {
  _SpeedPainter(this.samples);

  final List<RouteSpeedSample> samples;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(2);
    if (bounds.isEmpty) return;
    final grid = Paint()
      ..color = AppTheme.border
      ..strokeWidth = 0.5;
    for (var column = 0; column <= 6; column++) {
      final x = bounds.left + bounds.width * column / 6;
      canvas.drawLine(Offset(x, bounds.top), Offset(x, bounds.bottom), grid);
    }
    for (var row = 0; row <= 4; row++) {
      final y = bounds.top + bounds.height * row / 4;
      canvas.drawLine(Offset(bounds.left, y), Offset(bounds.right, y), grid);
    }
    if (samples.isEmpty) return;
    final start = samples.first.elapsed.inMicroseconds;
    final span = samples.last.elapsed.inMicroseconds - start;
    final maximum = samples.fold(
      1.0,
      (value, sample) => math.max(value, sample.speed),
    );
    Offset position(RouteSpeedSample sample) => Offset(
      bounds.left +
          (span == 0 ? 0 : (sample.elapsed.inMicroseconds - start) / span) *
              bounds.width,
      bounds.bottom - sample.speed / maximum * bounds.height,
    );

    final line = Paint()
      ..color = AppTheme.route
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.75
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    if (samples.length == 1) {
      canvas.drawCircle(
        position(samples.single),
        2,
        line..style = PaintingStyle.fill,
      );
      return;
    }
    final path = Path();
    for (final (index, sample) in samples.indexed) {
      final point = position(sample);
      if (index == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(_SpeedPainter oldDelegate) =>
      !identical(samples, oldDelegate.samples);
}

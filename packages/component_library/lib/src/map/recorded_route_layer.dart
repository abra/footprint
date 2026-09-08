import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';

/// A recorded path with an optional, independently updated playback tail.
class RecordedRouteLayer extends StatefulWidget {
  const RecordedRouteLayer({
    super.key,
    required this.points,
    this.tail = const [],
    this.strokeWidth = 7,
    this.muted = false,
  }) : assert(strokeWidth > 0);

  final List<LatLng> points;
  final List<LatLng> tail;
  final double strokeWidth;
  final bool muted;

  @override
  State<RecordedRouteLayer> createState() => _RecordedRouteLayerState();
}

typedef _StrokeLayers = ({Widget shadow, Widget stroke});

class _RecordedRouteLayerState extends State<RecordedRouteLayer> {
  late _StrokeLayers _history;

  @override
  void initState() {
    super.initState();
    _history = _layers(widget.points, 'route-history');
  }

  @override
  void didUpdateWidget(covariant RecordedRouteLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points) ||
        oldWidget.strokeWidth != widget.strokeWidth ||
        oldWidget.muted != widget.muted) {
      _history = _layers(widget.points, 'route-history');
    }
  }

  _StrokeLayers _layers(
    List<LatLng> points,
    String name, {
    bool continuesHistory = false,
  }) {
    if (points.length < 2) {
      return (shadow: const SizedBox.shrink(), stroke: const SizedBox.shrink());
    }
    List<double>? shadowStops;
    if (continuesHistory) {
      final camera = MapCamera.of(context);
      final length =
          (camera.latLngToScreenOffset(points.last) -
                  camera.latLngToScreenOffset(points.first))
              .distance;
      if (length > 0) {
        // The cached round cap already casts a shadow at the joint. Start the
        // short tail's shadow beyond it instead of darkening that overlap.
        shadowStops = [
          0,
          ((widget.strokeWidth + 6) / 2 / length).clamp(0, 1),
          ((widget.strokeWidth + 10) / 2 / length).clamp(0, 1),
          1,
        ];
      }
    }
    List<Color>? shadowGradient(Color color) => shadowStops == null
        ? null
        : [color.withAlpha(0), color.withAlpha(0), color, color];
    return (
      // Feathered vector strokes avoid a viewport-sized blur/filter layer.
      shadow: widget.muted
          ? const SizedBox.shrink()
          : Transform.translate(
              offset: const Offset(0, 2),
              child: PolylineLayer(
                key: ValueKey('$name-shadow'),
                polylines: [
                  Polyline(
                    points: points,
                    strokeWidth: widget.strokeWidth + 10,
                    color: const Color(0x031F1837),
                    gradientColors: shadowGradient(const Color(0x031F1837)),
                    colorsStop: shadowStops,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                  Polyline(
                    points: points,
                    strokeWidth: widget.strokeWidth + 6,
                    color: const Color(0x0A1F1837),
                    gradientColors: shadowGradient(const Color(0x0A1F1837)),
                    colorsStop: shadowStops,
                    strokeCap: StrokeCap.round,
                    strokeJoin: StrokeJoin.round,
                  ),
                ],
              ),
            ),
      stroke: PolylineLayer(
        key: ValueKey('$name-layer'),
        polylines: [
          Polyline(
            points: points,
            strokeWidth: widget.strokeWidth,
            color: widget.muted
                ? AppTheme.route.withValues(alpha: 0.25)
                : AppTheme.route,
            strokeCap: StrokeCap.round,
            strokeJoin: StrokeJoin.round,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    assert(widget.tail.length <= 2);
    final tail = _layers(
      widget.tail,
      'route-tail',
      continuesHistory: widget.points.length >= 2,
    );
    // Both shadows stay beneath the route. Historical widgets remain cached
    // between fixes while only the short tail changes during playback.
    return Stack(
      fit: StackFit.expand,
      children: [_history.shadow, tail.shadow, _history.stroke, tail.stroke],
    );
  }
}

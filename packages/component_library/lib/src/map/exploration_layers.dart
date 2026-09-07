import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

const explorationColor = Color(0xFF168577);

class RouteEndpointMarker extends Marker {
  RouteEndpointMarker({required GeoPoint point, required this.letter})
    : super(
        point: point.latLng,
        width: 36,
        height: 60,
        // Opposite stems keep coincident endpoints and the GPS marker readable.
        alignment: letter == 'A' ? Alignment.topCenter : Alignment.bottomCenter,
        rotate: true,
        child: Column(
          verticalDirection: letter == 'A'
              ? VerticalDirection.down
              : VerticalDirection.up,
          children: [
            SizedBox.square(
              dimension: 36,
              child: RouteEndpointBadge(letter: letter),
            ),
            SizedBox(
              width: 2,
              height: 24,
              child: ColoredBox(
                color: letter == 'A'
                    ? explorationColor
                    : const Color(0xFFE36478),
              ),
            ),
          ],
        ),
      );

  final String letter;
}

class RouteEndpointBadge extends StatelessWidget {
  const RouteEndpointBadge({super.key, required this.letter});
  final String letter;
  @override
  Widget build(BuildContext context) => Tooltip(
    message: letter == 'A' ? 'Route start' : 'Destination',
    child: CircleAvatar(
      backgroundColor: letter == 'A'
          ? explorationColor
          : const Color(0xFFE36478),
      child: Text(
        letter,
        textScaler: TextScaler.noScaling,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

class PlannedRouteLayer extends StatelessWidget {
  const PlannedRouteLayer({super.key, required this.plan, this.reached = 0});
  final RoutePlan plan;
  final int reached;

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      PolylineLayer(
        polylines: [
          Polyline(
            points: plan.points.map((p) => p.latLng).toList(),
            strokeWidth: 4,
            color: explorationColor,
            pattern: const StrokePattern.dotted(),
          ),
        ],
      ),
      MarkerLayer(
        markers: [
          if (!plan.isLoop)
            RouteEndpointMarker(point: plan.points.first, letter: 'A'),
          for (final (index, checkpoint) in plan.checkpoints.indexed)
            Marker(
              point: checkpoint.point.latLng,
              width: 36,
              height: 60,
              // The stem anchors the badge without covering the live marker.
              alignment: Marker.computePixelAlignment(
                width: 36,
                height: 60,
                left: 18,
                top: 0,
              ),
              rotate: true,
              child: Tooltip(
                message: index < reached
                    ? 'Checkpoint ${index + 1} reached'
                    : index == plan.checkpoints.length - 1
                    ? plan.isLoop
                          ? 'Return to start'
                          : 'Destination'
                    : 'Checkpoint ${index + 1}',
                child: Column(
                  children: [
                    const SizedBox(
                      width: 2,
                      height: 24,
                      child: ColoredBox(color: explorationColor),
                    ),
                    SizedBox.square(
                      dimension: 36,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: index < reached
                              ? explorationColor
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: explorationColor, width: 2),
                        ),
                        child: Center(
                          child: index < reached
                              ? const Icon(
                                  Icons.check,
                                  size: 22,
                                  color: Colors.white,
                                  applyTextScaling: false,
                                )
                              : Text(
                                  !plan.isLoop &&
                                          index == plan.checkpoints.length - 1
                                      ? 'B'
                                      : '${index + 1}',
                                  textScaler: TextScaler.noScaling,
                                  style: const TextStyle(
                                    color: explorationColor,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class ExploredAreasLayer extends StatelessWidget {
  const ExploredAreasLayer({super.key, required this.cells});
  final List<ExplorationCell> cells;

  @override
  Widget build(BuildContext context) => PolygonLayer(
    polygons: [
      for (final cell in cells)
        Polygon(
          points: cell.corners.map((p) => p.latLng).toList(),
          color: explorationColor.withValues(alpha: 0.16),
          borderColor: explorationColor.withValues(alpha: 0.4),
          borderStrokeWidth: 1,
        ),
    ],
  );
}

class WalkSummary extends StatelessWidget {
  const WalkSummary({super.key, required this.progress, this.location});
  final WalkProgress progress;
  final LocationDM? location;

  @override
  Widget build(BuildContext context) {
    final next = progress.next;
    final here = location;
    final distance = next == null || here == null
        ? null
        : next.point.distanceTo(GeoPoint(here.latitude, here.longitude));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          progress.completed
              ? progress.plan.isLoop
                    ? 'Loop completed'
                    : 'Walk completed'
              : progress.recording
              ? 'Walking route'
              : 'Walk ended early',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: explorationColor,
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            Text(
              '${progress.reached} / ${progress.plan.checkpoints.length} checkpoints',
            ),
            Text('${progress.newCells} new areas'),
            if (distance != null) Text('Next: ${distance.round()} m away'),
          ],
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: progress.reached / progress.plan.checkpoints.length,
          color: explorationColor,
          backgroundColor: explorationColor.withValues(alpha: 0.12),
          semanticsLabel: 'Checkpoint progress',
        ),
      ],
    );
  }
}

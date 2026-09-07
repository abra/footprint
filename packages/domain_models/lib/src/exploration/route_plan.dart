import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

import 'geo_point.dart';

enum RoutePlanMode { loop, pointToPoint }

class WalkCheckpoint extends Equatable {
  const WalkCheckpoint({required this.point, required this.distanceAlong});
  final GeoPoint point;
  final double distanceAlong;
  @override
  List<Object> get props => [point, distanceAlong];
}

/// A proposed walking path, independent of the recorded GPS trace.
class RoutePlan extends Equatable {
  RoutePlan._({
    required this.id,
    required this.mode,
    required this.requestedDistance,
    required this.distance,
    required List<GeoPoint> points,
    required List<WalkCheckpoint> checkpoints,
  }) : points = List.unmodifiable(points),
       checkpoints = List.unmodifiable(checkpoints);

  factory RoutePlan.fromGeometry({
    required String id,
    double? requestedDistance,
    RoutePlanMode mode = RoutePlanMode.loop,
    required List<GeoPoint> points,
  }) {
    final loop = mode == RoutePlanMode.loop;
    if (id.isEmpty ||
        points.length < (loop ? 4 : 2) ||
        points.length > 20000 ||
        points.any((p) => !p.isValid)) {
      throw const FormatException('Invalid walking route geometry.');
    }
    if (loop &&
        (requestedDistance == null ||
            !requestedDistance.isFinite ||
            requestedDistance < 1000 ||
            requestedDistance > 20000 ||
            points.first.distanceTo(points.last) > 40)) {
      throw const FormatException('A closed walking route is required.');
    }
    if (!loop && requestedDistance != null) {
      throw const FormatException(
        'Point-to-point distance comes from the route.',
      );
    }
    final lengths = <double>[0];
    for (var i = 1; i < points.length; i++) {
      lengths.add(lengths.last + points[i - 1].distanceTo(points[i]));
    }
    final distance = lengths.last;
    if (!distance.isFinite ||
        distance <= 0 ||
        (loop &&
            (distance - requestedDistance!).abs() > requestedDistance * 0.1) ||
        (!loop && (distance < 100 || distance > 20000))) {
      throw const FormatException(
        'Route length is outside the requested range.',
      );
    }
    final count = ((requestedDistance ?? distance) / 1000).ceil().clamp(
      loop ? 3 : 1,
      10,
    );
    final checkpoints = <WalkCheckpoint>[];
    var segment = 1;
    const geodesic = DistanceHaversine(roundResult: false);
    for (var i = 1; i <= count; i++) {
      final target = distance * i / count;
      while (segment < points.length - 1 && lengths[segment] < target) {
        segment++;
      }
      final from = points[segment - 1].latLng;
      final to = points[segment].latLng;
      final position = i == count
          ? points.last.latLng
          : geodesic.offset(
              from,
              target - lengths[segment - 1],
              geodesic.bearing(from, to),
            );
      checkpoints.add(
        WalkCheckpoint(
          point: GeoPoint(position.latitude, position.longitude),
          distanceAlong: target,
        ),
      );
    }
    if (checkpoints.first.point.distanceTo(points.first) < 100 ||
        checkpoints.indexed
            .skip(1)
            .any(
              (entry) =>
                  entry.$2.point.distanceTo(checkpoints[entry.$1 - 1].point) <
                  70,
            )) {
      throw const FormatException('Route checkpoints are too close together.');
    }
    return RoutePlan._(
      id: id,
      mode: mode,
      requestedDistance: requestedDistance,
      distance: distance,
      points: points,
      checkpoints: checkpoints,
    );
  }

  factory RoutePlan.fromMap(Map<String, dynamic> map) {
    if (map['version'] != 1 && map['version'] != 2) {
      throw const FormatException('Unsupported route plan version.');
    }
    final mode = map['version'] == 1
        ? RoutePlanMode.loop
        : switch (map['mode']) {
            'loop' => RoutePlanMode.loop,
            'point_to_point' => RoutePlanMode.pointToPoint,
            _ => throw const FormatException('Unsupported route plan mode.'),
          };
    final validated = RoutePlan.fromGeometry(
      id: map['id'] as String,
      mode: mode,
      requestedDistance: (map['requested_distance'] as num?)?.toDouble(),
      points: (map['coordinates'] as List)
          .map((p) => GeoPoint.fromCoordinates(p as List))
          .toList(),
    );
    final checkpoints = (map['checkpoints'] as List).map((entry) {
      final value = entry as Map<String, dynamic>;
      return WalkCheckpoint(
        point: GeoPoint.fromCoordinates(value['coordinates'] as List),
        distanceAlong: (value['distance_along'] as num).toDouble(),
      );
    }).toList();
    if (checkpoints.length < (validated.isLoop ? 3 : 1) ||
        checkpoints.length > 10 ||
        checkpoints.any(
          (c) =>
              !c.distanceAlong.isFinite ||
              c.distanceAlong <= 0 ||
              c.distanceAlong > validated.distance + 1,
        ) ||
        checkpoints.indexed
            .skip(1)
            .any(
              (entry) =>
                  entry.$2.distanceAlong <=
                  checkpoints[entry.$1 - 1].distanceAlong,
            )) {
      throw const FormatException('Invalid saved checkpoints.');
    }
    return RoutePlan._(
      id: validated.id,
      mode: mode,
      requestedDistance: validated.requestedDistance,
      distance: validated.distance,
      points: validated.points,
      checkpoints: checkpoints,
    );
  }

  final String id;
  final RoutePlanMode mode;
  bool get isLoop => mode == RoutePlanMode.loop;
  final double? requestedDistance;
  final double distance;
  final List<GeoPoint> points;
  final List<WalkCheckpoint> checkpoints;

  /// Uniform sampling avoids rewarding routes merely for denser API geometry.
  late final List<GeoPoint> explorationSamples = _sample();

  List<GeoPoint> _sample() {
    const geodesic = DistanceHaversine(roundResult: false);
    final samples = <GeoPoint>[points.first];
    var traveled = 0.0;
    var next = 40.0;
    for (var i = 1; i < points.length; i++) {
      final from = points[i - 1];
      final to = points[i];
      final length = from.distanceTo(to);
      while (next <= traveled + length) {
        final point = geodesic.offset(
          from.latLng,
          next - traveled,
          geodesic.bearing(from.latLng, to.latLng),
        );
        samples.add(GeoPoint(point.latitude, point.longitude));
        next += 40;
      }
      traveled += length;
    }
    return List.unmodifiable(samples);
  }

  Duration get estimatedDuration =>
      Duration(seconds: (distance / 1.25).round());

  Map<String, dynamic> toMap() => {
    'version': 2,
    'mode': isLoop ? 'loop' : 'point_to_point',
    'id': id,
    'requested_distance': requestedDistance,
    'coordinates': points.map((p) => p.coordinates).toList(),
    'checkpoints': checkpoints
        .map(
          (c) => {
            'coordinates': c.point.coordinates,
            'distance_along': c.distanceAlong,
          },
        )
        .toList(),
  };

  @override
  List<Object?> get props => [id, mode, requestedDistance, points, checkpoints];
}

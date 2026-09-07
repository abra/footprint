import 'package:domain_models/domain_models.dart';
import 'package:latlong2/latlong.dart';

final walkEpoch = DateTime.utc(2026, 9, 7, 12);

RoutePlan pointToPointPlan({
  GeoPoint start = const GeoPoint(0.0005, 0.0005),
  GeoPoint end = const GeoPoint(0.012, 0.0005),
}) => RoutePlan.fromGeometry(
  id: 'point-to-point',
  mode: RoutePlanMode.pointToPoint,
  points: [start, end],
);

RoutePlan loopPlan({
  String id = 'loop',
  double distance = 1200,
  GeoPoint start = const GeoPoint(0.0005, 0.0005),
}) {
  const geodesic = DistanceHaversine(roundResult: false);
  final points = <GeoPoint>[start];
  for (final bearing in [0.0, 90.0, 180.0]) {
    final point = geodesic.offset(points.last.latLng, distance / 4, bearing);
    points.add(GeoPoint(point.latitude, point.longitude));
  }
  points.add(start);
  return RoutePlan.fromGeometry(
    id: id,
    requestedDistance: distance,
    points: points,
  );
}

LocationDM walkFix(
  GeoPoint point,
  int second, {
  double? accuracy = 5,
  double? speed = 0.8,
}) => LocationDM(
  id: 'walk:$second',
  latitude: point.latitude,
  longitude: point.longitude,
  timestamp: walkEpoch.add(Duration(seconds: second)),
  accuracy: accuracy,
  speed: speed,
  speedAccuracy: 0.2,
);

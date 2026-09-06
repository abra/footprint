import 'package:domain_models/domain_models.dart';
import 'package:test/test.dart';

void main() {
  test(
    'location accepts numeric JSON coordinates and preserves its timestamp',
    () {
      final location = LocationDM.fromMap({
        'id': 'point',
        'latitude': 56,
        'longitude': 60.5,
        'timestamp': '2026-09-06T10:00:00.000Z',
      });
      expect(location.latitude, 56.0);
      expect(LocationDM.fromMap(location.toMap()), location);
      expect(
        LocationDM(
          id: location.id,
          latitude: 56,
          longitude: 60.5,
          timestamp: location.timestamp.add(const Duration(seconds: 1)),
        ),
        isNot(location),
      );
    },
  );

  test(
    'active routes accept missing completion data and own immutable points',
    () {
      final points = <RoutePointDM>[];
      final route = RouteDM(
        id: 1,
        startTime: DateTime(2026),
        status: Status.active,
        routePoints: points,
      );
      expect(route.endTime, isNull);
      expect(route.startPoint, isNull);
      expect(() => route.routePoints.clear(), throwsUnsupportedError);
      points.add(
        RoutePointDM(
          id: 1,
          routeId: 1,
          latitude: 0,
          longitude: 0,
          address: '',
          timestamp: DateTime(2026),
        ),
      );
      expect(route.routePoints, isEmpty);
    },
  );
}

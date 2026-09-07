import 'package:domain_models/domain_models.dart';
import 'package:test/test.dart';

void main() {
  test(
    'filtered coordinates preserve raw observations and metadata on round trip',
    () {
      final raw = LocationDM(
        id: 'raw',
        latitude: 56.00001,
        longitude: 60.00001,
        timestamp: DateTime.utc(2026, 9, 7),
        accuracy: 5,
        speed: 0,
        speedAccuracy: 0.2,
      );
      final filtered = raw.withFilteredPosition(
        latitude: 56,
        longitude: 60,
        isStationary: true,
        filteredSpeed: 0,
      );
      expect(filtered.rawLatitude, raw.latitude);
      expect(filtered.rawLongitude, raw.longitude);
      expect(filtered.timestamp, raw.timestamp);
      expect(filtered.id, raw.id);
      expect(LocationDM.fromMap(filtered.toMap()), filtered);
      final again = filtered.withFilteredPosition(
        latitude: 55,
        longitude: 59,
        isStationary: false,
      );
      expect(again.rawLatitude, raw.latitude);
      expect(again.rawLongitude, raw.longitude);
      final point = RoutePointDM.fromMap({
        ...filtered.toMap(),
        'id': 1,
        'source_id': raw.id,
        'route_id': 2,
        'address': '',
      });
      expect(point.toLocation(), filtered);
      expect(RoutePointDM.fromMap(point.toMap()), point);
    },
  );
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

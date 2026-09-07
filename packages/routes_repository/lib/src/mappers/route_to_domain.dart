import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart' as storage;

extension RouteToDomain on storage.Route {
  RouteDM toDomain() => RouteDM(
    id: id,
    name: name,
    startTime: DateTime.parse(startTime),
    endTime: endTime == null ? null : DateTime.parse(endTime!),
    distance: distance,
    averageSpeed: averageSpeed,
    status: Status.values.byName(status!),
    routePoints: [
      for (final point in routePoints ?? [])
        RoutePointDM(
          id: point.id,
          routeId: point.routeId,
          latitude: point.latitude,
          longitude: point.longitude,
          address: point.address ?? '',
          timestamp: DateTime.parse(point.timestamp),
          sourceId: point.sourceId,
          accuracy: point.accuracy,
          speed: point.speed,
          speedAccuracy: point.speedAccuracy,
          filteredSpeed: point.filteredSpeed,
          rawLatitude: point.rawLatitude,
          rawLongitude: point.rawLongitude,
          isStationary: point.isStationary,
        ),
    ],
  );
}

import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'mappers/route_to_domain.dart';

class RoutesRepository {
  RoutesRepository({required SqliteStorage sqliteStorage})
    : _routes = sqliteStorage.routes;

  final RoutesDao _routes;

  Future<List<RouteDM>> getRoutes() async =>
      (await _routes.getAll()).map((route) => route.toDomain()).toList();

  Future<RouteDM?> getRoute(int id) async =>
      (await _routes.getById(id))?.toDomain();

  Future<RouteDM?> getActiveRoute() async =>
      (await _routes.getActive())?.toDomain();

  Future<int> startRoute(LocationDM location) => _routes.create(
    latitude: location.latitude,
    longitude: location.longitude,
    timestamp: location.timestamp,
    sourceId: location.id,
  );

  Future<bool> addPoint(int id, LocationDM location) => _routes.addPoint(
    routeId: id,
    latitude: location.latitude,
    longitude: location.longitude,
    timestamp: location.timestamp,
    sourceId: location.id,
  );

  Future<void> finishRoute(int id, DateTime endTime) =>
      _routes.complete(id, endTime);
  Future<void> deleteRoute(int id) => _routes.delete(id);
}

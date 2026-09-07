import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'mappers/route_to_domain.dart';
import 'photos/route_photos_repository.dart';

class RoutesRepository {
  RoutesRepository({required SqliteStorage sqliteStorage, this._photos})
    : _routes = sqliteStorage.routes,
      _statistics = sqliteStorage.statistics;

  final RoutesDao _routes;
  final RouteStatisticsDao _statistics;
  final RoutePhotosRepository? _photos;

  Future<List<RecordedRouteSummary>> getRecordedSummaries() =>
      _statistics.getSummaries();

  Future<List<RouteDM>> getRoutes() async =>
      (await _routes.getAll()).map((route) => route.toDomain()).toList();

  Future<List<RouteDM>> getRoutePage({
    String query = '',
    RouteSort sort = RouteSort.newest,
    int offset = 0,
    int limit = 20,
  }) async {
    if (offset < 0 || limit < 1 || limit > 100) {
      throw ArgumentError('Invalid route page.');
    }
    final rows = await _routes.getAll(
      query: query.trim(),
      offset: offset,
      limit: limit,
      orderBy: switch (sort) {
        RouteSort.newest => 'start_time DESC, id DESC',
        RouteSort.oldest => 'start_time ASC, id ASC',
        RouteSort.name => "coalesce(name_search, start_time) ASC, id ASC",
      },
    );
    return rows.map((route) => route.toDomain()).toList();
  }

  Future<void> renameRoute(int id, String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 80) {
      throw ArgumentError('Route name must contain 1 to 80 characters.');
    }
    return _routes.rename(id, trimmed);
  }

  Future<RouteDM?> getRoute(int id) async =>
      (await _routes.getById(id))?.toDomain();

  Future<RouteDM?> getActiveRoute() async =>
      (await _routes.getActive())?.toDomain();

  Future<int> startRoute(LocationDM location, {RoutePlan? plan}) =>
      _routes.create(
        plan: plan,
        latitude: location.latitude,
        longitude: location.longitude,
        timestamp: location.timestamp,
        sourceId: location.id,
        accuracy: location.accuracy,
        speed: location.speed,
        speedAccuracy: location.speedAccuracy,
        filteredSpeed: location.filteredSpeed,
        rawLatitude: location.rawLatitude,
        rawLongitude: location.rawLongitude,
        isStationary: location.isStationary,
      );

  Future<bool> addPoint(int id, LocationDM location) => _routes.addPoint(
    routeId: id,
    latitude: location.latitude,
    longitude: location.longitude,
    timestamp: location.timestamp,
    sourceId: location.id,
    accuracy: location.accuracy,
    speed: location.speed,
    speedAccuracy: location.speedAccuracy,
    filteredSpeed: location.filteredSpeed,
    rawLatitude: location.rawLatitude,
    rawLongitude: location.rawLongitude,
    isStationary: location.isStationary,
  );

  Future<void> finishRoute(int id, DateTime endTime) =>
      _routes.complete(id, endTime);
  Future<void> deleteRoute(int id) async {
    await _routes.delete(id);
    await _photos?.collectGarbage();
  }
}

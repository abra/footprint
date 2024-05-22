import 'package:domain_models/domain_models.dart';

abstract interface class LocalStorageInterface {
  Future<void> init();

  Future<int> createRoute(Location location);

  Future<void> addRoutePoints(int routeId, Location location);

  Future<int> changeRouteStatus(int routeId, int status);

  Future<void> deleteRoute(int routeId);

  Future<List<Location>> getRoutePoints(int routeId);
}

import 'package:footprint/src/domain_models/location.dart';

abstract interface class LocalStorage {
  Future<void> init();

  Future<int> createRoute(Location location);

  Future<void> addRoutePoints(int routeId, Location location);

  Future<int> changeRouteStatus(int routeId, int status);

  Future<void> deleteRoute(int routeId);

  Future<List<Location>> getRoutePoints(int routeId);
}

import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:routes_repository/routes_repository.dart';

LocationDM location(int index) => LocationDM(
  id: '$index',
  latitude: 56 + index * 0.0001,
  longitude: 60,
  timestamp: DateTime.utc(2026, 9, 6, 10, 0, index),
);

class FakeRoutePhotosRepository extends Fake implements RoutePhotosRepository {
  final photos = <RoutePhotoDM>[];
  @override
  Stream<int> get changes => const Stream.empty();
  @override
  Future<void> initialize() async {}
  @override
  Future<void> retryPending() async {}
  @override
  Future<void> discardPending() async {}
  @override
  Future<List<RoutePhotoDM>> getPhotos(int id) async =>
      photos.where((photo) => photo.routeId == id).toList();
  @override
  Future<void> dispose() async {}
}

class FakeLocationService implements LocationService {
  final controller = StreamController<LocationDM>.broadcast();
  final modes = <LocationMode>[];
  bool disposed = false;
  bool failStart = false;
  bool failStop = false;
  int starts = 0;
  LocationMode mode = LocationMode.stopped;
  @override
  LocationDM? lastLocation;
  @override
  Stream<LocationDM> get locations => controller.stream;
  void send(LocationDM value) {
    lastLocation = value;
    controller.add(value);
  }

  @override
  Future<void> setMode(
    LocationMode value, {
    bool restart = false,
    LocationDM? initialLocation,
  }) async {
    if (value == mode && !restart) return;
    modes.add(value);
    if (value == LocationMode.stopped) {
      if (failStop) throw StateError('Stop failed');
    } else {
      starts++;
      if (failStart) throw LocationServicePermissionDeniedException();
    }
    mode = value;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await controller.close();
  }
}

class FakeRoutesRepository extends Fake implements RoutesRepository {
  RouteDM? active;
  final saved = <int, RouteDM>{};
  Completer<RouteDM?>? activeGate;
  Completer<int>? startGate;
  Completer<void>? pointGate;
  Completer<void>? finishGate;
  final added = <LocationDM>[];
  int finished = 0;
  int finishAttempts = 0;
  bool failStart = false;
  bool failPoint = false;
  bool failFinish = false;

  @override
  Future<RouteDM?> getActiveRoute() async =>
      activeGate == null ? active : activeGate!.future;
  @override
  Future<List<RouteDM>> getRoutes() async => [?active, ...saved.values];
  @override
  Future<List<RouteDM>> getRoutePage({
    String query = '',
    RouteSort sort = RouteSort.newest,
    int offset = 0,
    int limit = 20,
  }) async => (await getRoutes()).skip(offset).take(limit).toList();
  @override
  Future<void> renameRoute(int id, String name) async {
    final route = saved[id]!;
    saved[id] = RouteDM(
      id: id,
      name: name,
      startTime: route.startTime,
      endTime: route.endTime,
      status: route.status,
      routePoints: route.routePoints,
    );
  }

  @override
  Future<void> deleteRoute(int id) async => saved.remove(id);
  @override
  Future<RouteDM?> getRoute(int id) async =>
      active?.id == id ? active : saved[id];
  @override
  Future<int> startRoute(LocationDM location) async {
    if (failStart) throw StateError('Disk full');
    final id = startGate == null ? saved.length + 1 : await startGate!.future;
    active = RouteDM(
      id: id,
      startTime: location.timestamp,
      status: Status.active,
      routePoints: [_point(id, location)],
    );
    return id;
  }

  RoutePointDM _point(int id, LocationDM value) => RoutePointDM(
    id: added.length + 1,
    routeId: id,
    sourceId: value.id,
    latitude: value.latitude,
    longitude: value.longitude,
    address: '',
    timestamp: value.timestamp,
    accuracy: value.accuracy,
    speed: value.speed,
    speedAccuracy: value.speedAccuracy,
    filteredSpeed: value.filteredSpeed,
    rawLatitude: value.rawLatitude,
    rawLongitude: value.rawLongitude,
    isStationary: value.isStationary,
  );

  @override
  Future<bool> addPoint(int id, LocationDM location) async {
    await pointGate?.future;
    if (failPoint) throw StateError('Disk full');
    final route = active;
    if (route == null ||
        route.id != id ||
        route.routePoints.any((point) => point.sourceId == location.id)) {
      return false;
    }
    added.add(location);
    active = RouteDM(
      id: id,
      startTime: route.startTime,
      status: Status.active,
      routePoints: [...route.routePoints, _point(id, location)],
    );
    return true;
  }

  @override
  Future<void> finishRoute(int id, DateTime timestamp) async {
    finishAttempts++;
    await finishGate?.future;
    if (failFinish) throw StateError('Disk full');
    final route = active!;
    saved[id] = RouteDM(
      id: id,
      startTime: route.startTime,
      endTime: timestamp,
      status: Status.completed,
      routePoints: route.routePoints,
    );
    active = null;
    finished++;
  }
}

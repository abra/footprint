import 'package:equatable/equatable.dart';

import 'route_point_dm.dart';
import 'location_dm.dart';
import 'route_metrics.dart';

class RouteDM extends Equatable {
  RouteDM({
    required this.id,
    required this.startTime,
    this.name,
    this.endTime,
    this.distance,
    this.averageSpeed,
    required this.status,
    List<RoutePointDM> routePoints = const [],
  }) : routePoints = List.unmodifiable(routePoints);

  final int id;
  final String? name;
  final DateTime startTime;
  final DateTime? endTime;
  final double? distance;
  final double? averageSpeed;
  final Status status;
  final List<RoutePointDM> routePoints;

  late final RouteMetrics metrics = RouteMetrics.fromLocations(
    routePoints.map(
      (point) => LocationDM(
        id: '${point.id}',
        latitude: point.latitude,
        longitude: point.longitude,
        timestamp: point.timestamp,
      ),
    ),
    startedAt: startTime,
    endedAt: endTime,
  );

  RoutePointDM? get startPoint => routePoints.firstOrNull;
  RoutePointDM? get endPoint => routePoints.lastOrNull;

  @override
  List<Object?> get props => [
    id,
    name,
    startTime,
    endTime,
    distance,
    averageSpeed,
    status,
    routePoints,
  ];
}

enum Status { active, completed }

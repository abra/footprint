import 'package:equatable/equatable.dart';

import 'route_point_dm.dart';

class RouteDM extends Equatable {
  RouteDM({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distance,
    this.averageSpeed,
    required this.status,
    List<RoutePointDM> routePoints = const [],
  }) : routePoints = List.unmodifiable(routePoints);

  final int id;
  final DateTime startTime;
  final DateTime? endTime;
  final double? distance;
  final double? averageSpeed;
  final Status status;
  final List<RoutePointDM> routePoints;

  RoutePointDM? get startPoint => routePoints.firstOrNull;
  RoutePointDM? get endPoint => routePoints.lastOrNull;

  @override
  List<Object?> get props => [
    id,
    startTime,
    endTime,
    distance,
    averageSpeed,
    status,
    routePoints,
  ];
}

enum Status { active, completed }

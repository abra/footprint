import 'package:equatable/equatable.dart';

import 'route_point_dm.dart';

/// Domain model for route. DM stands for Domain Model.
class RouteDM extends Equatable {
  const RouteDM({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.averageSpeed,
    required this.status,
    required this.routePoints,
  });

  final String id;
  final RoutePointDM startPoint;
  final RoutePointDM endPoint;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double averageSpeed;
  final Status status;
  final List<RoutePointDM> routePoints;

  factory RouteDM.fromMap(Map<String, dynamic> map) {
    return RouteDM(
      id: map['id'] as String,
      startPoint:
          RoutePointDM.fromMap(map['start_point'] as Map<String, dynamic>),
      endPoint: RoutePointDM.fromMap(map['end_point'] as Map<String, dynamic>),
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      distance: map['distance'] as double,
      averageSpeed: map['average_speed'] as double,
      status: Status.values.byName(map['status'] as String),
      routePoints: (map['route_points'] as List<dynamic>)
          .map((map) => RoutePointDM.fromMap(map as Map<String, dynamic>))
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        startPoint,
        endPoint,
        startTime,
        endTime,
        distance,
        averageSpeed,
        status,
        routePoints,
      ];
}

enum Status {
  active,
  completed,
}

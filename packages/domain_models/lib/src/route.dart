import 'package:equatable/equatable.dart';

import 'route_point.dart';

class Route extends Equatable {
  const Route({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.averageSpeed,
    this.status = Status.active,
    required this.routePoints,
  });

  final String id;
  final RoutePoint startPoint;
  final RoutePoint endPoint;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double averageSpeed;
  final Status status;
  final List<RoutePoint> routePoints;

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

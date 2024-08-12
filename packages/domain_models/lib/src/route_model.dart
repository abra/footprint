import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

import 'route_point_model.dart';

@immutable
class RouteModel extends Equatable {
  const RouteModel({
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
  final RoutePointModel startPoint;
  final RoutePointModel endPoint;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final double averageSpeed;
  final Status status;
  final List<RoutePointModel> routePoints;

  static RouteModel fromMap(Map<String, dynamic> map) {
    return RouteModel(
      id: map['id'] as String,
      startPoint:
          RoutePointModel.fromMap(map['start_point'] as Map<String, dynamic>),
      endPoint: RoutePointModel.fromMap(map['end_point'] as Map<String, dynamic>),
      startTime: DateTime.parse(map['start_time'] as String),
      endTime: DateTime.parse(map['end_time'] as String),
      distance: map['distance'] as double,
      averageSpeed: map['average_speed'] as double,
      status: Status.values.byName(map['status'] as String),
      routePoints: (map['route_points'] as List<dynamic>)
          .map((map) => RoutePointModel.fromMap(map as Map<String, dynamic>))
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

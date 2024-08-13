import 'route_point_dto.dart';

class RouteDTO {
  const RouteDTO({
    required this.id,
    required this.startTime,
    this.endTime,
    this.distance,
    this.averageSpeed,
    this.status,
    this.routePoints,
  });

  final String id;
  final String startTime;
  final String? endTime;
  final double? distance;
  final double? averageSpeed;
  final String? status;
  final List<RoutePointDTO>? routePoints;

  factory RouteDTO.fromMap(Map<String, dynamic> map) {
    return RouteDTO(
      id: map['id'] as String,
      startTime: map['start_time'] as String,
      endTime: map['end_time'] as String?,
      distance: map['distance'] as double?,
      averageSpeed: map['average_speed'] as double?,
      status: map['status'] as String?,
      routePoints: (map['route_points'] as List<dynamic>)
          .map((map) => RoutePointDTO.fromMap(map as Map<String, dynamic>))
          .toList(),
    );
  }
}

import 'location.dart';

class Route {
  const Route({
    required this.id,
    required this.startPoint,
    required this.endPoint,
    required this.startTime,
    required this.endTime,
    required this.distance,
    required this.status,
    required this.routePoints,
  });

  final String id;
  final Location startPoint;
  final Location endPoint;
  final DateTime startTime;
  final DateTime endTime;
  final double distance;
  final RouteStatus status;
  final List<Location> routePoints;
}

enum RouteStatus {
  notStarted,
  inProgress,
  finished,
}

import 'package:equatable/equatable.dart';

class RoutePoint extends Equatable {
  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
  });

  final int id;
  final int routeId;
  final double latitude;
  final double longitude;
  final String address;
  final DateTime timestamp;

  static RoutePoint fromMap(Map<String, dynamic> map) {
    return RoutePoint(
      id: map['id'] as int,
      routeId: map['route_id'] as int,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      address: map['address'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }

  @override
  List<Object?> get props => [
        id,
        routeId,
        latitude,
        longitude,
        address,
        timestamp,
      ];
}

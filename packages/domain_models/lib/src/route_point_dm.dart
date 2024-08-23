import 'package:equatable/equatable.dart';

/// Domain model for route point. DM stands for Domain Model.
class RoutePointDM extends Equatable {
  const RoutePointDM({
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

  factory RoutePointDM.fromMap(Map<String, dynamic> map) => RoutePointDM(
        id: map['id'] as int,
        routeId: map['route_id'] as int,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        address: map['address'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'route_id': routeId,
        'latitude': latitude,
        'longitude': longitude,
        'address': address,
        'timestamp': timestamp.toIso8601String(),
      };

  @override
  List<Object?> get props => [
        id,
        routeId,
        latitude,
        longitude,
        address,
      ];
}

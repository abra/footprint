import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
class RoutePointModel extends Equatable {
  const RoutePointModel({
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

  factory RoutePointModel.fromMap(Map<String, dynamic> map) => RoutePointModel(
        id: map['id'] as int,
        routeId: map['route_id'] as int,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        address: map['address'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

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

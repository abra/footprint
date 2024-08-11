import 'package:equatable/equatable.dart';

import '../domain_models.dart';

class RoutePoint extends Equatable {
  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.locationAddress,
    required this.timestamp,
  });

  final int id;
  final int routeId;
  final double latitude;
  final double longitude;
  final LocationAddress locationAddress;
  final DateTime timestamp;

  @override
  List<Object?> get props => [
        id,
        routeId,
        latitude,
        longitude,
        locationAddress,
        timestamp,
      ];
}

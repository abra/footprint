import 'package:equatable/equatable.dart';

enum PhotoSource { camera, gallery }

class RoutePhotoDM extends Equatable {
  const RoutePhotoDM({
    required this.id,
    required this.routeId,
    required this.path,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
  });

  final String id;
  final int routeId;
  final String path;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;

  @override
  List<Object?> get props => [
    id,
    routeId,
    path,
    latitude,
    longitude,
    capturedAt,
  ];
}

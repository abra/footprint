class RoutePoint {
  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
  });

  final String id;
  final String routeId;
  final double latitude;
  final double longitude;
  final String address;
  final String timestamp;

  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(
        id: map['id'] as String,
        routeId: map['route_id'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        address: map['address'] as String,
        timestamp: map['timestamp'] as String,
      );
}

class RoutePoint {
  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.sourceId,
  });

  final int id;
  final int routeId;
  final double latitude;
  final double longitude;
  final String? address;
  final String timestamp;
  final String? sourceId;

  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(
    id: map['id'] as int,
    routeId: map['route_id'] as int,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    address: map['address'] as String?,
    timestamp: map['timestamp'] as String,
    sourceId: map['source_id'] as String?,
  );
}

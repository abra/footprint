class RoutePoint {
  const RoutePoint({
    required this.id,
    required this.routeId,
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.timestamp,
    this.sourceId,
    this.accuracy,
    this.speed,
    this.speedAccuracy,
    this.filteredSpeed,
    this.rawLatitude,
    this.rawLongitude,
    this.isStationary = false,
  });

  final int id;
  final int routeId;
  final double latitude;
  final double longitude;
  final String? address;
  final String timestamp;
  final String? sourceId;
  final double? accuracy;
  final double? speed;
  final double? speedAccuracy;
  final double? filteredSpeed;
  final double? rawLatitude;
  final double? rawLongitude;
  final bool isStationary;

  factory RoutePoint.fromMap(Map<String, dynamic> map) => RoutePoint(
    id: map['id'] as int,
    routeId: map['route_id'] as int,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    address: map['address'] as String?,
    timestamp: map['timestamp'] as String,
    sourceId: map['source_id'] as String?,
    accuracy: (map['accuracy'] as num?)?.toDouble(),
    speed: (map['speed'] as num?)?.toDouble(),
    speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble(),
    filteredSpeed: (map['filtered_speed'] as num?)?.toDouble(),
    rawLatitude: (map['raw_latitude'] as num?)?.toDouble(),
    rawLongitude: (map['raw_longitude'] as num?)?.toDouble(),
    isStationary: map['is_stationary'] == 1,
  );
}

class RoutePhoto {
  const RoutePhoto({
    required this.id,
    required this.routeId,
    required this.fileName,
    required this.latitude,
    required this.longitude,
    required this.capturedAt,
    this.sourcePath,
  });

  final String id;
  final int routeId;
  final String fileName;
  final double latitude;
  final double longitude;
  final DateTime capturedAt;
  final String? sourcePath;

  factory RoutePhoto.fromMap(Map<String, Object?> row) => RoutePhoto(
    id: row['id'] as String,
    routeId: row['route_id'] as int,
    fileName: row['file_name'] as String,
    latitude: (row['latitude'] as num).toDouble(),
    longitude: (row['longitude'] as num).toDouble(),
    capturedAt: DateTime.parse(row['captured_at'] as String),
    sourcePath: row['source_path'] as String?,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'route_id': routeId,
    'file_name': fileName,
    'latitude': latitude,
    'longitude': longitude,
    'captured_at': capturedAt.toIso8601String(),
  };
}

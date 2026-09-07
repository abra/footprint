import 'package:equatable/equatable.dart';

import 'location_dm.dart';

/// Domain model for route point. DM stands for Domain Model.
class RoutePointDM extends Equatable {
  const RoutePointDM({
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
  final String address;
  final DateTime timestamp;
  final String? sourceId;
  final double? accuracy;
  final double? speed;
  final double? speedAccuracy;
  final double? filteredSpeed;
  final double? rawLatitude;
  final double? rawLongitude;
  final bool isStationary;

  LocationDM toLocation() => LocationDM(
    id: sourceId ?? 'stored:$id',
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    speed: speed,
    speedAccuracy: speedAccuracy,
    filteredSpeed: filteredSpeed,
    rawLatitude: rawLatitude,
    rawLongitude: rawLongitude,
    isStationary: isStationary,
  );

  factory RoutePointDM.fromMap(Map<String, dynamic> map) => RoutePointDM(
    id: map['id'] as int,
    routeId: map['route_id'] as int,
    latitude: map['latitude'] as double,
    longitude: map['longitude'] as double,
    address: map['address'] as String,
    timestamp: DateTime.parse(map['timestamp'] as String),
    sourceId: map['source_id'] as String?,
    accuracy: (map['accuracy'] as num?)?.toDouble(),
    speed: (map['speed'] as num?)?.toDouble(),
    speedAccuracy: (map['speed_accuracy'] as num?)?.toDouble(),
    filteredSpeed: (map['filtered_speed'] as num?)?.toDouble(),
    rawLatitude: (map['raw_latitude'] as num?)?.toDouble(),
    rawLongitude: (map['raw_longitude'] as num?)?.toDouble(),
    isStationary: map['is_stationary'] == true,
  );

  Map<String, dynamic> toMap() => {
    'id': id,
    'route_id': routeId,
    'latitude': latitude,
    'longitude': longitude,
    'address': address,
    'timestamp': timestamp.toIso8601String(),
    if (sourceId != null) 'source_id': sourceId,
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (speedAccuracy != null) 'speed_accuracy': speedAccuracy,
    if (filteredSpeed != null) 'filtered_speed': filteredSpeed,
    if (rawLatitude != null) 'raw_latitude': rawLatitude,
    if (rawLongitude != null) 'raw_longitude': rawLongitude,
    if (isStationary) 'is_stationary': true,
  };

  @override
  List<Object?> get props => [
    id,
    routeId,
    latitude,
    longitude,
    address,
    timestamp,
    sourceId,
    accuracy,
    speed,
    speedAccuracy,
    filteredSpeed,
    rawLatitude,
    rawLongitude,
    isStationary,
  ];
}

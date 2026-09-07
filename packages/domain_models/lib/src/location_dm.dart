import 'package:equatable/equatable.dart';

/// Domain model for location. DM stands for Domain Model.
class LocationDM extends Equatable {
  const LocationDM({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
    this.accuracy,
    this.speed,
    this.speedAccuracy,
    this.filteredSpeed,
    this.rawLatitude,
    this.rawLongitude,
    this.isStationary = false,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;
  final double? accuracy;
  final double? speed;
  final double? speedAccuracy;

  /// Motion estimate before presentation interpolation; null for legacy fixes.
  final double? filteredSpeed;
  final double? rawLatitude;
  final double? rawLongitude;
  final bool isStationary;

  /// Sensor speed in m/s, only when its reported uncertainty is usable.
  double? get reliableSpeed {
    final value = speed;
    final uncertainty = speedAccuracy;
    if (value == null ||
        !value.isFinite ||
        value < 0 ||
        uncertainty == null ||
        !uncertainty.isFinite ||
        uncertainty < 0 ||
        uncertainty > 1) {
      return null;
    }
    return value;
  }

  LocationDM withFilteredPosition({
    required double latitude,
    required double longitude,
    required bool isStationary,
    double? filteredSpeed,
  }) => LocationDM(
    id: id,
    latitude: latitude,
    longitude: longitude,
    timestamp: timestamp,
    accuracy: accuracy,
    speed: speed,
    speedAccuracy: speedAccuracy,
    filteredSpeed: filteredSpeed ?? this.filteredSpeed,
    rawLatitude: rawLatitude ?? this.latitude,
    rawLongitude: rawLongitude ?? this.longitude,
    isStationary: isStationary,
  );

  bool get hasValidCoordinates =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;

  factory LocationDM.fromMap(Map<String, dynamic> map) => LocationDM(
    id: map['id'] as String,
    latitude: (map['latitude'] as num).toDouble(),
    longitude: (map['longitude'] as num).toDouble(),
    timestamp: DateTime.parse(map['timestamp'] as String),
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
    'latitude': latitude,
    'longitude': longitude,
    'timestamp': timestamp.toIso8601String(),
    if (accuracy != null) 'accuracy': accuracy,
    if (speed != null) 'speed': speed,
    if (speedAccuracy != null) 'speed_accuracy': speedAccuracy,
    if (filteredSpeed != null) 'filtered_speed': filteredSpeed,
    if (rawLatitude != null) 'raw_latitude': rawLatitude,
    if (rawLongitude != null) 'raw_longitude': rawLongitude,
    if (isStationary) 'is_stationary': true,
  };

  @override
  String toString() {
    return 'LocationDM(id: $id, latitude: $latitude, longitude: $longitude, timestamp: $timestamp)';
  }

  @override
  List<Object?> get props => [
    id,
    latitude,
    longitude,
    timestamp,
    accuracy,
    speed,
    speedAccuracy,
    filteredSpeed,
    rawLatitude,
    rawLongitude,
    isStationary,
  ];
}

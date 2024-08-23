import 'package:equatable/equatable.dart';

/// Domain model for location. DM stands for Domain Model.
class LocationDM extends Equatable {
  const LocationDM({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory LocationDM.fromMap(Map<String, dynamic> map) => LocationDM(
        id: map['id'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
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
      ];
}

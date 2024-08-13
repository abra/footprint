import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
class LocationModel extends Equatable {
  const LocationModel({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  factory LocationModel.fromMap(Map<String, dynamic> map) => LocationModel(
        id: map['id'] as String,
        latitude: map['latitude'] as double,
        longitude: map['longitude'] as double,
        timestamp: DateTime.parse(map['timestamp'] as String),
      );

  @override
  List<Object?> get props => [
        id,
        latitude,
        longitude,
        timestamp,
      ];
}

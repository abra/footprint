import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

@immutable
class Location extends Equatable {
  const Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  static Location fromMap(Map<String, dynamic> map) => Location(
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

import 'package:equatable/equatable.dart';

class LocationAddress extends Equatable {
  const LocationAddress({
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.name,
    required this.locality,
    required this.administrativeArea,
    required this.country,
    required this.postalCode,
    required this.subAdministrativeArea,
    required this.subLocality,
    required this.subThoroughfare,
    required this.thoroughfare,
  });

  final DateTime timestamp;
  final double latitude;
  final double longitude;
  final String name;
  final String locality;
  final String administrativeArea;
  final String country;
  final String postalCode;
  final String subAdministrativeArea;
  final String subLocality;
  final String subThoroughfare;
  final String thoroughfare;

  @override
  List<Object?> get props => [
        timestamp,
        latitude,
        longitude,
        name,
        locality,
        administrativeArea,
        country,
        postalCode,
        subAdministrativeArea,
        subLocality,
        subThoroughfare,
        thoroughfare,
      ];
}

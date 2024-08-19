import 'package:equatable/equatable.dart';

/// Domain model for place address. DM stands for Domain Model.
class PlaceAddressDM extends Equatable {
  const PlaceAddressDM({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;

  @override
  String toString() {
    return 'PlaceAddressDM(address: $address, latitude: $latitude, longitude: $longitude)';
  }

  @override
  List<Object?> get props => [
        address,
        latitude,
        longitude,
      ];
}

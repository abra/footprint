import 'package:meta/meta.dart';

@immutable
class PlaceAddressModel {
  const PlaceAddressModel({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;

  @override
  String toString() =>
      'PlaceAddressModel(address: $address, latitude: $latitude, longitude: $longitude)';
}

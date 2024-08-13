import 'package:meta/meta.dart';

@immutable
class LocationAddressModel {
  const LocationAddressModel({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;
}
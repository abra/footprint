/// [LocationAddressCM] model for caching
///
/// CM stands for 'Cache Model'
class LocationAddressCM {
  LocationAddressCM({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  final String address;
  final double latitude;
  final double longitude;

  factory LocationAddressCM.fromMap(Map<String, dynamic> map) {
    return LocationAddressCM(
      address: map['address'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
    );
  }
}

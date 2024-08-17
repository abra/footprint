

/// [PlaceAddressCM] model for caching
///
/// CM stands for 'Cache Model'
class PlaceAddressCM {
  PlaceAddressCM({
    required this.id,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.latitudeIdx,
    required this.longitudeIdx,
    required this.usageFrequency,
    required this.timestamp,
  });

  final int id;
  final String address;
  final double latitude;
  final double longitude;
  final int latitudeIdx;
  final int longitudeIdx;
  final int usageFrequency;
  final DateTime timestamp;

  factory PlaceAddressCM.fromMap(Map<String, dynamic> map) {
    return PlaceAddressCM(
      id: map['id'] as int,
      address: map['address'] as String,
      latitude: map['latitude'] as double,
      longitude: map['longitude'] as double,
      latitudeIdx: map['latitude_idx'] as int,
      longitudeIdx: map['longitude_idx'] as int,
      usageFrequency: map['usage_frequency'] as int,
      timestamp: DateTime.parse(map['timestamp'] as String),
    );
  }
}

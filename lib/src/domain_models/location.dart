class Location {
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

  (String, double, double, DateTime) _equality() => (
        id,
        latitude,
        longitude,
        timestamp,
      );

  @override
  bool operator ==(covariant Location other) {
    if (identical(this, other)) return true;
    return other._equality() == _equality();
  }

  @override
  int get hashCode => _equality().hashCode;
}

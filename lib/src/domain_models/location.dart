class Location {
  const Location({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.dateTime,
  });

  final String id;
  final double latitude;
  final double longitude;
  final DateTime dateTime;

  (String, double, double, DateTime) _equality() => (
        id,
        latitude,
        longitude,
        dateTime,
      );

  @override
  bool operator ==(covariant Location other) {
    if (identical(this, other)) return true;
    return other._equality() == _equality();
  }

  @override
  int get hashCode => _equality().hashCode;
}

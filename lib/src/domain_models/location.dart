class Location {
  const Location(
    this.latitude,
    this.longitude,
  );

  final double latitude;
  final double longitude;

  (double, double) _equality() => (latitude, longitude);

  @override
  bool operator ==(covariant Location other) {
    if (identical(this, other)) return true;
    return other._equality() == _equality();
  }

  @override
  int get hashCode => _equality().hashCode;
}

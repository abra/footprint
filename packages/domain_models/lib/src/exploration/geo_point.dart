import 'package:equatable/equatable.dart';
import 'package:latlong2/latlong.dart';

class GeoPoint extends Equatable {
  const GeoPoint(this.latitude, this.longitude);

  factory GeoPoint.fromCoordinates(List<dynamic> coordinates) {
    if (coordinates.length < 2 ||
        coordinates[0] is! num ||
        coordinates[1] is! num) {
      throw const FormatException('Invalid route coordinates.');
    }
    final point = GeoPoint(
      (coordinates[1] as num).toDouble(),
      (coordinates[0] as num).toDouble(),
    );
    if (!point.isValid) {
      throw const FormatException('Invalid route coordinates.');
    }
    return point;
  }

  final double latitude;
  final double longitude;
  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180;
  LatLng get latLng => LatLng(latitude, longitude);
  List<double> get coordinates => [longitude, latitude];
  double distanceTo(GeoPoint other) =>
      const DistanceHaversine(roundResult: false)(latLng, other.latLng);

  @override
  List<Object> get props => [latitude, longitude];
}

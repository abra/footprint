import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/src/mappers/position_to_domain.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test(
    'platform quality measurements survive mapping without guessed zeroes',
    () {
      final measured = Position.fromMap({
        'latitude': 56.0,
        'longitude': 60.0,
        'timestamp': DateTime.utc(2026, 9, 7).millisecondsSinceEpoch,
        'accuracy': 8.0,
        'speed': 0.0,
        'speed_accuracy': 0.2,
      }).toDomainModel();
      expect(measured.accuracy, 8);
      expect(measured.speed, 0);
      expect(measured.speedAccuracy, 0.2);
      expect(measured.reliableSpeed, 0);
      expect(measured.rawLatitude, isNull);
      expect(measured.isStationary, isFalse);
    },
  );

  test('missing or explicitly unavailable measurements remain unknown', () {
    for (final metadata in [
      <String, Object?>{},
      {
        'accuracy': 0.0,
        'speed': 0.0,
        'speed_accuracy': 0.0,
        'has_accuracy': false,
        'has_speed': false,
        'has_speed_accuracy': false,
      },
    ]) {
      final unknown = Position.fromMap({
        'latitude': 56.0,
        'longitude': 60.0,
        ...metadata,
      }).toDomainModel();
      expect(unknown.accuracy, isNull);
      expect(unknown.speed, isNull);
      expect(unknown.speedAccuracy, isNull);
      expect(unknown.reliableSpeed, isNull);
    }
  });
}

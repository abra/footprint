import 'package:domain_models/domain_models.dart';

final gpsEpoch = DateTime.utc(2026, 9, 7);

LocationDM fix(
  int seconds,
  double meters, {
  double north = 0,
  double? accuracy = 5,
  double? speed,
  double? speedAccuracy,
}) => LocationDM(
  id: '$seconds',
  latitude: north / 111195,
  longitude: meters / 111195,
  timestamp: gpsEpoch.add(Duration(seconds: seconds)),
  accuracy: accuracy,
  speed: speed,
  speedAccuracy: speedAccuracy,
);

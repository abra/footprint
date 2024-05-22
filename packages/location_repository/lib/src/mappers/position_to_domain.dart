import 'package:domain_models/domain_models.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

extension PositionToDomain on Position {
  Location toDomainModel() => Location(
        id: const Uuid().v1(),
        timestamp: timestamp,
        latitude: latitude,
        longitude: longitude,
      );
}

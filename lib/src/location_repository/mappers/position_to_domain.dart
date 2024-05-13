import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';

import '../../domain_models/location.dart';

extension PositionToDomain on Position {
  Location toDomainModel() {
    return Location(
      id: const Uuid().v1(),
      timestamp: timestamp,
      latitude: latitude,
      longitude: longitude,
    );
  }
}

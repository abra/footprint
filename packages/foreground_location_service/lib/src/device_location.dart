import 'package:domain_models/domain_models.dart';
import 'package:geolocator/geolocator.dart';

import 'mappers/position_to_domain.dart';

class DeviceLocation {
  Future<void> ensureAvailable() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw LocationServiceDisabledStateException();
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationServicePermanentlyDeniedException();
    }
    if (permission != LocationPermission.always &&
        permission != LocationPermission.whileInUse) {
      throw LocationServicePermissionDeniedException();
    }
  }

  Stream<LocationDM> positions({
    required bool apple,
    required bool background,
  }) => Geolocator.getPositionStream(
    locationSettings: apple
        ? AppleSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
            activityType: ActivityType.fitness,
            pauseLocationUpdatesAutomatically: !background,
            showBackgroundLocationIndicator: background,
            allowBackgroundLocationUpdates: background,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 5,
          ),
  ).map((position) => position.toDomainModel());
}

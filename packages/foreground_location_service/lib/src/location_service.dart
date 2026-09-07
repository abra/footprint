import 'package:domain_models/domain_models.dart';

enum LocationMode { stopped, preview, recording }

abstract interface class LocationService {
  Stream<LocationDM> get locations;
  LocationDM? get lastLocation;

  /// Requests a fresh fix without changing tracking mode or publishing a point.
  Future<LocationDM> currentLocation();
  Future<void> setMode(
    LocationMode mode, {
    bool restart = false,
    LocationDM? initialLocation,
  });
  Future<void> dispose();
}

/// Platform boundary, separate from lifecycle coordination for deterministic tests.
abstract interface class LocationBackend {
  Stream<LocationDM> get locations;
  Future<LocationDM> currentLocation();
  Future<void> start({required bool background, LocationDM? initialLocation});
  Future<void> stop();
  Future<void> dispose();
}

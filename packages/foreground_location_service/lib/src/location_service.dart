import 'package:domain_models/domain_models.dart';

enum LocationMode { stopped, preview, recording }

abstract interface class LocationService {
  Stream<LocationDM> get locations;
  LocationDM? get lastLocation;
  Future<void> setMode(LocationMode mode, {bool restart = false});
  Future<void> dispose();
}

/// Platform boundary, separate from lifecycle coordination for deterministic tests.
abstract interface class LocationBackend {
  Stream<LocationDM> get locations;
  Future<void> start({required bool background});
  Future<void> stop();
  Future<void> dispose();
}

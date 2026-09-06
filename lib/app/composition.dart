import 'dart:developer';

import 'package:footprint/app/dependency_container.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:recording_service/recording_service.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'config/application_config.dart';
import 'resource_disposer.dart';

Future<CompositionResult> composeDependencies({
  ApplicationConfig config = const ApplicationConfig(),
  Future<SqliteStorage> Function() openStorage = SqliteStorage.open,
  LocationService Function()? createLocation,
}) async {
  final stopwatch = Stopwatch()..start();
  log('Initializing dependencies...', name: 'Composition');

  config.validate();
  final dependencies = await createDependenciesContainer(
    config: config,
    openStorage: openStorage,
    createLocation:
        createLocation ??
        () => ForegroundLocationService(
          backend: NativeLocationBackend(recordingCallback: startRecordingTask),
        ),
  );

  stopwatch.stop();
  log(
    'Dependencies initialized in ${stopwatch.elapsedMilliseconds} ms.',
    name: 'Composition',
  );

  return CompositionResult(
    dependencies: dependencies,
    millisecondsSpent: stopwatch.elapsedMilliseconds,
  );
}

Future<DependenciesContainer> createDependenciesContainer({
  required ApplicationConfig config,
  required Future<SqliteStorage> Function() openStorage,
  required LocationService Function() createLocation,
}) async {
  final resources = ResourceDisposer();
  try {
    final sqliteStorage = await openStorage();
    resources.add('database', sqliteStorage.close);
    final locationService = createLocation();
    resources.add('location service', locationService.dispose);
    final routes = RoutesRepository(sqliteStorage: sqliteStorage);
    final geocoding = GeocodingManager(sqliteStorage: sqliteStorage);
    resources.add('geocoding', geocoding.dispose);
    final recording = RecordingService(
      locationService: locationService,
      routesRepository: routes,
    );
    resources.add('recording', recording.dispose);
    await recording.initialize();
    return DependenciesContainer(
      foregroundLocationService: locationService,
      sqliteStorage: sqliteStorage,
      routesRepository: routes,
      geocodingManager: geocoding,
      recordingService: recording,
      config: config,
      resources: resources,
    );
  } on Object {
    await resources.dispose();
    rethrow;
  }
}

final class CompositionResult {
  const CompositionResult({
    required this.dependencies,
    required this.millisecondsSpent,
  });

  final DependenciesContainer dependencies;
  final int millisecondsSpent;
}

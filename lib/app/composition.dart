import 'dart:developer';

import 'package:footprint/app/dependency_container.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

Future<CompositionResult> composeDependencies() async {
  final stopwatch = Stopwatch()..start();
  log('Initializing dependencies...', name: 'Composition');

  final dependencies = await createDependenciesContainer();

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

Future<DependenciesContainer> createDependenciesContainer() async {
  final sqliteStorage = SqliteStorage();
  final foregroundLocationService = ForegroundLocationService();
  final routesRepository = RoutesRepository(sqliteStorage: sqliteStorage);
  final geocodingManager = GeocodingManager(sqliteStorage: sqliteStorage);

  return DependenciesContainer(
    foregroundLocationService: foregroundLocationService,
    sqliteStorage: sqliteStorage,
    routesRepository: routesRepository,
    geocodingManager: geocodingManager,
  );
}

final class CompositionResult {
  const CompositionResult({
    required this.dependencies,
    required this.millisecondsSpent,
  });

  final DependenciesContainer dependencies;
  final int millisecondsSpent;
}

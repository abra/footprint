import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:recording_service/recording_service.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'config/application_config.dart';
import 'resource_disposer.dart';

class DependenciesContainer {
  const DependenciesContainer({
    required this.foregroundLocationService,
    required this.sqliteStorage,
    required this.routesRepository,
    required this.photosRepository,
    required this.geocodingManager,
    required this.recordingService,
    required this.config,
    required this.resources,
  });

  final LocationService foregroundLocationService;
  final SqliteStorage sqliteStorage;
  final RoutesRepository routesRepository;
  final RoutePhotosRepository photosRepository;
  final GeocodingManager geocodingManager;
  final RecordingService recordingService;
  final ApplicationConfig config;
  final ResourceDisposer resources;

  Future<void> dispose() => resources.dispose();
}

base class TestDependenciesContainer implements DependenciesContainer {
  const TestDependenciesContainer();

  @override
  Object noSuchMethod(Invocation invocation) {
    throw UnimplementedError(
      'The test tries to access ${invocation.memberName} dependency, but it '
      'was not provided by the test dependency container.',
    );
  }
}

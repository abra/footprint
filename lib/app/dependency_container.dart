import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class DependenciesContainer {
  const DependenciesContainer({
    required this.foregroundLocationService,
    required this.sqliteStorage,
    required this.routesRepository,
    required this.geocodingManager,
  });

  final ForegroundLocationService foregroundLocationService;
  final SqliteStorage sqliteStorage;
  final RoutesRepository routesRepository;
  final GeocodingManager geocodingManager;
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

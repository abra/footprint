import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class RoutesRepository {
  const RoutesRepository({
    @visibleForTesting SqliteStorage? sqliteStorage,
  }) : _routesStorage = sqliteStorage ?? const SqliteStorage();

  final SqliteStorage _routesStorage;
}

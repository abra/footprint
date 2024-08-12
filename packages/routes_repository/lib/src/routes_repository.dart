import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class RoutesRepository {
  RoutesRepository({
    @visibleForTesting SqliteStorage? sqliteStorage,
  }) : _storage = sqliteStorage ?? SqliteStorage();

  final SqliteStorage _storage;
}

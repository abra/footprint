import 'package:sqlite_storage/sqlite_storage.dart';

class RoutesRepository {
  RoutesRepository({
    SqliteStorage? sqliteStorage,
  }) : _storage = sqliteStorage ?? SqliteStorage();

  final SqliteStorage _storage;
}

import 'package:sqlite_storage/sqlite_storage.dart';

class RoutesRepository {
  RoutesRepository({
    SqliteStorage? sqliteStorage,
  }) : sqliteStorage = sqliteStorage ?? SqliteStorage();

  final SqliteStorage sqliteStorage;
}

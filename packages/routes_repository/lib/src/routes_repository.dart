import 'package:meta/meta.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class RoutesRepository {
  const RoutesRepository({
    @visibleForTesting SqliteStorage? localStorage,
  }) : _localStorage = localStorage ?? const SqliteStorage();

  final SqliteStorage _localStorage;
}

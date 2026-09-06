import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'daos/geocoding_cache_dao.dart';
import 'daos/routes_dao.dart';

/// The composition root owns the connection; features only borrow its DAOs.
class SqliteStorage {
  SqliteStorage._(this._database)
    : routes = RoutesDao(_database),
      geocodingCache = GeocodingCacheDao(_database);

  final Database _database;
  final RoutesDao routes;
  final GeocodingCacheDao geocodingCache;
  Future<void>? _closeFuture;

  static Future<SqliteStorage> open({
    DatabaseFactory? factory,
    String? path,
  }) async {
    final selectedFactory = factory ?? databaseFactory;
    final databasePath =
        path ??
        p.join(await selectedFactory.getDatabasesPath(), 'footprint.db');
    final database = await selectedFactory.openDatabase(
      databasePath,
      options: OpenDatabaseOptions(
        version: 3,
        singleInstance: false,
        onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
        onCreate: DatabaseHelper.create,
        onUpgrade: DatabaseHelper.upgrade,
      ),
    );
    return SqliteStorage._(database);
  }

  Future<void> close() => _closeFuture ??= _database.close();
}

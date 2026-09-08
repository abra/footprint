import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'database_helper.dart';
import 'database_retry.dart';
import 'daos/geocoding_cache_dao.dart';
import 'daos/routes_dao.dart';
import 'daos/route_statistics_dao.dart';
import 'daos/route_photos_dao.dart';
import 'daos/exploration_dao.dart';

/// The composition root owns the connection; features only borrow its DAOs.
class SqliteStorage {
  SqliteStorage._(this._database)
    : routes = RoutesDao(_database),
      statistics = RouteStatisticsDao(_database),
      exploration = ExplorationDao(_database),
      routePhotos = RoutePhotosDao(_database),
      geocodingCache = GeocodingCacheDao(_database);

  final Database _database;
  final RoutesDao routes;
  final RouteStatisticsDao statistics;
  final ExplorationDao exploration;
  final RoutePhotosDao routePhotos;
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
    final database = await retryOnDatabaseBusy(
      () => selectedFactory.openDatabase(
        databasePath,
        options: OpenDatabaseOptions(
          version: 9,
          singleInstance: false,
          onConfigure: (db) async {
            // Native busy waits can block sqflite's shared Android worker and
            // prevent the other connection from committing. Retry in Dart instead.
            await db.rawQuery('PRAGMA busy_timeout = 0');
            await db.setJournalMode('WAL');
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: DatabaseHelper.create,
          onUpgrade: DatabaseHelper.upgrade,
        ),
      ),
    );
    return SqliteStorage._(database);
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    await statistics.close();
    await _database.close();
  }
}

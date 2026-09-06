import 'package:sqflite/sqflite.dart';

import '../database_retry.dart';
import '../models/route_photo.dart';

class RoutePhotosDao {
  const RoutePhotosDao(this._db);
  final Database _db;

  Future<List<RoutePhoto>> getForRoute(int routeId) async => (await _db.query(
    'route_photos',
    where: 'route_id = ?',
    whereArgs: [routeId],
    orderBy: 'captured_at, id',
  )).map(RoutePhoto.fromMap).toList();

  Future<RoutePhoto?> getPending() async {
    final rows = await _db.query('pending_photo');
    return rows.isEmpty ? null : RoutePhoto.fromMap(rows.single);
  }

  Future<void> beginCapture(RoutePhoto photo) =>
      _db.retryTransaction((txn) async {
        final active = await txn.query(
          'routes',
          columns: ['id'],
          where: 'id = ? AND status = ?',
          whereArgs: [photo.routeId, 'active'],
        );
        if (active.isEmpty) {
          throw StateError('Only an active route can capture photos.');
        }
        await txn.insert('pending_photo', {...photo.toMap(), 'slot': 1});
      });

  Future<void> setSource(String id, String path) async {
    final count = await retryOnDatabaseBusy(
      () => _db.update(
        'pending_photo',
        {'source_path': path},
        where: 'id = ?',
        whereArgs: [id],
      ),
    );
    if (count != 1) throw StateError('Photo capture no longer exists.');
  }

  Future<void> finishCapture(RoutePhoto photo) => _db.retryTransaction((
    txn,
  ) async {
    await txn.insert(
      'route_photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.ignore,
    );
    await txn.delete('pending_photo', where: 'id = ?', whereArgs: [photo.id]);
  });

  Future<void> cancelCapture(String id) async {
    await retryOnDatabaseBusy(
      () => _db.delete('pending_photo', where: 'id = ?', whereArgs: [id]),
    );
  }

  Future<void> delete(int routeId, String id) async {
    await retryOnDatabaseBusy(
      () => _db.delete(
        'route_photos',
        where: 'id = ? AND route_id = ?',
        whereArgs: [id, routeId],
      ),
    );
  }

  Future<Set<String>> referencedFiles() => _db.retryTransaction((txn) async {
    final photos = await txn.query('route_photos', columns: ['file_name']);
    final pending = await txn.query('pending_photo', columns: ['file_name']);
    return {
      for (final row in [...photos, ...pending]) row['file_name'] as String,
    };
  });
}

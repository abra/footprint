import 'package:sqflite/sqflite.dart';

import '../models/route.dart';

class RoutesDao {
  const RoutesDao(this._db);

  final Database _db;

  Future<int> create({
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? sourceId,
  }) => _db.transaction((txn) async {
    final active = await txn.query(
      'routes',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['active'],
      limit: 1,
    );
    if (active.isNotEmpty) {
      throw StateError('A route is already being recorded.');
    }
    final id = await txn.insert('routes', {
      'start_time': timestamp.toIso8601String(),
      'status': 'active',
    });
    await txn.insert('route_points', {
      'route_id': id,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'source_id': sourceId,
    });
    return id;
  });

  Future<bool> addPoint({
    required int routeId,
    required double latitude,
    required double longitude,
    required DateTime timestamp,
    String? sourceId,
  }) => _db.transaction((txn) async {
    final active = await txn.query(
      'routes',
      columns: ['id'],
      where: 'id = ? AND status = ?',
      whereArgs: [routeId, 'active'],
      limit: 1,
    );
    if (active.isEmpty) return false;
    if (sourceId != null) {
      final existing = await txn.query(
        'route_points',
        columns: ['id'],
        where: 'route_id = ? AND source_id = ?',
        whereArgs: [routeId, sourceId],
        limit: 1,
      );
      if (existing.isNotEmpty) return false;
    }
    await txn.insert('route_points', {
      'route_id': routeId,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp.toIso8601String(),
      'source_id': sourceId,
    });
    return true;
  });

  Future<Route?> getActive() async {
    final rows = await _db.query(
      'routes',
      columns: ['id'],
      where: 'status = ?',
      whereArgs: ['active'],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : getById(rows.single['id'] as int);
  }

  Future<List<Route>> getAll() async {
    final rows = await _db.query('routes', orderBy: 'start_time DESC, id DESC');
    return rows.map(Route.fromMap).toList(growable: false);
  }

  Future<Route?> getById(int id) async {
    final rows = await _db.query('routes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    final points = await _db.query(
      'route_points',
      where: 'route_id = ?',
      whereArgs: [id],
      orderBy: 'id ASC',
    );
    return Route.fromMap({...rows.single, 'route_points': points});
  }

  Future<void> complete(int id, DateTime endTime) => _db.transaction((
    txn,
  ) async {
    final rows = await txn.query('routes', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) throw StateError('Route $id does not exist.');
    if (rows.single['status'] == 'completed') return;
    final points = await txn.query(
      'route_points',
      columns: ['timestamp'],
      where: 'route_id = ?',
      whereArgs: [id],
      orderBy: 'id DESC',
      limit: 1,
    );
    final lastTime = points.isEmpty
        ? endTime
        : DateTime.parse(points.single['timestamp'] as String);
    final completedAt = lastTime.isAfter(endTime) ? lastTime : endTime;
    await txn.update(
      'routes',
      {'status': 'completed', 'end_time': completedAt.toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  });

  Future<void> delete(int id) => _db.transaction((txn) async {
    await txn.delete('route_points', where: 'route_id = ?', whereArgs: [id]);
    await txn.delete('routes', where: 'id = ?', whereArgs: [id]);
  });
}

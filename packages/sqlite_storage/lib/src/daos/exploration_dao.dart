import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:sqflite/sqflite.dart';

/// The recording transaction owns all writes. Motion rules remain pure domain
/// functions, shared by both isolates; UI reads never award progress.
class ExplorationDao {
  const ExplorationDao(this._db);
  final Database _db;

  static Future<void> createWalk(
    Transaction txn,
    int routeId,
    RoutePlan plan,
  ) async {
    await txn.insert('walks', {
      'route_id': routeId,
      'plan': jsonEncode(plan.toMap()),
    });
    final batch = txn.batch();
    for (final (index, checkpoint) in plan.checkpoints.indexed) {
      batch.insert('walk_checkpoints', {
        'route_id': routeId,
        'ordinal': index,
        'latitude': checkpoint.point.latitude,
        'longitude': checkpoint.point.longitude,
      });
    }
    await batch.commit(noResult: true);
  }

  static Future<void> recordPoint(Transaction txn, int routeId) async {
    final rows = await txn.query(
      'route_points',
      where: 'route_id = ?',
      whereArgs: [routeId],
      orderBy: 'id DESC',
      limit: 2,
    );
    if (rows.length < 2) return;
    LocationDM location(Map<String, Object?> row) => LocationDM.fromMap({
      ...row,
      'id': row['source_id'] ?? 'stored:${row['id']}',
      'is_stationary': row['is_stationary'] == 1,
    });
    final current = location(rows.first);
    final previous = location(rows.last);
    final cell = ExplorationRules.discovered(previous, current);
    if (cell != null) {
      await txn.insert('explored_cells', {
        'cell_id': cell.id,
        'latitude': cell.center.latitude,
        'longitude': cell.center.longitude,
        'first_route_id': routeId,
        'discovered_at': current.timestamp.toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
      // Counts and writes are protected by the same transaction as the fix.
      final inserted =
          Sqflite.firstIntValue(await txn.rawQuery('SELECT changes()')) == 1;
      if (inserted) {
        final count = Sqflite.firstIntValue(
          await txn.rawQuery(
            'SELECT count(*) FROM (SELECT 1 FROM explored_cells LIMIT 100)',
          ),
        )!;
        if (count >= 10) {
          await _award(txn, ExplorationAchievement.tenAreas, current.timestamp);
        }
        if (count >= 100) {
          await _award(
            txn,
            ExplorationAchievement.hundredAreas,
            current.timestamp,
          );
        }
      }
    }
    final checkpoints = await txn.rawQuery(
      '''
      SELECT c.latitude, c.longitude, w.last_reached_at FROM walks w
      JOIN walk_checkpoints c ON c.route_id = w.route_id AND c.ordinal = w.reached
      WHERE w.route_id = ?
    ''',
      [routeId],
    );
    if (checkpoints.isEmpty) return;
    final checkpoint = checkpoints.single;
    final reachedAt = checkpoint['last_reached_at'] as String?;
    if (!ExplorationRules.reaches(
      previous,
      current,
      GeoPoint(
        (checkpoint['latitude'] as num).toDouble(),
        (checkpoint['longitude'] as num).toDouble(),
      ),
      lastReached: reachedAt == null ? null : DateTime.parse(reachedAt),
    )) {
      return;
    }
    await txn.rawUpdate(
      'UPDATE walks SET reached = reached + 1, last_reached_at = ? WHERE route_id = ?',
      [current.timestamp.toIso8601String(), routeId],
    );
  }

  static Future<void> completeWalk(
    Transaction txn,
    int routeId,
    DateTime at,
  ) async {
    final rows = await txn.rawQuery(
      '''
      SELECT route_id FROM walks w WHERE route_id = ? AND reached =
        (SELECT count(*) FROM walk_checkpoints c WHERE c.route_id = w.route_id)
    ''',
      [routeId],
    );
    if (rows.isNotEmpty) {
      await _award(txn, ExplorationAchievement.firstWalk, at);
    }
  }

  static Future<void> _award(
    Transaction txn,
    ExplorationAchievement achievement,
    DateTime at,
  ) async {
    await txn.insert('exploration_achievements', {
      'code': achievement.name,
      'unlocked_at': at.toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  Future<RoutePlan?> getPlan(int routeId) async {
    final rows = await _db.query(
      'walks',
      columns: ['plan'],
      where: 'route_id = ?',
      whereArgs: [routeId],
    );
    return rows.isEmpty
        ? null
        : RoutePlan.fromMap(
            jsonDecode(rows.single['plan'] as String) as Map<String, dynamic>,
          );
  }

  Future<WalkProgress?> getProgress(int routeId, RoutePlan plan) async {
    final rows = await _db.rawQuery(
      '''
      SELECT w.reached, r.status, (SELECT count(*) FROM explored_cells e WHERE e.first_route_id = w.route_id) AS new_cells
      FROM walks w JOIN routes r ON r.id = w.route_id WHERE w.route_id = ?
    ''',
      [routeId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return WalkProgress(
      routeId: routeId,
      plan: plan,
      reached: row['reached'] as int,
      newCells: row['new_cells'] as int,
      recording: row['status'] == 'active',
    );
  }

  Future<ExplorationProfile> getProfile() async {
    final rows = await _db.rawQuery('''
      SELECT (SELECT count(*) FROM explored_cells) AS cells,
        (SELECT count(*) FROM walks w JOIN routes r ON r.id = w.route_id
         WHERE r.status = 'completed' AND w.reached =
          (SELECT count(*) FROM walk_checkpoints c WHERE c.route_id = w.route_id)) AS walks
    ''');
    final awards = await _db.query(
      'exploration_achievements',
      columns: ['code'],
    );
    return ExplorationProfile(
      cells: rows.single['cells'] as int,
      completedWalks: rows.single['walks'] as int,
      achievements: Set.unmodifiable(
        ExplorationAchievement.values.where(
          (a) => awards.any((row) => row['code'] == a.name),
        ),
      ),
    );
  }

  Future<List<ExplorationCell>> getCells({
    required double south,
    required double north,
    required double west,
    required double east,
    int limit = 1500,
  }) async {
    final rows = await _db.query(
      'explored_cells',
      columns: ['cell_id'],
      where:
          'latitude BETWEEN ? AND ? AND ${west <= east ? 'longitude BETWEEN ? AND ?' : '(longitude >= ? OR longitude <= ?)'}',
      whereArgs: [south, north, west, east],
      orderBy: 'discovered_at DESC, cell_id',
      limit: limit,
    );
    return rows
        .map((row) => ExplorationCell.fromId(row['cell_id'] as String))
        .toList();
  }
}

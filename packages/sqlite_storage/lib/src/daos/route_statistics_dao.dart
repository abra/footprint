import 'dart:isolate';

import 'package:domain_models/domain_models.dart';
import 'package:sqflite/sqflite.dart';

import '../database_retry.dart';

/// Lazily caches immutable completed recordings, never an active GPS trace.
class RouteStatisticsDao {
  RouteStatisticsDao(this._db);
  final Database _db;
  Future<List<RecordedRouteSummary>>? _pending;
  bool _closing = false;

  Future<List<RecordedRouteSummary>> getSummaries() {
    if (_closing) return Future.error(StateError('Storage is closing.'));
    return _pending ??= _read().whenComplete(() => _pending = null);
  }

  Future<List<RecordedRouteSummary>> _read() async {
    final missing = await _db.rawQuery('''
      SELECT r.id, r.start_time, r.end_time FROM routes r
      LEFT JOIN route_statistics s ON s.route_id = r.id
      WHERE r.status = 'completed' AND s.route_id IS NULL
      ORDER BY r.id
    ''');
    // Read one trace at a time; geodesic calculations run off the UI isolate.
    // No write transaction is held while reading or calculating old traces.
    for (final route in missing) {
      if (_closing) break;
      final id = route['id'] as int;
      final points = await _db.query(
        'route_points',
        columns: ['latitude', 'longitude', 'timestamp'],
        where: 'route_id = ?',
        whereArgs: [id],
        orderBy: 'id ASC',
      );
      final metrics = await _calculateMetrics(route, points);
      await retryOnDatabaseBusy(
        () => _db.rawInsert(
          '''
          INSERT OR IGNORE INTO route_statistics(route_id, distance, duration_us)
          SELECT id, ?, ? FROM routes WHERE id = ? AND status = 'completed'
        ''',
          [metrics.distance, metrics.durationUs, id],
        ),
      );
    }
    final rows = await _db.rawQuery('''
      SELECT r.id, r.start_time, s.distance, s.duration_us
      FROM routes r JOIN route_statistics s ON s.route_id = r.id
      WHERE r.status = 'completed' ORDER BY r.id
    ''');
    return [
      for (final row in rows)
        RecordedRouteSummary(
          id: row['id'] as int,
          startedAt: DateTime.parse(row['start_time'] as String),
          distance: (row['distance'] as num).toDouble(),
          duration: Duration(microseconds: row['duration_us'] as int),
        ),
    ];
  }

  Future<void> close() async {
    _closing = true;
    try {
      await _pending;
    } on Object {
      // The requesting Cubit receives the failure; disposal still closes SQLite.
    }
  }
}

// Top-level helper keeps the database connection out of the isolate closure.
Future<({double distance, int durationUs})> _calculateMetrics(
  Map<String, Object?> route,
  List<Map<String, Object?>> points,
) => Isolate.run(() {
  final metrics = RouteMetrics.fromLocations(
    points.map(
      (point) => LocationDM(
        id: '',
        latitude: (point['latitude'] as num).toDouble(),
        longitude: (point['longitude'] as num).toDouble(),
        timestamp: DateTime.parse(point['timestamp'] as String),
      ),
    ),
    startedAt: DateTime.parse(route['start_time'] as String),
    endedAt: route['end_time'] == null
        ? null
        : DateTime.parse(route['end_time'] as String),
  );
  return (
    distance: metrics.distance,
    durationUs: metrics.duration.inMicroseconds,
  );
});

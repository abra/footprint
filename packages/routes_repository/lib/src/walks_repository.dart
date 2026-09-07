import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

class WalksRepository {
  WalksRepository({required SqliteStorage storage})
    : _dao = storage.exploration;
  final ExplorationDao _dao;
  int? _cachedRoute;
  RoutePlan? _cachedPlan;

  Future<WalkProgress?> getProgress(int routeId) async {
    final plan = _cachedRoute == routeId
        ? _cachedPlan
        : await _dao.getPlan(routeId);
    _cachedRoute = routeId;
    _cachedPlan = plan;
    return plan == null ? null : _dao.getProgress(routeId, plan);
  }

  Future<ExplorationProfile> getProfile() => _dao.getProfile();
  Future<List<ExplorationCell>> getCells({
    required double south,
    required double north,
    required double west,
    required double east,
  }) => _dao.getCells(south: south, north: north, west: west, east: east);
}

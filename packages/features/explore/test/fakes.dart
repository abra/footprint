import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_planning/route_planning.dart';
import 'package:routes_repository/routes_repository.dart';

import '../../../domain_models/test/walk_fixtures.dart';
export '../../../domain_models/test/walk_fixtures.dart';
export '../../../recording_service/test/fakes.dart';

class FakePlanner implements RoutePlanner {
  @override
  bool available = true;
  Completer<RoutePlan>? pending;
  Object? error;
  int calls = 0;
  int cancellations = 0;
  int disposals = 0;
  @override
  Future<RoutePlan> generateBetween({
    required GeoPoint start,
    required GeoPoint end,
  }) async {
    calls++;
    if (error case final failure?) throw failure;
    return pending?.future ?? pointToPointPlan(start: start, end: end);
  }

  @override
  Future<RoutePlan> generate({
    required GeoPoint start,
    required double distance,
    Set<String> exploredCells = const {},
  }) async {
    calls++;
    if (error case final failure?) throw failure;
    return pending?.future ?? loopPlan(start: start, distance: distance);
  }

  @override
  void cancel() => cancellations++;
  @override
  void dispose() {
    disposals++;
    cancel();
  }
}

class FakeWalks extends Fake implements WalksRepository {
  ExplorationProfile profile = const ExplorationProfile();
  List<ExplorationCell> cells = [];
  Object? failure;
  @override
  Future<ExplorationProfile> getProfile() async {
    if (failure case final error?) throw error;
    return profile;
  }

  @override
  Future<List<ExplorationCell>> getCells({
    required double south,
    required double north,
    required double west,
    required double east,
  }) async {
    if (failure case final error?) throw error;
    return cells;
  }

  @override
  Future<WalkProgress?> getProgress(int routeId) async => null;
}

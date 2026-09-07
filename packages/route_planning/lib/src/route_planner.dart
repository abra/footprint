import 'package:domain_models/domain_models.dart';

abstract interface class RoutePlanner {
  bool get available;
  Future<RoutePlan> generate({
    required GeoPoint start,
    required double distance,
    Set<String> exploredCells = const {},
  });
  Future<RoutePlan> generateBetween({
    required GeoPoint start,
    required GeoPoint end,
  });
  void cancel();
  void dispose();
}

class RoutePlanningException implements Exception {
  const RoutePlanningException(this.message);
  final String message;
  @override
  String toString() => message;
}

class PlanningCancelled implements Exception {
  const PlanningCancelled();
}

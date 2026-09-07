import 'package:equatable/equatable.dart';

import 'route_plan.dart';

class WalkProgress extends Equatable {
  const WalkProgress({
    required this.routeId,
    required this.plan,
    required this.reached,
    required this.newCells,
    required this.recording,
  });

  final int routeId;
  final RoutePlan plan;
  final int reached;
  final int newCells;
  final bool recording;
  bool get completed => reached == plan.checkpoints.length;
  WalkCheckpoint? get next => completed ? null : plan.checkpoints[reached];

  @override
  List<Object> get props => [routeId, plan, reached, newCells, recording];
}

enum ExplorationAchievement {
  firstWalk('First walk', 'Complete a planned walk'),
  tenAreas('Explorer', 'Discover 10 areas'),
  hundredAreas('Pathfinder', 'Discover 100 areas');

  const ExplorationAchievement(this.title, this.description);
  final String title;
  final String description;
}

class ExplorationProfile extends Equatable {
  const ExplorationProfile({
    this.cells = 0,
    this.completedWalks = 0,
    this.achievements = const {},
  });
  final int cells;
  final int completedWalks;
  final Set<ExplorationAchievement> achievements;

  @override
  List<Object> get props => [cells, completedWalks, achievements];
}

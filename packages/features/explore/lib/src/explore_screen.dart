import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_planning/route_planning.dart';
import 'package:routes_repository/routes_repository.dart';

import 'explore_cubit.dart';
import 'explore_view.dart';

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({
    super.key,
    required this.planner,
    required this.walks,
    required this.recording,
    required this.config,
    required this.onBack,
  });
  final RoutePlanner planner;
  final WalksRepository walks;
  final RecordingService recording;
  final MapTileConfig config;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) =>
        ExploreCubit(planner: planner, walks: walks, recording: recording)
          ..initialize(),
    child: ExploreView(config: config, onBack: onBack),
  );
}

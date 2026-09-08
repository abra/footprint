import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

import '../route_details_cubit.dart';
import 'route_timeline_view.dart';

class RouteTimelineScreen extends StatelessWidget {
  const RouteTimelineScreen({
    super.key,
    required this.routeId,
    required this.repository,
    required this.photosRepository,
    required this.onBack,
    this.config = const MapTileConfig(),
  });

  final int routeId;
  final RoutesRepository repository;
  final RoutePhotosRepository photosRepository;
  final VoidCallback onBack;
  final MapTileConfig config;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RouteDetailsCubit(
      repository: repository,
      routeId: routeId,
      photosRepository: photosRepository,
    )..load(),
    child: RouteTimelineView(config: config, onBack: onBack),
  );
}

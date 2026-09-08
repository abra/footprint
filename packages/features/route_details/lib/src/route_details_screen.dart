import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

import 'route_details_cubit.dart';
import 'route_details_view.dart';

class RouteDetailsScreen extends StatelessWidget {
  const RouteDetailsScreen({
    super.key,
    required this.routeId,
    required this.repository,
    required this.photosRepository,
    required this.onClosed,
    this.config = const MapTileConfig(),
    this.justRecorded = false,
    this.walksRepository,
    this.onTimelineRequested,
  });
  final int routeId;
  final RoutesRepository repository;
  final RoutePhotosRepository photosRepository;
  final MapTileConfig config;
  final ValueChanged<bool> onClosed;
  final bool justRecorded;
  final WalksRepository? walksRepository;
  final VoidCallback? onTimelineRequested;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RouteDetailsCubit(
      repository: repository,
      photosRepository: photosRepository,
      routeId: routeId,
      walksRepository: walksRepository,
    )..load(),
    child: RouteDetailsView(
      config: config,
      onClosed: onClosed,
      justRecorded: justRecorded,
      onTimelineRequested: onTimelineRequested,
    ),
  );
}

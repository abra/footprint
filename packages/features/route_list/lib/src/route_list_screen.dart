import 'package:flutter/material.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:route_snapshots/route_snapshots.dart';

import 'route_list_cubit.dart';
import 'route_list_view.dart';
import 'route_thumbnail.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.routesRepository,
    required this.snapshots,
    required this.onPageChangeRequested,
    this.config = const MapTileConfig(),
    this.onRouteRequested,
    this.onStatisticsRequested,
  });

  final RoutesRepository routesRepository;
  final RouteSnapshotRepository snapshots;
  final VoidCallback onPageChangeRequested;
  final MapTileConfig config;
  final Future<void> Function(int)? onRouteRequested;
  final VoidCallback? onStatisticsRequested;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RouteListCubit(
      routesRepository: routesRepository,
      onRouteDeleted: snapshots.removeRoute,
    )..load(),
    child: RouteListView(
      onMapRequested: onPageChangeRequested,
      thumbnailBuilder: (route, onTap) => RouteThumbnail(
        route: route,
        snapshots: snapshots,
        config: config,
        onTap: onTap,
      ),
      onRouteRequested: onRouteRequested,
      onStatisticsRequested: onStatisticsRequested,
    ),
  );
}

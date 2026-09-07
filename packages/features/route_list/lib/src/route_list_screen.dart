import 'package:flutter/material.dart';
import 'package:component_library/component_library.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:routes_repository/routes_repository.dart';

import 'route_list_cubit.dart';
import 'route_list_view.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.routesRepository,
    required this.onPageChangeRequested,
    this.config = const MapTileConfig(),
    this.onRouteRequested,
    this.onStatisticsRequested,
  });

  final RoutesRepository routesRepository;
  final VoidCallback onPageChangeRequested;
  final MapTileConfig config;
  final Future<void> Function(int)? onRouteRequested;
  final VoidCallback? onStatisticsRequested;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => RouteListCubit(routesRepository: routesRepository)..load(),
    child: RouteListView(
      onMapRequested: onPageChangeRequested,
      config: config,
      onRouteRequested: onRouteRequested,
      onStatisticsRequested: onStatisticsRequested,
    ),
  );
}

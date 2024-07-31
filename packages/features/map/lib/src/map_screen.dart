import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location_repository/location_repository.dart';
import 'package:map/src/map_view_notifier.dart';
import 'package:routes_repository/routes_repository.dart';

import 'map_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';
import 'map_view_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.routesRepository,
    required this.onPageChangeRequested,
  });

  final LocationRepository locationRepository;
  final RoutesRepository routesRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapNotifier _mapNotifier;

  @override
  void initState() {
    super.initState();
    _mapNotifier = MapNotifier(
      locationRepository: widget.locationRepository,
      routesRepository: widget.routesRepository,
      viewConfig: const MapViewConfig(),
    );
  }

  @override
  void dispose() {
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapNotifierProvider(
        notifier: _mapNotifier,
        child: MapView(
          onPageChange: widget.onPageChangeRequested,
        ),
      );
}

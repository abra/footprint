import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:location_repository/location_repository.dart';
import 'package:map/src/map_view_notifier.dart';
import 'package:routes_repository/routes_repository.dart';

import 'map_location_notifier.dart';
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
  late MapLocationNotifier _mapLocationNotifier;
  late MapViewNotifier _mapViewNotifier;

  @override
  void initState() {
    super.initState();
    _mapLocationNotifier = MapLocationNotifier(
      locationRepository: widget.locationRepository,
    );
    _mapViewNotifier = MapViewNotifier(
      config: const MapViewConfig(),
    );
  }

  @override
  void dispose() {
    _mapViewNotifier.dispose();
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapNotifierProvider(
        locationNotifier: _mapLocationNotifier,
        viewNotifier: _mapViewNotifier,
        child: MapView(
          onPageChange: widget.onPageChangeRequested,
        ),
      );
}

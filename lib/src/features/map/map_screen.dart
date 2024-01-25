import 'package:flutter/material.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

import 'map_app_bar.dart';
import 'map_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.onGoToRouteList,
  });

  final VoidCallback onGoToRouteList;
  final LocationRepository locationRepository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapNotifier _mapNotifier = MapNotifier(
    locationRepository: widget.locationRepository,
  );

  @override
  void dispose() {
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapNotifierProvider(
      notifier: _mapNotifier,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: MapAppBar(
          onGoToRouteList: widget.onGoToRouteList,
        ),
        body: const MapView(),
      ),
    );
  }
}

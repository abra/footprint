import 'package:flutter/material.dart';
import 'package:location_repository/location_repository.dart';

import 'map_app_bar.dart';
import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';
import 'map_view_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.onPageChangeRequested,
  });

  final LocationRepository locationRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapLocationNotifier _mapLocationNotifier;
  MapViewConfig get _config => const MapViewConfig();

  @override
  void initState() {
    super.initState();
    _mapLocationNotifier = MapLocationNotifier(
      locationRepository: widget.locationRepository,
    );
  }

  @override
  void dispose() {
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapLocationNotifierProvider(
        notifier: _mapLocationNotifier,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: MapAppBar(
            onPageChange: widget.onPageChangeRequested,
          ),
          body: MapView(
            config: _config,
          ),
        ),
      );
}

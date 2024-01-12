import 'package:flutter/material.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

import 'map_app_bar.dart';
import 'map_view.dart';
import 'map_notifier.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.repository,
    required this.onGoToRouteList,
  });

  final LocationRepository repository;
  final VoidCallback onGoToRouteList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: MapAppBar(
        onGoToRouteList: onGoToRouteList,
      ),
      body: MapView(
        mapNotifier: MapNotifier(
          locationRepository: repository,
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

import 'map_app_bar.dart';
import 'map_location_notifier.dart';
import 'map_view.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.onGoToRouteList,
  });

  final LocationRepository locationRepository;
  final VoidCallback onGoToRouteList;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: MapAppBar(
        onGoToRouteList: onGoToRouteList,
      ),
      body: MapView(
        locationNotifier: MapLocationNotifier(
          locationRepository: locationRepository,
        ),
      ),
    );
  }
}

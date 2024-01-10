import 'package:flutter/material.dart';
import 'package:footprint/src/components/page_manager.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

import 'map_screen_notifier.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.repository,
  });

  final LocationRepository repository;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late final MapScreenNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = MapScreenNotifier(
      locationRepository: widget.repository,
    );
    _notifier.updateLocation();
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ValueListenableBuilder<MapScreenState>(
              valueListenable: _notifier,
              builder: (BuildContext context, MapScreenState state, _) {
                // TODO: Improve the code below
                if (state is MapScreenInitial) {
                  return const CircularProgressIndicator();
                } else if (state is MapScreenLocationUpdateSuccess) {
                  return Text(
                    'Timestamp: ${state.location.timestamp}\n'
                    'Latitude: ${state.location.latitude}\n'
                    'Longitude: ${state.location.longitude}',
                  );
                } else if (state is MapScreenLocationUpdateFailure) {
                  return const Text('Error');
                }
                return const Text('Error');
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                PageManager.goToPage(Pages.routeList);
              },
              child: const Text('Go to RouteListScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

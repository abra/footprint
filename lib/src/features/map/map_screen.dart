import 'package:flutter/material.dart';
import 'package:footprint/src/components/page_manager.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required LocationRepository repository,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('MapScreen'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                PageManager.goToPage(PageIndex.routeList);
              },
              child: const Text('Go to RouteListScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';
import 'package:footprint/src/components/page_manager.dart';
import 'package:footprint/src/features/map/map_screen.dart';
import 'package:footprint/src/features/route_list/route_list_screen.dart';
import 'package:footprint/src/location_repository/location_repository.dart';
import 'package:footprint/src/location_repository/location_service.dart';

import 'splash_screen.dart';

class FootprintApp extends StatelessWidget {
  const FootprintApp({super.key});

  final _locationRepository = const LocationRepository(
    locationService: LocationService(
      updateInterval: Duration(seconds: 5),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: Future<void>.delayed(
          const Duration(seconds: 2),
        ),
        builder: (BuildContext ctx, AsyncSnapshot<void> snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: snapshot.connectionState == ConnectionState.done
                ? _HomeScreen(
                    pages: [
                      MapScreen(
                        repository: _locationRepository,
                      ),
                      const RouteListScreen(),
                    ],
                  )
                : const SplashScreen(),
          );
        },
      ),
    );
  }
}

class _HomeScreen extends StatelessWidget {
  const _HomeScreen({
    required this.pages,
  });

  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        allowImplicitScrolling: true,
        physics: const NeverScrollableScrollPhysics(),
        controller: PageManager.pageController,
        children: pages,
      ),
    );
  }
}

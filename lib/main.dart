import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:footprint/src/map/map_screen.dart';
import 'package:footprint/src/route_list/route_list_screen.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const FootprintApp());
    },
    (error, stack) {
      log('ZONED ERROR: $error\n$stack');
    },
  );
}

class FootprintApp extends StatefulWidget {
  const FootprintApp({
    super.key,
  });

  @override
  State<FootprintApp> createState() => FootprintAppState();
}

abstract class _Pages {
  static const int map = 0;
  static const int routeList = 1;
}

class FootprintAppState extends State<FootprintApp> {
  final _locationRepository = const LocationRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: HomeScreen(
        pages: [
          MapScreen(
            locationRepository: _locationRepository,
            onPageChangeRequested: () => _PageManager.goToPage(
              _Pages.routeList,
            ),
          ),
          RouteListScreen(
            onPageChangeRequested: () => _PageManager.goToPage(
              _Pages.map,
            ),
            // onRouteSelected: (routeId) {
            //   MaterialPage(
            //     name: 'route-details',
            //     child: RouteDetailsScreen(
            //       routeId: routeId,
            //       routeRepository: _routeRepository,
            //     ),
            //   );
            // }
          ),
        ],
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.pages,
  });

  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: PageView(
        allowImplicitScrolling: true,
        physics: const NeverScrollableScrollPhysics(),
        controller: _PageManager.pageController,
        children: pages,
      ),
    );
  }
}

/// Page controller for switching between pages at _HomeScreen of FootprintApp
class _PageManager {
  static final PageController _pageController = PageController(
    initialPage: _Pages.map,
  );

  static PageController get pageController => _pageController;

  static void goToPage(int pageIndex) {
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linearToEaseOut,
    );
  }
}

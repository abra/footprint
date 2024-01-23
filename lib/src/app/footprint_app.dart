import 'package:flutter/material.dart';
import 'package:footprint/src/features/map/map_screen.dart';
import 'package:footprint/src/features/route_list/route_list_screen.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

class FootprintApp extends StatelessWidget {
  const FootprintApp({super.key});

  final _locationRepository = const LocationRepository();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _HomeScreen(
        pages: [
          MapScreen(
            locationRepository: _locationRepository,
            onGoToRouteList: () => _PageManager.goToPage(
              _Pages.routeList,
            ),
          ),
          RouteListScreen(
            onGoToMap: () => _PageManager.goToPage(
              _Pages.map,
            ),
          ),
        ],
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

abstract class _Pages {
  static const int map = 0;
  static const int routeList = 1;
}

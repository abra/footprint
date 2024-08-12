import 'dart:async';
import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:location_repository/location_repository.dart';
import 'package:map/map.dart';
import 'package:route_list/route_list.dart';
import 'package:routes_repository/routes_repository.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(FootprintApp());
    },
    (error, stack) {
      log('ZONED ERROR: $error\n$stack');
    },
  );
}

class FootprintApp extends StatelessWidget {
  FootprintApp({
    super.key,
  });

  final LocationRepository _locationRepository = const LocationRepository();
  final RoutesRepository _routesRepository = RoutesRepository();

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomeScreen(
          pages: [
            MapScreen(
              locationRepository: _locationRepository,
              routesRepository: _routesRepository,
              onPageChangeRequested: () => _PageManager.goToPage(
                _Pages.routeList,
              ),
            ),
            RouteListScreen(
              routesRepository: _routesRepository,
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

/// Home screen of FootprintApp
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.pages,
  });

  final List<Widget> pages;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) => Scaffold(
        body: PageView(
          allowImplicitScrolling: true,
          physics: const NeverScrollableScrollPhysics(),
          controller: _PageManager.pageController,
          children: widget.pages,
        ),
      );

  @override
  void dispose() {
    _PageManager.pageController.dispose();
    super.dispose();
  }
}

abstract class _Pages {
  static const int map = 0;
  static const int routeList = 1;
}

/// Page controller for switching between pages at _HomeScreen of FootprintApp
class _PageManager {
  static final PageController _pageController = PageController(
    initialPage: _Pages.map,
  );

  static PageController get pageController => _pageController;

  static Future<void> goToPage(int pageIndex) async {
    await _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linearToEaseOut,
    );
  }
}

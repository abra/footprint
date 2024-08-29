import 'dart:async';
import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:map/map.dart';
import 'package:route_list/route_list.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await ForegroundLocationService.initCommunicationPort();

    runApp(FootprintApp());
  }, (error, stack) {
    log('--- Uncaught error: $error\n$stack');
    // send uncaught error to crashlytics
  });
}

class FootprintApp extends StatelessWidget {
  FootprintApp({
    super.key,
  });

  final _foregroundLocationService = ForegroundLocationService();
  final _routesRepository = RoutesRepository();
  final _sqliteStorage = SqliteStorage();
  late final _geocodingManager = GeocodingManager(
    sqliteStorage: _sqliteStorage,
  );

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: HomeScreen(
          pages: [
            MapScreen(
              locationService: _foregroundLocationService,
              routesRepository: _routesRepository,
              geocodingManager: _geocodingManager,
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

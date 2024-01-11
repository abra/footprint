import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:footprint/src/app/common/constants.dart';
import 'package:footprint/src/features/map/map_screen.dart';
import 'package:footprint/src/features/route_list/route_list_screen.dart';
import 'package:footprint/src/location_repository/location_repository.dart';
import 'package:footprint/src/location_repository/location_service.dart';

abstract class _Pages {
  static const int map = 0;
  static const int routeList = 1;
}

class FootprintApp extends StatelessWidget {
  const FootprintApp({super.key});

  final _locationRepository = const LocationRepository(
    locationService: LocationService(
      timeLimit: Duration(seconds: 15),
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
                        goTo: () => _PageManager.goToPage(_Pages.routeList),
                      ),
                      RouteListScreen(
                        goTo: () => _PageManager.goToPage(_Pages.map),
                      ),
                    ],
                  )
                : const _SplashScreen(),
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
        controller: _PageManager.pageController,
        children: pages,
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: greenColor,
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.6,
            child: SvgPicture.asset(
              svgFile,
              colorFilter: const ColorFilter.mode(
                whiteColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
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

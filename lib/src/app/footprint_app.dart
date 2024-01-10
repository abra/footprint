import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:footprint/src/components/colors.dart';
import 'package:footprint/src/components/constants.dart';
import 'package:footprint/src/components/page_manager.dart';
import 'package:footprint/src/features/map/map_screen.dart';
import 'package:footprint/src/features/route_list/route_list_screen.dart';
import 'package:footprint/src/location_repository/location_repository.dart';
import 'package:footprint/src/location_repository/location_service.dart';

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
        controller: PageManager.pageController,
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

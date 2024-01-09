import 'package:flutter/material.dart';
import 'package:footprint/src/components/home_screen_page_manager.dart';

import 'splash_screen.dart';

class FootprintApp extends StatelessWidget {
  const FootprintApp({super.key});

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
                ? const _HomeScreen(
                    pages: [
                      MapScreen(),
                      RouteListScreen(),
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
        controller: HomeScreenPageManager.pageController,
        children: pages,
        onPageChanged: (int index) {
          // TODO: implement
        },
      ),
    );
  }
}

class MapScreen extends StatelessWidget {
  const MapScreen({super.key});

  final int routeListPageIndex = 1;

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
                HomeScreenPageManager.goToPage(routeListPageIndex);
              },
              child: const Text('Go to RouteListScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({super.key});

  final int mapPageIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('RouteListScreen'),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                HomeScreenPageManager.goToPage(mapPageIndex);
              },
              child: const Text('Go to MapScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

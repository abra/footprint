import 'package:flutter/material.dart';

abstract class Pages {
  static const int map = 0;
  static const int routeList = 1;
}

/// Page controller for switching between pages at _HomeScreen of FootprintApp
///
/// This class should be shared because it is used in multiple places
class PageManager {
  static final PageController _pageController = PageController(
    initialPage: Pages.map,
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

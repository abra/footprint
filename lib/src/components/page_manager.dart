import 'package:flutter/material.dart';

abstract class PageIndex {
  static const int map = 0;
  static const int routeList = 1;
}

class PageManager {
  static final PageController _pageController = PageController(
    initialPage: PageIndex.map,
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

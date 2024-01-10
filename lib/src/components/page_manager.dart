import 'package:flutter/material.dart';

class HomeScreenPageManager {
  static final PageController _pageController = PageController();

  static PageController get pageController => _pageController;

  static void goToPage(int pageIndex) {
    _pageController.animateToPage(
      pageIndex,
      duration: const Duration(milliseconds: 300),
      curve: Curves.linearToEaseOut,
    );
  }
}

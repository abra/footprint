import 'package:flutter/material.dart';
import 'package:footprint/src/components/page_manager.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({super.key});

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
                PageManager.goToPage(PageIndex.map);
              },
              child: const Text('Go to MapScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

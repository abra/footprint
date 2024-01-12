import 'package:flutter/material.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.onGoToMap,
  });

  final VoidCallback onGoToMap;

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
              onPressed: () => onGoToMap(),
              child: const Text('Go to MapScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

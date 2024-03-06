import 'package:flutter/material.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.onPageChangeRequested,
  });

  final VoidCallback onPageChangeRequested;

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
              onPressed: () => onPageChangeRequested(),
              child: const Text('Go to MapScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

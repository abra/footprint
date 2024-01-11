import 'package:flutter/material.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.goTo,
  });

  final VoidCallback goTo;

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
              onPressed: () => goTo(),
              child: const Text('Go to MapScreen'),
            ),
          ],
        ),
      ),
    );
  }
}

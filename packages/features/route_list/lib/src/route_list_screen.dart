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
      appBar: AppBar(
        title: const Text('Route List'),
      ),
      body: Center(
        child: TextButton(
          onPressed: onPageChangeRequested,
          child: const Text('Go to MapScreen'),
        ),
      ),
    );
  }
}

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:routes_repository/routes_repository.dart';

class RouteListScreen extends StatelessWidget {
  const RouteListScreen({
    super.key,
    required this.routesRepository,
    required this.onPageChangeRequested,
  });

  final RoutesRepository routesRepository;
  final VoidCallback onPageChangeRequested;

  @override
  Widget build(BuildContext context) {
    log('build', name: '$this', time: DateTime.now());
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

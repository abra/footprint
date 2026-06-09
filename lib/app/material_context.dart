import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:footprint/app/dependency_scope.dart';
import 'package:footprint/app/routing.dart';
import 'package:go_router/go_router.dart';

class MaterialContext extends StatefulWidget {
  const MaterialContext({super.key});

  @override
  State<MaterialContext> createState() => _MaterialContextState();
}

class _MaterialContextState extends State<MaterialContext> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = buildRouter(dependencies: DependenciesScope.of(context));
  }

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: _router,
      builder: (context, child) {
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: 2,
          child: child!,
        );
      },
    );
  }
}

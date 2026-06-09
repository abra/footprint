import 'package:flutter/widgets.dart';
import 'package:footprint/app/composition.dart';
import 'package:footprint/app/dependency_scope.dart';
import 'package:footprint/app/material_context.dart';

class RootContext extends StatelessWidget {
  const RootContext({
    required this.compositionResult,
    super.key,
  });

  final CompositionResult compositionResult;

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: compositionResult.dependencies,
      child: const MaterialContext(),
    );
  }
}

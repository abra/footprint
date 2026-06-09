import 'package:flutter/widgets.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:footprint/utils/inherited_extension.dart';

class DependenciesScope extends StatelessWidget {
  const DependenciesScope({
    required this.dependencies,
    required this.child,
    super.key,
  });

  final DependenciesContainer dependencies;
  final Widget child;

  static DependenciesContainer of(BuildContext context) =>
      context.inhOf<_DependenciesInherited>(listen: false).dependencies;

  @override
  Widget build(BuildContext context) {
    return _DependenciesInherited(
      dependencies: dependencies,
      child: child,
    );
  }
}

class _DependenciesInherited extends InheritedWidget {
  const _DependenciesInherited({
    required this.dependencies,
    required super.child,
  });

  final DependenciesContainer dependencies;

  @override
  bool updateShouldNotify(_DependenciesInherited oldWidget) =>
      !identical(dependencies, oldWidget.dependencies);
}

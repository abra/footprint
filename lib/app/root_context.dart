import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:footprint/app/composition.dart';
import 'package:footprint/app/dependency_scope.dart';
import 'package:footprint/app/material_context.dart';

class RootContext extends StatefulWidget {
  const RootContext({required this.compositionResult, super.key});

  final CompositionResult compositionResult;

  @override
  State<RootContext> createState() => _RootContextState();
}

class _RootContextState extends State<RootContext> {
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    _onLifecycle(
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed,
    );
  }

  void _onLifecycle(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        unawaited(
          widget.compositionResult.dependencies.recordingService.setForeground(
            true,
          ),
        );
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        unawaited(
          widget.compositionResult.dependencies.recordingService.setForeground(
            false,
          ),
        );
      case AppLifecycleState.inactive:
        break;
    }
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(widget.compositionResult.dependencies.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DependenciesScope(
      dependencies: widget.compositionResult.dependencies,
      child: const MaterialContext(),
    );
  }
}

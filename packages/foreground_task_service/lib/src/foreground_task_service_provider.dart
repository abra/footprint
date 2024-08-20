import 'package:flutter/widgets.dart';

import 'foreground_task_service.dart';

class ForegroundTaskServiceProvider extends InheritedWidget {
  final ForegroundTaskService foregroundTaskService;

  ForegroundTaskServiceProvider({
    required this.foregroundTaskService,
    required super.child,
  });

  static ForegroundTaskService of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<ForegroundTaskServiceProvider>();
    return provider!.foregroundTaskService;
  }

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => false;
}

extension ForegroundTaskServiceProviderExtension on BuildContext {
  ForegroundTaskService get foregroundTaskService =>
      ForegroundTaskServiceProvider.of(this);
}
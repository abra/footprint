import 'package:flutter/widgets.dart';

import 'map_notifier.dart';

class MapNotifierProvider extends InheritedWidget {
  const MapNotifierProvider({
    super.key,
    required this.notifier,
    required super.child,
  });

  final MapNotifier notifier;

  static MapNotifierProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapNotifierProvider>()!;

  @override
  bool updateShouldNotify(MapNotifierProvider oldWidget) => false;
}

import 'package:flutter/widgets.dart';

import 'map_location_notifier.dart';

class MapLocationNotifierProvider extends InheritedWidget {
  const MapLocationNotifierProvider({
    super.key,
    required this.notifier,
    required super.child,
  });

  final MapLocationNotifier notifier;

  static MapLocationNotifierProvider of(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MapLocationNotifierProvider>()!;

  @override
  bool updateShouldNotify(MapLocationNotifierProvider oldWidget) => false;
}

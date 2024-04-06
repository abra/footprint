import 'package:flutter/widgets.dart';

import 'map_location_notifier.dart';

class MapLocationNotifierProvider extends InheritedWidget {
  const MapLocationNotifierProvider({
    super.key,
    required this.locationNotifier,
    required super.child,
  });

  final MapLocationNotifier locationNotifier;

  static MapLocationNotifierProvider of(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<MapLocationNotifierProvider>()!;
  }

  @override
  bool updateShouldNotify(MapLocationNotifierProvider oldWidget) {
    return oldWidget.locationNotifier != locationNotifier;
  }
}

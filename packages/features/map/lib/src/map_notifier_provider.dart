import 'package:flutter/widgets.dart';

import 'map_location_notifier.dart';
import 'map_view_notifier.dart';

class MapNotifierProvider extends InheritedWidget {
  const MapNotifierProvider({
    super.key,
    required this.locationNotifier,
    required this.viewNotifier,
    required super.child,
  });

  final MapLocationNotifier locationNotifier;
  final MapViewNotifier viewNotifier;

  static MapNotifierProvider of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapNotifierProvider>()!;

  @override
  bool updateShouldNotify(MapNotifierProvider oldWidget) => false;
}

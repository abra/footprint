import 'package:flutter/foundation.dart';
import 'package:equatable/equatable.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier() : super(MapViewInitial());
}

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'map_config.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier()
      : super(
          const MapViewUpdated(
            shouldCenterMap: MapConfig.shouldCenterMap,
            zoomStep: MapConfig.zoomStep,
            zoom: MapConfig.defaultZoom,
            maxZoom: MapConfig.maxZoom,
            minZoom: MapConfig.minZoom,
            urlTemplate: MapConfig.urlTemplate,
            fallbackUrl: MapConfig.fallbackUrl,
            userAgentPackageName: MapConfig.userAgentPackageName,
          ),
        );

  void handleCenterMap(bool newValue) async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final newState = currentState.copyWith(
        shouldCenterMap: newValue,
      );
      value = newState;
    }
  }

  void handleZoomedIn() async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final previousZoom = currentState.zoom;
      if (previousZoom + MapConfig.zoomStep <= MapConfig.maxZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom + MapConfig.zoomStep,
        );
        value = newState;
      }
    }
  }

  void handleZoomedOut() async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final previousZoom = currentState.zoom;
      if (previousZoom - MapConfig.zoomStep >= MapConfig.minZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom - MapConfig.zoomStep,
        );
        value = newState;
      }
    }
  }
}

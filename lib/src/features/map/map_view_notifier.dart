import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'map_view_config.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier({
    required this.config,
  }) : super(
          MapViewUpdated(
            shouldCenterMap: config.shouldCenterMap,
            zoomStep: config.zoomStep,
            zoom: config.defaultZoom,
            maxZoom: config.maxZoom,
            minZoom: config.minZoom,
            urlTemplate: config.urlTemplate,
            fallbackUrl: config.fallbackUrl,
            userAgentPackageName: config.userAgentPackageName,
          ),
        );

  final MapViewConfig config;

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
      if (previousZoom + config.zoomStep <= config.maxZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom + config.zoomStep,
        );
        value = newState;
      }
    }
  }

  void handleZoomedOut() async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final previousZoom = currentState.zoom;
      if (previousZoom - config.zoomStep >= config.minZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom - config.zoomStep,
        );
        value = newState;
      }
    }
  }
}

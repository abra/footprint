import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'map_config.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier()
      : super(
          const MapViewUpdated(
            shouldCenterMap: MapConfig.shouldCenterMap,
            zoom: MapConfig.defaultZoom,
            maxZoom: MapConfig.maxZoom,
            minZoom: MapConfig.minZoom,
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

  void handleZoomedIn(double newValue) async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final previousZoom = currentState.zoom;
      if (previousZoom + newValue <= MapConfig.maxZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom + newValue,
        );
        value = newState;
      }
    }
  }

  void handleZoomedOut(double newValue) async {
    final currentState = value;
    if (currentState is MapViewUpdated) {
      final previousZoom = currentState.zoom;
      if (previousZoom - newValue >= MapConfig.minZoom) {
        final newState = currentState.copyWith(
          zoom: previousZoom - newValue,
        );
        value = newState;
      }
    }
  }
}

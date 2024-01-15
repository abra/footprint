import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier({
    required this.shouldCenter,
    required this.zoom,
    required this.maxZoom,
    required this.minZoom,
  }) : super(
          MapViewUpdated(
            shouldCenter: shouldCenter,
            zoom: zoom,
            maxZoom: maxZoom,
            minZoom: minZoom,
          ),
        );

  final bool shouldCenter;
  final double zoom;
  final double maxZoom;
  final double minZoom;

  void onCenterMapChanged(bool newValue) {
    final currentState = value as MapViewUpdated;
    final newState = currentState.copyWith(
      shouldCenter: newValue,
    );
    value = newState;
  }

  void onZoomIn(double newValue) {
    final currentState = value as MapViewUpdated;
    final previousZoom = currentState.zoom;
    if (previousZoom + newValue <= maxZoom) {
      final newState = currentState.copyWith(
        zoom: previousZoom + newValue,
      );
      value = newState;
    }
  }

  void onZoomOut(double newValue) {
    final currentState = value as MapViewUpdated;
    final previousZoom = currentState.zoom;
    if (previousZoom - newValue >= minZoom) {
      final newState = currentState.copyWith(
        zoom: previousZoom - newValue,
      );
      value = newState;
    }
  }
}
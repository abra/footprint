import 'dart:developer';

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

  Future<void> centerMap(bool newValue) async {
    value = (value as MapViewUpdated).copyWith(
      shouldCenterMap: newValue,
    );
  }

  Future<void> zoomIn() async {
    final currentState = (value as MapViewUpdated);
    final previousZoom = currentState.zoom;
    if (previousZoom + config.zoomStep <= config.maxZoom) {
      final newState = currentState.copyWith(
        zoom: previousZoom + config.zoomStep,
      );
      value = newState;
    }
  }

  Future<void> zoomOut() async {
    final currentState = (value as MapViewUpdated);
    final previousZoom = currentState.zoom;
    if (previousZoom - config.zoomStep >= config.minZoom) {
      final newState = currentState.copyWith(
        zoom: previousZoom - config.zoomStep,
      );
      value = newState;
    }
  }

  @override
  void dispose() {
    log('--- $this [$hashCode]: dispose');
    super.dispose();
  }
}

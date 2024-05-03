import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'map_view_config.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier({
    required this.config,
  }) : super(
          MapViewState(
            isCentered: config.isCentered,
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
    value = switch (value) {
      MapViewState(isCentered: final prevValue) =>
        prevValue != newValue ? value.copyWith(isCentered: newValue) : value,
    };
  }

  Future<void> zoomIn() async {
    value = switch (value) {
      MapViewState(zoom: final prevZoom) =>
        prevZoom + config.zoomStep < config.maxZoom
            ? value.copyWith(zoom: prevZoom + config.zoomStep)
            : value,
    };
  }

  Future<void> zoomOut() async {
    value = switch (value) {
      MapViewState(zoom: final prevZoom) =>
        prevZoom - config.zoomStep > config.minZoom
            ? value.copyWith(zoom: prevZoom - config.zoomStep)
            : value,
    };
  }

  @override
  void dispose() {
    log('--- $this [$hashCode]: dispose');
    super.dispose();
  }
}

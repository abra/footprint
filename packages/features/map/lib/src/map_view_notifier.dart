import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';

import 'map_view_config.dart';

part 'map_view_state.dart';

class MapViewNotifier extends ValueNotifier<MapViewState> {
  MapViewNotifier({
    required this.config,
  }) : super(
          MapViewState(
            markerSize: config.markerSize,
            maxMarkerSize: config.maxMarkerSize,
            minMarkerSize: config.minMarkerSize,
            polylineStrokeWidth: config.polylineStrokeWidth,
            polylineStrokeMinWidth: config.polylineStrokeMinWidth,
            polylineStrokeMaxWidth: config.polylineStrokeMaxWidth,
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

  Future<void> changePolylineStrokeWidth(double zoom) async {
    final double newPolylineStrokeWidth = config.polylineStrokeMinWidth +
        (zoom - config.minZoom) *
            (config.polylineStrokeMaxWidth - config.polylineStrokeMinWidth) /
            (config.maxZoom - config.minZoom);

    value = switch (value) {
      MapViewState(polylineStrokeWidth: final prevPolylineStrokeWidth) =>
        prevPolylineStrokeWidth != newPolylineStrokeWidth
            ? value.copyWith(polylineStrokeWidth: newPolylineStrokeWidth)
            : value,
    };
  }

  Future<void> changeMarkerSize(double zoom) async {
    final double newMarkerSize = config.minMarkerSize +
        (zoom - config.minZoom) *
            (config.maxMarkerSize - config.minMarkerSize) /
            (config.maxZoom - config.minZoom);

    value = switch (value) {
      MapViewState(markerSize: final prevMarkerSize) =>
        prevMarkerSize != newMarkerSize
            ? value.copyWith(markerSize: newMarkerSize)
            : value,
    };
  }

  Future<void> centerMap(bool newValue) async {
    value = switch (value) {
      MapViewState(isCentered: final prevValue) =>
        prevValue != newValue ? value.copyWith(isCentered: newValue) : value,
    };
  }

  Future<void> zoomIn() async {
    value = switch (value) {
      MapViewState(zoom: final prevZoom) =>
        prevZoom + config.zoomStep <= config.maxZoom
            ? value.copyWith(zoom: prevZoom + config.zoomStep)
            : value,
    };
  }

  Future<void> zoomOut() async {
    value = switch (value) {
      MapViewState(zoom: final prevZoom) =>
        prevZoom - config.zoomStep >= config.minZoom
            ? value.copyWith(zoom: prevZoom - config.zoomStep)
            : value,
    };
  }
}

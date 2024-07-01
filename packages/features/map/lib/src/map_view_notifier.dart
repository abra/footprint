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
    await _updateMapParameter(
      zoom: zoom,
      minValue: config.polylineStrokeMinWidth,
      maxValue: config.polylineStrokeMaxWidth,
      getCurrentValue: (state) => state.polylineStrokeWidth,
      updateState: (state, newValue) =>
          state.copyWith(polylineStrokeWidth: newValue),
    );
  }

  Future<void> changeMarkerSize(double zoom) async {
    await _updateMapParameter(
      zoom: zoom,
      minValue: config.minMarkerSize,
      maxValue: config.maxMarkerSize,
      getCurrentValue: (state) => state.markerSize,
      updateState: (state, newValue) => state.copyWith(markerSize: newValue),
    );
  }

  Future<void> _updateMapParameter({
    required double zoom,
    required double minValue,
    required double maxValue,
    required double Function(MapViewState) getCurrentValue,
    required MapViewState Function(MapViewState, double) updateState,
  }) async {
    final double newValue = _interpolateValue(
      zoom: zoom,
      minValue: minValue,
      maxValue: maxValue,
    );

    value = switch (value) {
      MapViewState() when getCurrentValue(value) != newValue =>
        updateState(value, newValue),
      _ => value,
    };
  }

  double _interpolateValue({
    required double zoom,
    required double minValue,
    required double maxValue,
  }) {
    return minValue +
        (zoom - config.minZoom) *
            (maxValue - minValue) /
            (config.maxZoom - config.minZoom);
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

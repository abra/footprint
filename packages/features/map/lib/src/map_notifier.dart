import 'dart:async';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_repository/location_repository.dart';
import 'package:map/src/extensions.dart';
import 'package:routes_repository/routes_repository.dart';

import 'map_view_config.dart';

part 'map_state.dart';

class MapNotifier extends ValueNotifier<MapState> {
  MapNotifier({
    required LocationRepository locationRepository,
    required RoutesRepository routesRepository,
    required MapViewConfig viewConfig,
  })  : _locationRepository = locationRepository,
        _routesRepository = routesRepository,
        _viewConfig = viewConfig,
        super(
          MapInitialLocationLoading(),
        ) {
    _init();
  }

  final LocationRepository _locationRepository;
  final RoutesRepository _routesRepository;
  final MapViewConfig _viewConfig;
  StreamSubscription<Location>? _locationUpdateSubscription;
  bool routeRecordingStarted = false;

  // TODO: Temp for testing
  List<LatLng> _routePoints = [];

  MapViewConfig get viewConfig => _viewConfig;

  Future<void> reInit() async {
    value = MapInitialLocationLoading();
    await _init();
  }

  Future<void> _init() async {
    final bool isSubscribedButPaused = _locationUpdateSubscription != null &&
        _locationUpdateSubscription!.isPaused;

    try {
      await _locationRepository.ensureLocationServiceEnabled();
      await _locationRepository.ensurePermissionGranted();

      if (_locationUpdateSubscription == null) {
        await _startLocationUpdate();
      } else if (isSubscribedButPaused) {
        _locationUpdateSubscription?.resume();
      }
    } catch (e) {
      value = MapLocationUpdateFailure(error: e);
    }
  }

  // TODO: Колбеки будут передаваться в MapView для MapNotifier
  // TODO: Например animation
  //     _animatedMapController.animateTo(
  //       dest: location,
  //     );

  Future<void> _startLocationUpdate() async {
    final Stream<Location> stream = _locationRepository.locationUpdateStream();

    _locationUpdateSubscription = stream.listen((Location location) {
      log('--- Location [$hashCode]: $location');
      if (routeRecordingStarted) {
        _routePoints.add(location.toLatLng());
        value = MapRouteRecordingStarted(
          location: location,
          routePoints: _routePoints,
        );
      } else {
        value = MapLocationUpdateSuccess(location: location);
      }
    }, onError: (dynamic error) {
      // TODO: Add error handling for another exceptions
      if (error is ServiceDisabledException) {
        value = MapLocationUpdateFailure(error: error);
        _locationUpdateSubscription?.cancel();
        _locationUpdateSubscription = null;
      }
    });
  }

  Future<void> startRouteRecording() async {
    if (value is MapLocationUpdateSuccess) {
      final location = (value as MapLocationUpdateSuccess).location;
      _routePoints = [];
      value = MapRouteRecordingStarted(
        location: location,
        routePoints: _routePoints,
      );
      routeRecordingStarted = true;
    }
  }

  Future<void> stopRouteRecording() async {
    // TODO: Add route in routes repository before stop recording
    if (value is MapRouteRecordingStarted) {
      value = MapLocationUpdateSuccess(
        location: (value as MapRouteRecordingStarted).location,
      );
      routeRecordingStarted = false;
    }
  }

  Future<void> zoomIn(double currentZoom, Function(double) callback) async {
    final double zoom = currentZoom + _viewConfig.zoomStep;
    if (zoom <= _viewConfig.maxZoom) {
      callback(zoom);
    }
  }

  Future<void> zoomOut(double currentZoom, Function(double) callback) async {
    final double zoom = currentZoom - _viewConfig.zoomStep;
    if (zoom >= _viewConfig.minZoom) {
      callback(zoom);
    }
  }

  Future<void> centerMap(Function() callback) async {
    //
  }

  void changeMarkerSize(double zoom) {

  }

  // Future<void> changePolylineStrokeWidth(double zoom) async {
  //   await _updateMapParameter(
  //     zoom: zoom,
  //     minValue: config.polylineStrokeMinWidth,
  //     maxValue: config.polylineStrokeMaxWidth,
  //     getCurrentValue: (state) => state.polylineStrokeWidth,
  //     updateState: (state, newValue) =>
  //         state.copyWith(polylineStrokeWidth: newValue),
  //   );
  // }
  //
  // Future<void> changeMarkerSize(double zoom) async {
  //   await _updateMapParameter(
  //     zoom: zoom,
  //     minValue: config.markerMinSize,
  //     maxValue: config.markerMaxSize,
  //     getCurrentValue: (state) => state.markerSize,
  //     updateState: (state, newValue) => state.copyWith(markerSize: newValue),
  //   );
  // }
  //
  // Future<void> _updateMapParameter({
  //   required double zoom,
  //   required double minValue,
  //   required double maxValue,
  //   required double Function(MapViewState) getCurrentValue,
  //   required MapViewState Function(MapViewState, double) updateState,
  // }) async {
  //   final double newValue = _interpolateValue(
  //     zoom: zoom,
  //     minValue: minValue,
  //     maxValue: maxValue,
  //   );
  //
  //   value = switch (value) {
  //     MapViewState() when getCurrentValue(value) != newValue =>
  //         updateState(value, newValue),
  //     _ => value,
  //   };
  // }
  //
  // double _interpolateValue({
  //   required double zoom,
  //   required double minValue,
  //   required double maxValue,
  // }) {
  //   return minValue +
  //       (zoom - config.minZoom) *
  //           (maxValue - minValue) /
  //           (config.maxZoom - config.minZoom);
  // }

  @override
  void dispose() {
    log('--- $this [$hashCode]: dispose');
    _locationUpdateSubscription?.cancel();
    super.dispose();
  }
}

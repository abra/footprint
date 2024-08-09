import 'dart:async';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_repository/location_repository.dart';
import 'package:routes_repository/routes_repository.dart';

import 'extensions.dart';
import 'map_view_config.dart';

class MapNotifier {
  MapNotifier({
    required LocationRepository locationRepository,
    required RoutesRepository routesRepository,
    required MapViewConfig viewConfig,
  })  : _locationRepository = locationRepository,
        _routesRepository = routesRepository,
        _config = viewConfig {
    _init();
  }

  final LocationRepository _locationRepository;
  final RoutesRepository _routesRepository;
  final MapViewConfig _config;

  MapViewConfig get viewConfig => _config;

  late StreamSubscription<Location> _locationUpdateSubscription;

  // map location update notifier
  late final locationState = ValueNotifier<LocationState>(LocationLoading());

  // map route recording notifiers
  final isRouteRecordingActive = ValueNotifier<bool>(false);
  final routePoints = ValueNotifier<List<LatLng>>([]);

  // map view notifiers
  late final currentZoomLevel = ValueNotifier<double>(_config.defaultZoom);
  late final currentMarkerSize = ValueNotifier<double>(_config.markerSize);
  late final currentPolylineWidth = ValueNotifier<double>(_config.polylineWidth);
  late final isMapCentered = ValueNotifier<bool>(_config.mapCentered);

  void Function(double)? onZoomChanged;
  void Function(Location)? onMapCentered;

  void dispose() {
    _locationUpdateSubscription.cancel();
  }

  Future<void> reInit() async {
    locationState.value = LocationLoading();
    await _init();
  }

  Future<void> _init() async {
    try {
      await _locationRepository.ensureLocationServiceEnabled();
      await _locationRepository.ensurePermissionGranted();
      await _startLocationUpdate();
    } catch (e) {
      locationState.value = LocationUpdateFailure(error: e);
    }
  }

  Future<void> _startLocationUpdate() async {
    final Stream<Location> stream = _locationRepository.locationUpdateStream();

    _locationUpdateSubscription = stream.listen((Location location) {
      log('--- Location [$hashCode]: $location');
      locationState.value = LocationUpdateSuccess(location: location);

      // Center the map on the current location
      if (isMapCentered.value && onMapCentered != null) {
        onMapCentered!(location);
      }

      // Start route recording
      if (isRouteRecordingActive.value) {
        // TODO: Replace with routeRepository
        // TODO: _routesRepository.addRoutePoint(location.toLatLng());
        routePoints.value = [
          ...routePoints.value,
          location.toLatLng(),
        ];
      }
    }, onError: (dynamic error) {
      // TODO: Add error handling for another exceptions
      if (error is ServiceDisabledException) {
        locationState.value = LocationUpdateFailure(error: error);
        _locationUpdateSubscription.cancel();
      } else {
        log('Location update error: $error');
        locationState.value = LocationUpdateFailure(error: error);
      }
    });
  }

  Future<void> startRouteRecording() async {
    if (!isRouteRecordingActive.value &&
        locationState.value is LocationUpdateSuccess) {
      routePoints.value = [];
      final location = (locationState.value as LocationUpdateSuccess).location;
      // TODO: Replace with await _routesRepository.startNewRoute();
      routePoints.value = [location.toLatLng()];
      isRouteRecordingActive.value = true;
    }
  }

  Future<void> stopRouteRecording() async {
    // TODO: Replace with proper handling for routeRepository
    if (isRouteRecordingActive.value) {
      // await _routesRepository.finishCurrentRoute();
      routePoints.value = [];
      isRouteRecordingActive.value = false;
    }
  }

  Future<void> zoomIn() =>
      _updateZoom(currentZoomLevel.value + _config.zoomStep, onZoomChanged ?? (_) {});

  Future<void> zoomOut() =>
      _updateZoom(currentZoomLevel.value - _config.zoomStep, onZoomChanged ?? (_) {});

  Future<void> _updateZoom(double newZoom, Function(double) callback) async {
    if (newZoom >= _config.minZoom && newZoom <= _config.maxZoom) {
      currentZoomLevel.value = newZoom;
      callback(currentZoomLevel.value);
      await _updateMarkerSize(currentZoomLevel.value);
      await _updatePolylineWidth(currentZoomLevel.value);
    }
  }

  Future<void> toggleMapCenter(bool value) async {
    if (onMapCentered != null) {
      isMapCentered.value = value;
      if (value) {
        final location =
            (locationState.value as LocationUpdateSuccess).location;
        onMapCentered!(location);
      }
    }
  }

  Future<void> _updatePolylineWidth(double zoom) async {
    currentPolylineWidth.value = await _calculateMapParameter(
      zoom: zoom,
      minValue: _config.polylineMinWidth,
      maxValue: _config.polylineMaxWidth,
    );
  }

  Future<void> _updateMarkerSize(double zoom) async {
    currentMarkerSize.value = await _calculateMapParameter(
      zoom: zoom,
      minValue: _config.markerMinSize,
      maxValue: _config.markerMaxSize,
    );
  }

  Future<double> _calculateMapParameter({
    required double zoom,
    required double minValue,
    required double maxValue,
  }) async {
    return minValue +
        (zoom - _config.minZoom) *
            (maxValue - minValue) /
            (_config.maxZoom - _config.minZoom);
  }
}

sealed class LocationState extends Equatable {
  const LocationState();
}

class LocationLoading extends LocationState {
  @override
  List<Object?> get props => [];
}

class LocationUpdateSuccess extends LocationState {
  const LocationUpdateSuccess({
    required this.location,
    this.locationUpdateError,
  });

  final Location location;
  final dynamic locationUpdateError;

  @override
  List<Object?> get props => [
        location,
        locationUpdateError,
      ];
}

class LocationUpdateFailure extends LocationState {
  const LocationUpdateFailure({
    required this.error,
  }) : errorMessage = '$error';

  final dynamic error;
  final String errorMessage;

  @override
  List<Object?> get props => [
        error,
        errorMessage,
      ];
}

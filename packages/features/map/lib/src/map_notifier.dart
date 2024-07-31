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
import 'map_config.dart';

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

  ValueNotifier<MapState> locationState = ValueNotifier<MapState>(
    MapInitialLocationLoading(),
  );

  ValueNotifier<bool> routeRecordingStarted = ValueNotifier<bool>(false);

  ValueNotifier<List<LatLng>> routePoints = ValueNotifier<List<LatLng>>([]);

  MapViewConfig get viewConfig => _viewConfig;

  late ValueNotifier<double> zoom = ValueNotifier<double>(
    _viewConfig.defaultZoom,
  );

  late ValueNotifier<double> markerSize = ValueNotifier<double>(
    _viewConfig.markerSize,
  );

  late ValueNotifier<double> polylineWidth = ValueNotifier<double>(
    _viewConfig.polylineWidth,
  );

  late ValueNotifier<bool> isCentered = ValueNotifier<bool>(
    _viewConfig.isCentered,
  );

  String get urlTemplate => _viewConfig.urlTemplate;

  String get fallbackUrl => _viewConfig.fallbackUrl;

  String get userAgentPackageName => _viewConfig.userAgentPackageName;

  double get maxZoom => _viewConfig.maxZoom;

  double get minZoom => _viewConfig.minZoom;

  double get defaultZoom => _viewConfig.defaultZoom;

  void Function(LatLng)? onMapLocationChanged;

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

  Future<void> _startLocationUpdate() async {
    final Stream<Location> stream = _locationRepository.locationUpdateStream();

    _locationUpdateSubscription = stream.listen((Location location) {
      log('--- Location [$hashCode]: $location');
      value = MapLocationUpdateSuccess(location: location);

      /// Center the map on the current location
      if (isCentered.value && onMapLocationChanged != null) {
        onMapLocationChanged!(location.toLatLng());
      }

      /// Start route recording
      if (routeRecordingStarted.value) {
        // TODO: Replace with routeRepository
        routePoints.value.add(location.toLatLng());
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

  Future<void> centerMap(Function(bool) callback) async {
    //
  }

  Future<void> startRouteRecording() async {
    if (!routeRecordingStarted.value && value is MapLocationUpdateSuccess) {
      routePoints.value = [];
      final location = (value as MapLocationUpdateSuccess).location;
      routePoints.value.add(location.toLatLng());
      routeRecordingStarted.value = true;
    }
  }

  Future<void> stopRouteRecording() async {
    // TODO: Replace with proper handling for routeRepository
    if (routeRecordingStarted.value) {
      routePoints.value = [];
      routeRecordingStarted.value = false;
    }
  }

  Future<void> zoomIn(Function(double) callback) async {
    if (zoom.value + _viewConfig.zoomStep <= _viewConfig.maxZoom) {
      zoom.value = zoom.value + _viewConfig.zoomStep;
      callback(zoom.value);
      updateMarkerSize(zoom.value);
      updatePolylineWidth(zoom.value);
    }
  }

  Future<void> zoomOut(Function(double) callback) async {
    if (zoom.value - _viewConfig.zoomStep >= _viewConfig.minZoom) {
      zoom.value = zoom.value - _viewConfig.zoomStep;
      callback(zoom.value);
      updateMarkerSize(zoom.value);
      updatePolylineWidth(zoom.value);
    }
  }

  Future<void> updatePolylineWidth(double zoom) async {
    polylineWidth.value = await _updateMapParameter(
      zoom: zoom,
      minValue: _viewConfig.polylineMinWidth,
      maxValue: _viewConfig.polylineMaxWidth,
    );
  }

  Future<void> updateMarkerSize(double zoom) async {
    markerSize.value = await _updateMapParameter(
      zoom: zoom,
      minValue: _viewConfig.markerMinSize,
      maxValue: _viewConfig.markerMaxSize,
    );
  }

  Future<double> _updateMapParameter({
    required double zoom,
    required double minValue,
    required double maxValue,
  }) async {
    final double newValue = _interpolateValue(
      zoom: zoom,
      minValue: minValue,
      maxValue: maxValue,
    );

    return newValue;
  }

  double _interpolateValue({
    required double zoom,
    required double minValue,
    required double maxValue,
  }) {
    return minValue +
        (zoom - _viewConfig.minZoom) *
            (maxValue - minValue) /
            (_viewConfig.maxZoom - _viewConfig.minZoom);
  }

  @override
  void dispose() {
    log('--- $this [$hashCode]: dispose');
    _locationUpdateSubscription?.cancel();
    super.dispose();
  }
}

sealed class MapState extends Equatable {
  const MapState();
}

class MapInitialLocationLoading extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapState {
  const MapLocationUpdateSuccess({
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

class MapLocationUpdateFailure extends MapState {
  const MapLocationUpdateFailure({
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

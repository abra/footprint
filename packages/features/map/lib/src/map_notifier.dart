import 'dart:async';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:latlong2/latlong.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'extensions.dart';

part 'map_state.dart';

class MapNotifier {
  MapNotifier({
    required ForegroundLocationService locationService,
    required RoutesRepository routesRepository,
    required GeocodingManager geocodingManager,
    required Config viewConfig,
  })  : _foregroundLocationService = locationService,
        _routesRepository = routesRepository,
        _geocodingManager = geocodingManager,
        _config = viewConfig {
    log('init $hashCode', name: 'MapNotifier', time: DateTime.now());
  }

  final ForegroundLocationService _foregroundLocationService;
  final RoutesRepository _routesRepository;
  final GeocodingManager _geocodingManager;
  final Config _config;

  // map view config
  Config get viewConfig => _config;

  // map location update notifier
  late final locationState = ValueNotifier<LocationState>(LocationLoading());

  // map route recording notifiers
  final isRouteRecordingActive = ValueNotifier<bool>(false);
  final routePoints = ValueNotifier<List<LatLng>>([]);

  // map address retrieval notifier
  final placeAddress = ValueNotifier<PlaceAddressState>(PlaceAddressLoading());

  // map view notifiers
  late final zoomLevel = ValueNotifier<double>(_config.defaultZoom);
  late final markerSize = ValueNotifier<double>(_config.markerSize);
  late final polylineWidth = ValueNotifier<double>(_config.polylineWidth);
  late final isMapCentered = ValueNotifier<bool>(_config.mapCentered);
  final Map<double, double> _polylineWidthCache = {};
  final Map<double, double> _markerSizeCache = {};

  // map view callbacks
  void Function(double)? onZoomChanged;
  void Function(LocationDM)? onMapCentered;

  void init() async {
    log('init', name: '$this', time: DateTime.now());
    _foregroundLocationService.onLocationUpdated = _handleLocationUpdate;

    _foregroundLocationService.onLocationUpdateError = _handleLocationError;
  }

  void _handleLocationUpdate(LocationDM location) {
    log('_handleLocationUpdate', name: '$runtimeType', time: DateTime.now());
    locationState.value = LocationUpdateSuccess(location: location);

    onPlaceAddressUpdate.call(location);

    // Center the map on the current location
    if (isMapCentered.value && onMapCentered != null) {
      onMapCentered!.call(location);
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
  }

  void _handleLocationError(Exception exception) {
    log('_handleLocationError', name: '$runtimeType', time: DateTime.now());
    locationState.value = LocationUpdateFailure(error: exception);
  }

  void dispose() {
    log('dispose', name: '$runtimeType', time: DateTime.now());
    locationState.dispose();
    isRouteRecordingActive.dispose();
    routePoints.dispose();
    placeAddress.dispose();
    zoomLevel.dispose();
    markerSize.dispose();
    polylineWidth.dispose();
    isMapCentered.dispose();
    _geocodingManager.closeCacheStorage();
    _foregroundLocationService.dispose();
    _foregroundLocationService.onLocationUpdated = null;
    _foregroundLocationService.onLocationUpdateError = null;
    onZoomChanged = null;
    onMapCentered = null;
  }

  Future<void> _placeAddressUpdate(LocationDM location) async {
    log('_placeAddressUpdate', name: '$runtimeType', time: DateTime.now());
    try {
      final placeAddressModel =
          await _geocodingManager.getAddressFromCoordinates(location);
      if (placeAddressModel != null) {
        placeAddress.value = PlaceAddressSuccess(
          address: placeAddressModel.address,
        );
      }
    } on CouldNotGetPlaceAddressException catch (e) {
      log(
        'Could not get location address: $e',
        name: 'MapNotifier',
        time: DateTime.now(),
      );
      placeAddress.value = PlaceAddressFailure(error: e);
    }
  }

  Function(LocationDM) get onPlaceAddressUpdate => _placeAddressUpdate;

  Future<void> startRouteRecording() async {
    log('startRouteRecording', name: '$runtimeType', time: DateTime.now());
    if (!isRouteRecordingActive.value &&
        locationState.value is LocationUpdateSuccess) {
      final location = (locationState.value as LocationUpdateSuccess).location;
      routePoints.value = [];
      // TODO: Replace with await _routesRepository.startNewRoute();
      routePoints.value = [location.toLatLng()];
      isRouteRecordingActive.value = true;
    }
  }

  Future<void> stopRouteRecording() async {
    log('stopRouteRecording', name: '$runtimeType', time: DateTime.now());
    // TODO: Replace with proper handling for routeRepository
    if (isRouteRecordingActive.value) {
      // await _routesRepository.finishCurrentRoute();
      routePoints.value = [];
      isRouteRecordingActive.value = false;
    }
  }

  Future<void> zoomIn() => _updateZoom(
        zoomLevel.value + _config.zoomStep,
        onZoomChanged ?? (_) {},
      );

  Future<void> zoomOut() => _updateZoom(
        zoomLevel.value - _config.zoomStep,
        onZoomChanged ?? (_) {},
      );

  Future<void> _updateZoom(double newZoom, Function(double) callback) async {
    log('_updateZoom', name: '$runtimeType', time: DateTime.now());
    if (newZoom >= _config.minZoom && newZoom <= _config.maxZoom) {
      zoomLevel.value = newZoom;
      callback(zoomLevel.value);
      _updateMarkerSize(zoomLevel.value);
      _updatePolylineWidth(zoomLevel.value);
    }
  }

  Future<void> toggleMapCenter(bool value) async {
    log('toggleMapCenter', name: '$runtimeType', time: DateTime.now());
    if (onMapCentered != null) {
      isMapCentered.value = value;

      if (locationState.value is LocationUpdateSuccess) {
        final state = locationState.value as LocationUpdateSuccess;
        onMapCentered!.call(state.location);
      }
    }
  }

  void _updatePolylineWidth(double zoom) {
    log('_updatePolylineWidth', name: '$runtimeType', time: DateTime.now());
    if (_polylineWidthCache.containsKey(zoom)) {
      polylineWidth.value = _polylineWidthCache[zoom]!;
      return;
    }
    polylineWidth.value = _calculateMapParameter(
      zoom: zoom,
      minValue: _config.polylineMinWidth,
      maxValue: _config.polylineMaxWidth,
    );
    _polylineWidthCache[zoom] = polylineWidth.value;
  }

  void _updateMarkerSize(double zoom) {
    log('_updateMarkerSize', name: '$runtimeType', time: DateTime.now());
    if (_markerSizeCache.containsKey(zoom)) {
      markerSize.value = _markerSizeCache[zoom]!;
      return;
    }
    markerSize.value = _calculateMapParameter(
      zoom: zoom,
      minValue: _config.markerMinSize,
      maxValue: _config.markerMaxSize,
    );
    _markerSizeCache[zoom] = markerSize.value;
  }

  double _calculateMapParameter({
    required double zoom,
    required double minValue,
    required double maxValue,
  }) {
    log('_calculateMapParameter', name: '$runtimeType', time: DateTime.now());
    return minValue +
        (zoom - _config.minZoom) *
            (maxValue - minValue) /
            (_config.maxZoom - _config.minZoom);
  }
}

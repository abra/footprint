import 'dart:async';
import 'dart:developer';
import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding_repository/geocoding_repository.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_service/location_service.dart';
import 'package:logger/logger.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'extensions.dart';

final logger = Logger(
  printer: PrettyPrinter(colors: true),
);

class MapNotifier {
  MapNotifier({
    required LocationService locationService,
    required RoutesRepository routesRepository,
    required GeocodingRepository geocodingRepository,
    required Config viewConfig,
  })  : _locationService = locationService,
        _routesRepository = routesRepository,
        _geocodingRepository = geocodingRepository,
        _config = viewConfig {
    logger.i('--- MapNotifier init $hashCode');
  }

  final LocationService _locationService;
  final RoutesRepository _routesRepository;
  final GeocodingRepository _geocodingRepository;
  final Config _config;

  Config get viewConfig => _config;

  late Stream<LocationDM> _locationUpdateStream;
  late StreamSubscription<LocationDM> _locationUpdateSubscription;

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

  void Function(double)? onZoomChanged;
  void Function(LocationDM)? onMapCentered;
  void Function(String)? foregroundTaskCallback;

  void dispose() {
    logger.i('--- MapNotifier dispose $hashCode');
    _locationUpdateSubscription.cancel();
    locationState.dispose();
    isRouteRecordingActive.dispose();
    routePoints.dispose();
    placeAddress.dispose();
    zoomLevel.dispose();
    markerSize.dispose();
    polylineWidth.dispose();
    isMapCentered.dispose();
    _geocodingRepository.closeCacheStorage();
  }

  Future<void> reInit() async {
    locationState.value = LocationLoading();
    await initLocationUpdate();
  }

  Future<void> ensurePermissions() async {
    await _locationService.ensureServiceEnabled();
    await _locationService.ensurePermissionsGranted();
  }

  Future<void> initLocationUpdate() async {
    try {
      await _startLocationUpdate();
    } catch (e) {
      locationState.value = LocationUpdateFailure(error: e);
    }
  }

  Future<Future<void> Function()> get startLocationUpdate async =>
      _startLocationUpdate;

  Future<void> _startLocationUpdate() async {
    log('--- _startLocationUpdate started');
    _locationUpdateStream = _locationService.getLocationUpdateStream();

    _locationUpdateSubscription = _locationUpdateStream.listen(
      onLocationUpdate,
      onError: onLocationUpdateError,
    );
    log('--- _startLocationUpdate stopped');
  }

  Function(LocationDM) get onLocationUpdate => (LocationDM location) {
        locationState.value = LocationUpdateSuccess(location: location);

        logger.d('Location update: ${jsonEncode(location.toMap())}');

        onPlaceAddressUpdate(location);

        if (placeAddress.value is PlaceAddressSuccess) {
          final place = placeAddress.value as PlaceAddressSuccess;

          if (foregroundTaskCallback != null) {
            foregroundTaskCallback!(place.address);
          }
        }

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
      };

  Function(dynamic) get onLocationUpdateError => (dynamic error) {
        // TODO: Add error handling for another exceptions
        if (error is LocationServiceDisabledStateException) {
          locationState.value = LocationUpdateFailure(error: error);
          _locationUpdateSubscription.cancel();
        } else {
          log('Location update error: $error');
          locationState.value = LocationUpdateFailure(error: error);
        }
      };

  Future<void> _placeAddressUpdate(LocationDM location) async {
    try {
      final placeAddressModel =
          await _geocodingRepository.getAddressFromCoordinates(location);

      if (placeAddressModel != null) {
        placeAddress.value = PlaceAddressSuccess(
          address: placeAddressModel.address,
        );
      }
    } on CouldNotGetPlaceAddressException catch (e) {
      log('Could not get location address: $e');
      placeAddress.value = PlaceAddressFailure(error: e);
    }
  }

  Function(LocationDM) get onPlaceAddressUpdate => _placeAddressUpdate;

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
      _updateZoom(zoomLevel.value + _config.zoomStep, onZoomChanged ?? (_) {});

  Future<void> zoomOut() =>
      _updateZoom(zoomLevel.value - _config.zoomStep, onZoomChanged ?? (_) {});

  Future<void> _updateZoom(double newZoom, Function(double) callback) async {
    if (newZoom >= _config.minZoom && newZoom <= _config.maxZoom) {
      zoomLevel.value = newZoom;
      callback(zoomLevel.value);
      await _updateMarkerSize(zoomLevel.value);
      await _updatePolylineWidth(zoomLevel.value);
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
    polylineWidth.value = await _calculateMapParameter(
      zoom: zoom,
      minValue: _config.polylineMinWidth,
      maxValue: _config.polylineMaxWidth,
    );
  }

  Future<void> _updateMarkerSize(double zoom) async {
    markerSize.value = await _calculateMapParameter(
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

  final LocationDM location;
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

sealed class PlaceAddressState extends Equatable {
  const PlaceAddressState();
}

class PlaceAddressLoading extends PlaceAddressState {
  @override
  List<Object?> get props => [];
}

class PlaceAddressSuccess extends PlaceAddressState {
  const PlaceAddressSuccess({
    required this.address,
  });

  final String address;

  @override
  List<Object?> get props => [address];
}

class PlaceAddressFailure extends PlaceAddressState {
  const PlaceAddressFailure({
    required this.error,
  }) : errorMessage = '$error';

  final dynamic error;
  final String errorMessage;

  @override
  List<Object?> get props => [error, errorMessage];
}

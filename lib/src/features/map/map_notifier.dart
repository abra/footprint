import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

part 'map_state.dart';

class MapNotifier extends ValueNotifier<MapState> {
  MapNotifier({
    required this.locationRepository,
  }) : super(MapInitialLocationUpdate());

  final LocationRepository locationRepository;
  StreamSubscription<Location>? _locationSubscription;

  Future<void> init() async {
    bool isStillSubscribedButPaused =
        _locationSubscription != null && _locationSubscription!.isPaused;

    try {
      await locationRepository.ensureLocationServiceEnabled();
      await locationRepository.ensurePermissionGranted();

      if (_locationSubscription == null) {
        await _startLocationUpdate();
      } else if (isStillSubscribedButPaused) {
        _locationSubscription?.resume();
      }
    } catch (e) {
      _handlePermissionExceptions(e);
    }
  }

  Future<void> _handlePermissionExceptions(Object e) async {
    if (e is PermissionDeniedException) {
      value = MapLocationServicePermissionDenied();
    } else if (e is PermissionsPermanentlyDeniedException) {
      value = MapLocationServicePermissionPermanentlyDenied();
    } else if (e is PermissionDefinitionsNotFoundException) {
      value = MapLocationServicePermissionDefinitionsNotFound();
    } else if (e is PermissionRequestInProgressException) {
      value = MapLocationServicePermissionRequestInProgress();
    }
  }

  Future<void> _startLocationUpdate() async {
    final stream = locationRepository.locationUpdateStream();

    _locationSubscription = stream.listen((location) {
      log('$location');
      value = MapLocationUpdateSuccess(location: location);
    }, onError: (error) {
      if (error is ServiceDisabledException) {
        value = MapLocationServiceDisabled();
        _locationSubscription?.cancel();
        _locationSubscription = null;
      }
    }, onDone: () {
      log('Done!');
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

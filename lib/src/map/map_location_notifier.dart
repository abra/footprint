import 'dart:async';
import 'dart:developer';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

part 'map_location_state.dart';

class MapLocationNotifier extends ValueNotifier<MapLocationState> {
  MapLocationNotifier({
    required LocationRepository locationRepository,
  })  : _locationRepository = locationRepository,
        super(
          MapInitialLocationUpdate(),
        ) {
    _init();
  }

  final LocationRepository _locationRepository;
  StreamSubscription<Location>? _locationSubscription;

  Future<void> reInit() async {
    value = MapInitialLocationUpdate();
    _init();
  }

  Future<void> _init() async {
    bool isStillSubscribedButPaused =
        _locationSubscription != null && _locationSubscription!.isPaused;

    try {
      await _locationRepository.ensureLocationServiceEnabled();
      await _locationRepository.ensurePermissionGranted();

      if (_locationSubscription == null) {
        await _startLocationUpdate();
      } else if (isStillSubscribedButPaused) {
        _locationSubscription?.resume();
      }
    } catch (e) {
      value = MapLocationUpdateFailure(error: e);
    }
  }

  Future<void> _startLocationUpdate() async {
    final stream = _locationRepository.locationUpdateStream();

    _locationSubscription = stream.listen((location) {
      log('--- Location [$hashCode]: $location');
      value = MapLocationUpdateSuccess(location: location);
    }, onError: (error) {
      if (error is ServiceDisabledException) {
        value = MapLocationUpdateFailure(error: error);
        _locationSubscription?.cancel();
        _locationSubscription = null;
      }
    });
  }

  @override
  void dispose() {
    log('--- $this [$hashCode]: dispose');
    _locationSubscription?.cancel();
    super.dispose();
  }
}

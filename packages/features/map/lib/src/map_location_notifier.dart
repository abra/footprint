import 'dart:async';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:location_repository/location_repository.dart';

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
    await _init();
  }

  Future<void> _init() async {
    final bool isSubscribedButPaused =
        _locationSubscription != null && _locationSubscription!.isPaused;

    try {
      await _locationRepository.ensureLocationServiceEnabled();
      await _locationRepository.ensurePermissionGranted();

      if (_locationSubscription == null) {
        await _startLocationUpdate();
      } else if (isSubscribedButPaused) {
        _locationSubscription?.resume();
      }
    } catch (e) {
      value = MapLocationUpdateFailure(error: e);
    }
  }

  Future<void> _startLocationUpdate() async {
    final Stream<Location> stream = _locationRepository.locationUpdateStream();

    _locationSubscription = stream.listen((Location location) {
      log('--- Location [$hashCode]: $location');
      value = MapLocationUpdateSuccess(location: location);
    }, onError: (dynamic error) {
      // TODO: Add error handling for another exceptions
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

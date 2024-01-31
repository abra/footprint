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
    required this.locationRepository,
  }) : super(MapInitialLocationUpdate());

  final LocationRepository locationRepository;
  StreamSubscription<Location>? _locationSubscription;

  Future<void> reInit() async {
    value = MapInitialLocationUpdate();
    init();
  }

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
      value = MapLocationUpdateFailure(error: e);
    }
  }

  Future<void> _startLocationUpdate() async {
    final stream = locationRepository.locationUpdateStream();

    _locationSubscription = stream.listen((location) {
      log('$location');
      value = MapLocationUpdateSuccess(location: location);
    }, onError: (e) {
      if (e is ServiceDisabledException) {
        value = MapLocationUpdateFailure(error: e);
        _locationSubscription?.cancel();
        _locationSubscription = null;
      }
    });
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

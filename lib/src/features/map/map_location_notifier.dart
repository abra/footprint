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
  }) : super(MapInitialLoading());

  final LocationRepository locationRepository;
  StreamSubscription<Location>? _locationSubscription;

  Future<void> init() async {
    bool isStillSubscribed =
        _locationSubscription != null && _locationSubscription!.isPaused;

    try {
      await _ensureServiceAndPermission();
      if (_locationSubscription == null) {
        log('start!');
        await _runLocationUpdate();
      } else if (isStillSubscribed) {
        log('resume!');
        _locationSubscription?.resume();
      }
    } catch (e) {
      log('Caught exception!');
      // if (e is ServiceDisabledException) {
      //   // TODO: Handle exception
      //   log('Service Disabled Exception');
      // } else
      if (e is PermissionDeniedException) {
        // TODO: Handle exception
        log('Permission Denied Exception');
      } else if (e is PermissionsPermanentlyDeniedException) {
        // TODO: Handle exception
        log('Permission Permanently Denied Exception');
      } else if (e is PermissionDefinitionsNotFoundException) {
        // TODO: Handle exception
        log('Permission Definitions Not Found Exception');
      } else if (e is PermissionRequestInProgressException) {
        // TODO: Handle exception
        log('Permission Request In Progress Exception');
      }
    }
  }

  Future<void> _ensureServiceAndPermission() async {
    await locationRepository.ensureLocationServiceEnabled();
    await locationRepository.ensurePermissionGranted();
  }

  Future<void> _runLocationUpdate() async {
    final stream = locationRepository.locationUpdateStream();

    Location? prev;

    _locationSubscription = stream.listen((location) {
      log('$location');
      value = MapLocationUpdateSuccess(location: location);
    }, onError: (error) {
      if (error is ServiceDisabledException) {
        log('Location Service Disabled Exception!');
        _locationSubscription?.cancel();
        _locationSubscription = null;
      }
    }, onDone: () {
      log('Done!');
    });
    log('Here');
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

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
    bool locationSubscriptionPaused =
        _locationSubscription != null && _locationSubscription!.isPaused;

    try {
      await _checkServiceAndPermission();
      if (_locationSubscription == null) {
        await _startLocationUpdate();
      } else if (locationSubscriptionPaused) {
        _locationSubscription?.resume();
      }
    } catch (e) {
      if (e is ServiceDisabledException) {
        // TODO: Handle exception
        log('Service Disabled Exception');
      } else if (e is PermissionDeniedException) {
        // TODO: Handle exception
        log('Permission Denied Exception');
      } else if (e is PermissionsPermanentlyDeniedException) {
        // TODO: Handle exception
        log('Permission Permanently Denied Exception');
      }
    }
  }

  Future<void> _checkServiceAndPermission() async {
    await locationRepository.checkLocationServiceEnabled();
    await locationRepository.checkPermissionGranted();
  }

  Future<void> _startLocationUpdate() async {
    try {
      final stream = locationRepository.getLocationUpdatesStream();

      Location? prev;

      _locationSubscription = stream.listen((location) async {
        log('$location');
        value = MapLocationUpdateSuccess(location: location);
      });
    } catch (_) {
      rethrow;
    }
    //
    // final lastMapLocationState = value;
    // if (lastMapLocationState is MapLocationUpdateSuccess) {
    //   value = MapLocationUpdateSuccess(
    //     location: lastMapLocationState.location,
    //     locationUpdateError: error,
    //   );
    //   _locationSubscription?.pause();
    //   logger.log(
    //       'Location Subscription is paused: ${_locationSubscription?.isPaused}');
    // }
    // });
    // } catch (error) {
    //   log('### Error: $error');
    //   final lastMapLocationState = value;
    //   if (lastMapLocationState is MapLocationUpdateSuccess) {
    //     value = MapLocationUpdateSuccess(
    //       location: lastMapLocationState.location,
    //       locationUpdateError: error,
    //     );
    //   }
    // }
  }

  // Future<double> _calculateSpeed({
  //   required Location from,
  //   required Location to,
  // }) async {
  //   Duration timeDifference = to.timestamp.difference(from.timestamp);
  //   double distance = await _calculateDistance(from: from, to: to);
  //   double speed = distance / timeDifference.inHours;
  //   return speed;
  // }
  //
  // double _degreesToRadians(double degrees) {
  //   return degrees * pi / 180;
  // }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

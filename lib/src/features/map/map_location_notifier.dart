import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_repository.dart';
import 'package:equatable/equatable.dart';

part 'map_location_state.dart';

class MapLocationNotifier extends ValueNotifier<MapLocationState> {
  MapLocationNotifier({
    required this.locationRepository,
  }) : super(MapInitialLoading());

  final LocationRepository locationRepository;
  StreamSubscription<Location>? _locationSubscription;

  Future<void> updateLocation() async {
    value = MapInitialLoading();
    await _updateLocation();
  }

  Future<void> _updateLocation() async {
    try {
      final stream = locationRepository.getLocationUpdatesStream();

      _locationSubscription = stream.listen((location) {
        value = MapLocationUpdateSuccess(
          location: location,
        );
        // TODO: Remove after testing
        log('Location: ${location.latitude}, ${location.longitude}');
      });
    } catch (error) {
      value = const MapLocationUpdateFailure();
      return;
    }
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    super.dispose();
  }
}

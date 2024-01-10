import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

part 'map_screen_state.dart';

class MapScreenNotifier extends ValueNotifier<MapScreenState> {
  MapScreenNotifier({
    required this.locationRepository,
  }) : super(MapScreenInitial());

  final LocationRepository locationRepository;
  late StreamSubscription<Location> _locationSubscription;

  Future<void> _updateLocation() async {
    try {
      _locationSubscription =
          locationRepository.getLocationUpdatesStream().listen((location) {
        // log('$runtimeType $hashCode}');
        // log('location: ${location.latitude}, ${location.longitude}');
        value = MapScreenLocationUpdateSuccess(
          location: location,
        );
      });
    } catch (error) {
      value = const MapScreenLocationUpdateFailure();
      return;
    }
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    super.dispose();
  }

  Future<void> updateLocation() async {
    value = MapScreenInitial();
    await _updateLocation();
  }
}

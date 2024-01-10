import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/location_repository/location_repository.dart';

part 'map_state.dart';

class MapNotifier extends ValueNotifier<MapState> {
  MapNotifier({
    required this.locationRepository,
  }) : super(MapUpdateLoading());

  final LocationRepository locationRepository;
  late StreamSubscription<Location> _locationSubscription;

  Future<void> _updateLocation() async {
    try {
      _locationSubscription =
          locationRepository.getLocationUpdatesStream().listen((location) {
        // log('$runtimeType $hashCode}');
        // log('location: ${location.latitude}, ${location.longitude}');
        value = MapLocationUpdateSuccess(
          location: location,
        );
      });
    } catch (error) {
      value = const MapLocationUpdateFailure();
      return;
    }
  }

  @override
  void dispose() {
    _locationSubscription.cancel();
    super.dispose();
  }

  Future<void> updateLocation() async {
    value = MapUpdateLoading();
    await _updateLocation();
  }
}

part of 'map_location_notifier.dart';

sealed class MapLocationState extends Equatable {
  const MapLocationState();
}

class MapInitialLocationUpdate extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapLocationState {
  const MapLocationUpdateSuccess({
    required this.location,
    this.locationUpdateError,
  });

  final Location location;
  final dynamic locationUpdateError;

  @override
  List<Object?> get props => [
        location,
        locationUpdateError,
      ];
}

class MapLocationUpdateFailure extends MapLocationState {
  const MapLocationUpdateFailure();

  @override
  List<Object?> get props => [];
}

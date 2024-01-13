part of 'map_location_notifier.dart';

sealed class MapLocationState extends Equatable {
  const MapLocationState();
}

class MapInitialLoading extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapLocationState {
  const MapLocationUpdateSuccess({
    required this.location,
  });

  final Location location;

  @override
  List<Object?> get props => [location];
}

class MapLocationUpdateFailure extends MapLocationState {
  const MapLocationUpdateFailure();

  @override
  List<Object?> get props => [];
}

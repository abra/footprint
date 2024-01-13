part of 'map_notifier.dart';

sealed class MapState extends Equatable {
  const MapState();
}

class MapInitialLoading extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapState {
  const MapLocationUpdateSuccess({
    required this.location,
  });

  final Location location;

  @override
  List<Object?> get props => [location];
}

class MapLocationUpdateFailure extends MapState {
  const MapLocationUpdateFailure();

  @override
  List<Object?> get props => [];
}

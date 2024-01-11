part of 'map_notifier.dart';

sealed class MapState {
  const MapState();
}

class MapInitialLoading extends MapState {}

class MapLocationUpdateSuccess extends MapState {
  const MapLocationUpdateSuccess({
    required this.location,
  });

  final Location location;
}

class MapLocationUpdateFailure extends MapState {
  const MapLocationUpdateFailure();
}

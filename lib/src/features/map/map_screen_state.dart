part of 'map_screen_notifier.dart';

sealed class MapScreenState {
  const MapScreenState();
}

class MapScreenInitial extends MapScreenState {}

class MapScreenLocationUpdateSuccess extends MapScreenState {
  const MapScreenLocationUpdateSuccess({
    required this.location,
  });

  final Location location;
}

class MapScreenLocationUpdateFailure extends MapScreenState {
  const MapScreenLocationUpdateFailure();
}

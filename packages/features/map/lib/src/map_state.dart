part of 'map_notifier.dart';

sealed class MapState extends Equatable {
  const MapState();
}

class MapInitialLocationLoading extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapState {
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

class MapLocationUpdateFailure extends MapState {
  const MapLocationUpdateFailure({
    required this.error,
  }) : errorMessage = '$error';

  final dynamic error;
  final String errorMessage;

  @override
  List<Object?> get props => [
        error,
        errorMessage,
      ];
}

class MapRouteRecordingStarted extends MapLocationUpdateSuccess {
  const MapRouteRecordingStarted({
    required super.location,
    required this.routePoints,
  });

  final List<LatLng> routePoints;

  @override
  List<Object?> get props => [
        location,
        routePoints,
      ];
}

class MapRouteRecordingStopped extends MapLocationUpdateSuccess {
  const MapRouteRecordingStopped({
    required super.location,
    required this.routePoints,
  });

  final List<LatLng> routePoints;

  @override
  List<Object?> get props => [
        location,
        routePoints,
      ];
}
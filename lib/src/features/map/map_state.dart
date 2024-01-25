part of 'map_notifier.dart';

sealed class MapState extends Equatable {
  const MapState();
}

class MapInitialLocationUpdate extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServiceEnabled extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServiceDisabled extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionGranted extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionDenied extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionPermanentlyDenied extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionDefinitionsNotFound extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionRequestInProgress extends MapState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapState {
  const MapLocationUpdateSuccess({
    required this.location,
  });

  final Location location;

  @override
  List<Object?> get props => [
        location,
      ];
}

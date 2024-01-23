part of 'map_location_notifier.dart';

sealed class MapLocationState extends Equatable {
  const MapLocationState();
}

class MapInitialLocationUpdate extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServiceEnabled extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServiceDisabled extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionGranted extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionDenied extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionPermanentlyDenied extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionDefinitionsNotFound extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationServicePermissionRequestInProgress extends MapLocationState {
  @override
  List<Object?> get props => [];
}

class MapLocationUpdateSuccess extends MapLocationState {
  const MapLocationUpdateSuccess({
    required this.location,
  });

  final Location location;

  @override
  List<Object?> get props => [
        location,
      ];
}

part of 'map_location_notifier.dart';

sealed class MapLocationState extends Equatable {
  const MapLocationState();
}

class MapInitialLocationLoading extends MapLocationState {
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

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
  });

  final Location location;

  @override
  List<Object?> get props => [
        location,
      ];
}

class MapLocationUpdateFailure extends MapLocationState {
  const MapLocationUpdateFailure({
    required this.error,
  }) : errorMessage = '$error';

  final dynamic error;
  final String errorMessage;

  @override
  // TODO: implement props
  List<Object?> get props => [
        error,
        errorMessage,
      ];
}

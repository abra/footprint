part of 'map_notifier.dart';

sealed class LocationState extends Equatable {
  const LocationState();
}

class LocationLoading extends LocationState {
  @override
  List<Object?> get props => [];
}

class LocationUpdateSuccess extends LocationState {
  const LocationUpdateSuccess({
    required this.location,
    this.locationUpdateError,
  });

  final LocationDM location;
  final dynamic locationUpdateError;

  @override
  List<Object?> get props => [
        location,
        locationUpdateError,
      ];
}

class LocationUpdateFailure extends LocationState {
  const LocationUpdateFailure({
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

sealed class PlaceAddressState extends Equatable {
  const PlaceAddressState();
}

class PlaceAddressLoading extends PlaceAddressState {
  @override
  List<Object?> get props => [];
}

class PlaceAddressSuccess extends PlaceAddressState {
  const PlaceAddressSuccess({
    required this.address,
  });

  final String address;

  @override
  List<Object?> get props => [address];
}

class PlaceAddressFailure extends PlaceAddressState {
  const PlaceAddressFailure({
    required this.error,
  }) : errorMessage = '$error';

  final dynamic error;
  final String errorMessage;

  @override
  List<Object?> get props => [error, errorMessage];
}

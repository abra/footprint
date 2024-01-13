part of 'map_view_notifier.dart';

sealed class MapViewState extends Equatable {
  const MapViewState();
}

class MapViewInitial extends MapViewState {
  @override
  List<Object?> get props => [];
}

class MapViewUpdated extends MapViewState {
  const MapViewUpdated({
    required this.centerMapToCurrentLocation,
    required this.zoom,
  });

  final bool centerMapToCurrentLocation;
  final double zoom;

  @override
  List<Object?> get props => [];
}

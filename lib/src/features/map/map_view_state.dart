part of 'map_view_notifier.dart';

sealed class MapViewState extends Equatable {
  const MapViewState();
}

class MapViewUpdated extends MapViewState {
  const MapViewUpdated({
    required this.shouldCenterMap,
    required this.zoom,
    required this.maxZoom,
    required this.minZoom,
  });

  final bool shouldCenterMap;
  final double zoom;
  final double maxZoom;
  final double minZoom;

  MapViewUpdated copyWith({
    bool? shouldCenterMap,
    double? zoom,
    double? maxZoom,
    double? minZoom,
  }) {
    return MapViewUpdated(
      shouldCenterMap: shouldCenterMap ?? this.shouldCenterMap,
      zoom: zoom ?? this.zoom,
      maxZoom: maxZoom ?? this.maxZoom,
      minZoom: minZoom ?? this.minZoom,
    );
  }

  @override
  List<Object?> get props => [
        shouldCenterMap,
        zoom,
        maxZoom,
        minZoom,
      ];
}

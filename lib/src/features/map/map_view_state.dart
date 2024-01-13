part of 'map_view_notifier.dart';

sealed class MapViewState extends Equatable {
  const MapViewState();
}

class MapViewUpdated extends MapViewState {
  const MapViewUpdated({
    required this.shouldCenter,
    required this.zoom,
    required this.maxZoom,
    required this.minZoom,
  });

  final bool shouldCenter;
  final double zoom;
  final double maxZoom;
  final double minZoom;

  MapViewUpdated copyWith({
    bool? shouldCenter,
    double? zoom,
    double? maxZoom,
    double? minZoom,
  }) {
    log('zoom: $zoom, shouldCenter: $shouldCenter');
    return MapViewUpdated(
      shouldCenter: shouldCenter ?? this.shouldCenter,
      zoom: zoom ?? this.zoom,
      maxZoom: maxZoom ?? this.maxZoom,
      minZoom: minZoom ?? this.minZoom,
    );
  }

  @override
  List<Object?> get props => [
        shouldCenter,
        zoom,
        maxZoom,
        minZoom,
      ];
}

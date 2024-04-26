part of 'map_view_notifier.dart';

sealed class MapViewState extends Equatable {
  const MapViewState();
}

class MapViewUpdated extends MapViewState {
  const MapViewUpdated({
    required this.shouldCenterMap,
    required this.zoomStep,
    required this.zoom,
    required this.maxZoom,
    required this.minZoom,
    required this.urlTemplate,
    required this.fallbackUrl,
    required this.userAgentPackageName,
  });

  final bool shouldCenterMap;
  final double zoomStep;
  final double zoom;
  final double maxZoom;
  final double minZoom;
  final String urlTemplate;
  final String fallbackUrl;
  final String userAgentPackageName;

  MapViewUpdated copyWith({
    bool? shouldCenterMap,
    double? zoomStep,
    double? zoom,
    double? maxZoom,
    double? minZoom,
    String? urlTemplate,
    String? fallbackUrl,
    String? userAgentPackageName,
  }) {
    return MapViewUpdated(
      shouldCenterMap: shouldCenterMap ?? this.shouldCenterMap,
      zoomStep: zoomStep ?? this.zoomStep,
      zoom: zoom ?? this.zoom,
      maxZoom: maxZoom ?? this.maxZoom,
      minZoom: minZoom ?? this.minZoom,
      urlTemplate: urlTemplate ?? this.urlTemplate,
      fallbackUrl: fallbackUrl ?? this.fallbackUrl,
      userAgentPackageName: userAgentPackageName ?? this.userAgentPackageName,
    );
  }

  @override
  List<Object?> get props => [
        shouldCenterMap,
        zoomStep,
        zoom,
        maxZoom,
        minZoom,
        urlTemplate,
        fallbackUrl,
        userAgentPackageName,
      ];
}

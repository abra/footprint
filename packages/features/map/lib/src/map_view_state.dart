part of 'map_view_notifier.dart';

class MapViewState extends Equatable {
  const MapViewState({
    required this.markerSize,
    required this.markerMaxSize,
    required this.markerMinSize,
    required this.polylineStrokeWidth,
    required this.polylineStrokeMinWidth,
    required this.polylineStrokeMaxWidth,
    required this.isCentered,
    required this.zoomStep,
    required this.zoom,
    required this.maxZoom,
    required this.minZoom,
    required this.urlTemplate,
    required this.fallbackUrl,
    required this.userAgentPackageName,
  });

  final double markerSize;
  final double markerMaxSize;
  final double markerMinSize;
  final double polylineStrokeWidth;
  final double polylineStrokeMinWidth;
  final double polylineStrokeMaxWidth;
  final bool isCentered;
  final double zoomStep;
  final double zoom;
  final double maxZoom;
  final double minZoom;
  final String urlTemplate;
  final String fallbackUrl;
  final String userAgentPackageName;

  MapViewState copyWith({
    double? markerSize,
    double? markerMaxSize,
    double? markerMinSize,
    double? polylineStrokeWidth,
    double? polylineStrokeMinWidth,
    double? polylineStrokeMaxWidth,
    bool? isCentered,
    double? zoomStep,
    double? zoom,
    double? maxZoom,
    double? minZoom,
    String? urlTemplate,
    String? fallbackUrl,
    String? userAgentPackageName,
  }) {
    return MapViewState(
      markerSize: markerSize ?? this.markerSize,
      markerMaxSize: markerMaxSize ?? this.markerMaxSize,
      markerMinSize: markerMinSize ?? this.markerMinSize,
      polylineStrokeWidth: polylineStrokeWidth ?? this.polylineStrokeWidth,
      polylineStrokeMinWidth: polylineStrokeMinWidth ?? this.polylineStrokeMinWidth,
      polylineStrokeMaxWidth: polylineStrokeMaxWidth ?? this.polylineStrokeMaxWidth,
      isCentered: isCentered ?? this.isCentered,
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
        markerSize,
        markerMaxSize,
        markerMinSize,
        polylineStrokeWidth,
        polylineStrokeMinWidth,
        polylineStrokeMaxWidth,
        isCentered,
        zoomStep,
        zoom,
        maxZoom,
        minZoom,
        urlTemplate,
        fallbackUrl,
        userAgentPackageName,
      ];
}

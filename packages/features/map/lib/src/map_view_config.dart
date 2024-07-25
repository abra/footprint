class MapViewConfig {
  const MapViewConfig();

  final double markerSize = 17.3;
  final double markerMaxSize = 22.0;
  final double markerMinSize = 8.0;
  final double polylineStrokeWidth = 4.0;
  final double polylineStrokeMinWidth = 2.0;
  final double polylineStrokeMaxWidth = 8.0;
  final bool isCentered = true;
  final double zoomStep = 0.5;
  final double defaultZoom = 16;
  final double maxZoom = 17;
  final double minZoom = 14;
  final String urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String fallbackUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  final String userAgentPackageName = 'com.github.abra.footprint';
}

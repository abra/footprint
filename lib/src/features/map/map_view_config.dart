// TODO: Should be initialized in main.dart
class MapViewConfig {
  const MapViewConfig();

  final bool shouldCenterMap = true;
  final double zoomStep = 0.5;
  final double defaultZoom = 16;
  final double maxZoom = 18;
  final double minZoom = 14;
  final String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  final String fallbackUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  final String userAgentPackageName = 'com.github.abra.footprint';
}

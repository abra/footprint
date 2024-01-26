abstract class MapConfig {
  static const bool shouldCenterMap = true;
  static const double zoomStep = 0.5;
  static const double defaultZoom = 16;
  static const double maxZoom = 18;
  static const double minZoom = 14;
  static const String urlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String fallbackUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const String userAgentPackageName = 'com.github.abra.footprint';
}

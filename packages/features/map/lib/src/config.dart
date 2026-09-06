class MapConfig {
  const MapConfig({
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.attribution = 'OpenStreetMap contributors',
    this.attributionUrl = 'https://www.openstreetmap.org/copyright',
  });

  final String urlTemplate;
  final String attribution;
  final String attributionUrl;
  final String userAgentPackageName = 'io.github.abra.footprint';
  final double defaultZoom = 16;
  final double maxZoom = 19;
  final double minZoom = 2;
}

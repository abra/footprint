import 'package:flutter_map/flutter_map.dart';

class MapTileConfig {
  const MapTileConfig({
    this.urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    this.attribution = 'OpenStreetMap contributors',
    this.attributionUrl = 'https://www.openstreetmap.org/copyright',
    this.tileProviderFactory,
  });
  final String urlTemplate;
  final String attribution;
  final String attributionUrl;
  final TileProvider Function()? tileProviderFactory;
  final String userAgentPackageName = 'io.github.abra.footprint';
  final double defaultZoom = 16;
  final double maxZoom = 19;
  final double minZoom = 2;
}

import 'package:map/map.dart';

class ApplicationConfig {
  const ApplicationConfig();

  MapConfig get map => const MapConfig(
    urlTemplate: String.fromEnvironment(
      'TILE_URL_TEMPLATE',
      defaultValue: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    ),
    attribution: String.fromEnvironment(
      'TILE_ATTRIBUTION',
      defaultValue: 'OpenStreetMap contributors',
    ),
    attributionUrl: String.fromEnvironment(
      'TILE_ATTRIBUTION_URL',
      defaultValue: 'https://www.openstreetmap.org/copyright',
    ),
  );

  void validate() {
    final template = map.urlTemplate;
    final uri = Uri.tryParse(template);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        !['{x}', '{y}', '{z}'].every(template.contains)) {
      throw const FormatException(
        'TILE_URL_TEMPLATE must be an HTTPS XYZ template.',
      );
    }
  }
}

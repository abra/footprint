import 'package:map/map.dart';
import 'package:route_planning/route_planning.dart';

class ApplicationConfig {
  const ApplicationConfig();

  String get routingApiKey => const String.fromEnvironment('ORS_API_KEY');
  Uri get routingEndpoint => Uri.parse(
    const String.fromEnvironment(
      'ROUTING_URL',
      defaultValue: OpenRouteServicePlanner.defaultEndpoint,
    ),
  );

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
    if (routingEndpoint.scheme != 'https' ||
        routingEndpoint.host.isEmpty ||
        routingEndpoint.userInfo.isNotEmpty) {
      throw const FormatException('ROUTING_URL must be an HTTPS endpoint.');
    }
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

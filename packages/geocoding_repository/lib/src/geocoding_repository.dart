import 'package:meta/meta.dart';

import 'geocoding_service.dart';

class GeocodingRepository {
  const GeocodingRepository({
    @visibleForTesting GeocodingService? geocodingService,
  }) : _geocodingService = geocodingService ?? const GeocodingService();

  final GeocodingService _geocodingService;



}

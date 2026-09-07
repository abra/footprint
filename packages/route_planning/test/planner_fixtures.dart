import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:http/testing.dart';

export '../../domain_models/test/walk_fixtures.dart';

Map<String, Object> geometryResponse(RoutePlan plan) => {
  'type': 'LineString',
  'coordinates': plan.points.map((point) => point.coordinates).toList(),
};

String routeResponse(RoutePlan plan) => jsonEncode({
  'type': 'FeatureCollection',
  'features': [
    {'type': 'Feature', 'geometry': geometryResponse(plan)},
  ],
});

class TrackedClient extends MockClient {
  TrackedClient(super.handler);
  bool closed = false;
  @override
  void close() {
    closed = true;
    super.close();
  }
}

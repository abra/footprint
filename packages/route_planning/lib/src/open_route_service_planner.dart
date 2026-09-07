import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

import 'route_planner.dart';

class OpenRouteServicePlanner implements RoutePlanner {
  static const defaultEndpoint =
      'https://api.heigit.org/openrouteservice/v2/directions/foot-walking/geojson';
  static const _hostedApiHosts = {'api.heigit.org', 'api.openrouteservice.org'};

  OpenRouteServicePlanner({
    this.apiKey = '',
    Uri? endpoint,
    http.Client Function()? createClient,
    int Function()? nextSeed,
    String Function()? nextId,
    this.timeout = const Duration(seconds: 12),
  }) : endpoint = endpoint ?? Uri.parse(defaultEndpoint),
       _createClient = createClient ?? http.Client.new,
       _nextSeed = nextSeed ?? (() => Random().nextInt(1000000)),
       _nextId = nextId ?? const Uuid().v4;

  final String apiKey;
  final Uri endpoint;
  final Duration timeout;
  final http.Client Function() _createClient;
  final int Function() _nextSeed;
  final String Function() _nextId;
  http.Client? _client;
  bool _disposed = false;

  @override
  bool get available =>
      !_disposed &&
      (apiKey.trim().isNotEmpty || !_hostedApiHosts.contains(endpoint.host));

  Future<http.Response> _request(
    http.Client client, {
    required GeoPoint start,
    GeoPoint? end,
    double? distance,
    required int seed,
  }) => client.post(
    endpoint,
    headers: {
      'Content-Type': 'application/json',
      if (apiKey.trim().isNotEmpty) 'Authorization': apiKey.trim(),
    },
    body: jsonEncode({
      'coordinates': [start.coordinates, if (end != null) end.coordinates],
      'instructions': false,
      if (end != null) 'radiuses': [100, 100],
      'options': {
        'avoid_features': ['ferries', 'fords'],
        if (end == null)
          'round_trip': {'length': distance, 'points': 3, 'seed': seed},
      },
    }),
  );

  @override
  Future<RoutePlan> generate({
    required GeoPoint start,
    required double distance,
    Set<String> exploredCells = const {},
  }) =>
      _generate(start: start, distance: distance, exploredCells: exploredCells);

  @override
  Future<RoutePlan> generateBetween({
    required GeoPoint start,
    required GeoPoint end,
  }) => _generate(start: start, end: end);

  Future<RoutePlan> _generate({
    required GeoPoint start,
    GeoPoint? end,
    double? distance,
    Set<String> exploredCells = const {},
  }) async {
    if (!available) {
      throw const RoutePlanningException('Route planning is not configured.');
    }
    if (!start.isValid || (end != null && !end.isValid)) {
      throw const RoutePlanningException('Choose valid points on the map.');
    }
    final loop = end == null;
    if (loop &&
        (distance == null ||
            !distance.isFinite ||
            distance < 1000 ||
            distance > 20000)) {
      throw const RoutePlanningException(
        'Choose a distance between 1 and 20 km.',
      );
    }
    if (!loop &&
        (start.distanceTo(end) < 100 || start.distanceTo(end) > 20000)) {
      throw const RoutePlanningException(
        'Choose points between 100 m and 20 km apart.',
      );
    }
    cancel();
    final client = _client = _createClient();
    RoutePlan? best;
    var bestScore = double.negativeInfinity;
    try {
      // Bounded candidate search. Length and closure are hard constraints;
      // unfamiliar areas only rank routes that already satisfy them.
      for (var attempt = 0; attempt < (loop ? 3 : 1); attempt++) {
        final response = await _request(
          client,
          start: start,
          end: end,
          distance: distance,
          seed: loop ? _nextSeed() : 0,
        ).timeout(timeout);
        if (!identical(_client, client)) throw const PlanningCancelled();
        if (response.statusCode == 401 || response.statusCode == 403) {
          throw const RoutePlanningException(
            'Route planning access was denied.',
          );
        }
        if (response.statusCode == 429) {
          if (best != null) return best;
          throw const RoutePlanningException(
            'Route planning is busy. Please try again later.',
          );
        }
        if (response.statusCode != 200) {
          if (best != null) return best;
          throw const RoutePlanningException(
            'A walking route could not be generated. Please try again.',
          );
        }
        RoutePlan plan;
        try {
          final body = jsonDecode(response.body) as Map<String, dynamic>;
          final shape =
              ((body['features'] as List).first
                      as Map<String, dynamic>)['geometry']
                  as Map<String, dynamic>;
          if (shape['type'] != 'LineString') throw const FormatException();
          plan = RoutePlan.fromGeometry(
            id: _nextId(),
            mode: loop ? RoutePlanMode.loop : RoutePlanMode.pointToPoint,
            requestedDistance: distance,
            points: (shape['coordinates'] as List)
                .map((p) => GeoPoint.fromCoordinates(p as List))
                .toList(),
          );
          if (plan.points.first.distanceTo(start) > 100) continue;
          if (end != null && plan.points.last.distanceTo(end) > 100) continue;
        } on Object catch (error) {
          if (error is! FormatException &&
              error is! TypeError &&
              error is! StateError) {
            rethrow;
          }
          continue;
        }
        if (!loop) return plan;
        final cells = plan.explorationSamples
            .map(ExplorationCell.at)
            .map((c) => c.id)
            .toSet();
        final novelty =
            cells.where((c) => !exploredCells.contains(c)).length /
            cells.length;
        final score = novelty - (plan.distance - distance!).abs() / distance;
        if (score > bestScore) {
          best = plan;
          bestScore = score;
        }
        if (exploredCells.isEmpty) return plan;
      }
      if (best != null) return best;
      if (!loop) {
        throw const RoutePlanningException(
          'No walking route between 100 m and 20 km was found near these points. Choose other points.',
        );
      }
      throw const RoutePlanningException(
        'No suitable loop within 10% of this distance was found. Try another distance.',
      );
    } on TimeoutException {
      if (!identical(_client, client)) throw const PlanningCancelled();
      if (best != null) return best;
      throw const RoutePlanningException(
        'Route planning timed out. Please try again.',
      );
    } on http.ClientException {
      if (!identical(_client, client)) throw const PlanningCancelled();
      if (best != null) return best;
      throw const RoutePlanningException(
        'Cannot reach the routing service. Check your connection.',
      );
    } finally {
      client.close();
      if (identical(_client, client)) _client = null;
    }
  }

  @override
  void cancel() {
    _client?.close();
    _client = null;
  }

  @override
  void dispose() {
    _disposed = true;
    cancel();
  }
}

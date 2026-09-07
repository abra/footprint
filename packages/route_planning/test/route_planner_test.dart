import 'dart:async';
import 'dart:convert';

import 'package:domain_models/domain_models.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:route_planning/route_planning.dart';
import 'package:test/test.dart';

import 'planner_fixtures.dart';

void main() {
  final plan = loopPlan();

  test('point-to-point request uses two ordered endpoints, no round trip and measured path distance', () async {
    final pointToPoint = RoutePlan.fromGeometry(
      id: 'open',
      mode: RoutePlanMode.pointToPoint,
      points: const [
        GeoPoint(49.4, 8.67),
        GeoPoint(49.41, 8.67),
        GeoPoint(49.41, 8.69),
      ],
    );
    var calls = 0;
    final client = TrackedClient((request) async {
      calls++;
      final body = jsonDecode(request.body);
      expect(body['coordinates'], [
        pointToPoint.points.first.coordinates,
        pointToPoint.points.last.coordinates,
      ]);
      expect(body['options']['round_trip'], isNull);
      expect(body['options']['avoid_features'], ['ferries', 'fords']);
      expect(body['radiuses'], [100, 100]);
      expect(request.headers['authorization'], 'test-key');
      return http.Response(routeResponse(pointToPoint), 200);
    });
    final planner = OpenRouteServicePlanner(
      apiKey: 'test-key',
      createClient: () => client,
    );
    final result = await planner.generateBetween(
      start: pointToPoint.points.first,
      end: pointToPoint.points.last,
    );
    expect(result.mode, RoutePlanMode.pointToPoint);
    expect(result.requestedDistance, isNull);
    expect(result.points, pointToPoint.points);
    expect(
      result.distance,
      greaterThan(
        pointToPoint.points.first.distanceTo(pointToPoint.points.last),
      ),
    );
    expect(calls, 1);
    expect(client.closed, isTrue);
  });

  test('invalid endpoint selections make no HTTP requests', () async {
    var created = 0;
    final planner = OpenRouteServicePlanner(
      apiKey: 'test-key',
      createClient: () {
        created++;
        return MockClient((_) async => http.Response('{}', 200));
      },
    );
    for (final end in [
      const GeoPoint(0, 0),
      const GeoPoint(0.0001, 0),
      const GeoPoint(1, 1),
      const GeoPoint(double.nan, 0),
    ]) {
      await expectLater(
        planner.generateBetween(start: const GeoPoint(0, 0), end: end),
        throwsA(isA<RoutePlanningException>()),
      );
    }
    expect(created, 0);
  });

  test('point-to-point rejects a distant snapped finish and malformed geometry without a fabricated fallback', () async {
    final open = pointToPointPlan();
    for (final body in [
      '{}',
      routeResponse(plan),
      routeResponse(pointToPointPlan(end: const GeoPoint(0.03, 0.0005))),
    ]) {
      var calls = 0;
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => MockClient((_) async {
          calls++;
          return http.Response(body, 200);
        }),
      );
      await expectLater(
        planner.generateBetween(
          start: open.points.first,
          end: open.points.last,
        ),
        throwsA(isA<RoutePlanningException>()),
      );
      expect(calls, 1);
    }
  });

  test(
    'changing request mode cancels an in-flight point-to-point result',
    () async {
      final pending = Completer<http.Response>();
      final open = pointToPointPlan();
      final clients = [
        TrackedClient((_) => pending.future),
        TrackedClient((_) async => http.Response(routeResponse(plan), 200)),
      ];
      var created = 0;
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => clients[created++],
      );
      final between = planner.generateBetween(
        start: open.points.first,
        end: open.points.last,
      );
      final cancelled = expectLater(between, throwsA(isA<PlanningCancelled>()));
      expect(
        (await planner.generate(
          start: plan.points.first,
          distance: 1200,
        )).isLoop,
        isTrue,
      );
      pending.complete(http.Response(routeResponse(open), 200));
      await cancelled;
      expect(clients.every((c) => c.closed), isTrue);
    },
  );
  test('uses walking GeoJSON, auth header and round trip options; closes the client', () async {
    final client = TrackedClient((request) async {
      expect(request.url.host, 'api.heigit.org');
      expect(
        request.url.path,
        '/openrouteservice/v2/directions/foot-walking/geojson',
      );
      expect(request.headers['authorization'], 'test-key');
      expect(request.url.query, isEmpty);
      final body = jsonDecode(request.body);
      expect(body['coordinates'], [plan.points.first.coordinates]);
      expect(body['options']['round_trip'], {
        'length': 1200.0,
        'points': 3,
        'seed': 4,
      });
      return http.Response(routeResponse(plan), 200);
    });
    final planner = OpenRouteServicePlanner(
      apiKey: ' test-key ',
      createClient: () => client,
      nextSeed: () => 4,
      nextId: () => 'result',
    );
    final result = await planner.generate(
      start: plan.points.first,
      distance: 1200,
    );
    expect(result.id, 'result');
    expect(result.points, plan.points);
    expect(client.closed, isTrue);
  });

  test(
    'missing key is explicit, never replaced with a fictional route',
    () async {
      final planner = OpenRouteServicePlanner();
      expect(planner.available, isFalse);
      await expectLater(
        planner.generate(start: plan.points.first, distance: 1200),
        throwsA(isA<RoutePlanningException>()),
      );
      expect(
        OpenRouteServicePlanner(
          endpoint: Uri.parse('https://routing.example/walk'),
        ).available,
        isTrue,
      );
    },
  );

  test(
    'invalid and wrong-length responses have a bounded retry count',
    () async {
      var calls = 0;
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => MockClient((_) async {
          calls++;
          return http.Response(routeResponse(loopPlan(distance: 5000)), 200);
        }),
      );
      await expectLater(
        planner.generate(start: plan.points.first, distance: 1200),
        throwsA(isA<RoutePlanningException>()),
      );
      expect(calls, 3);
    },
  );

  test(
    'both hosted API domains require a nonblank key before any HTTP request',
    () async {
      for (final endpoint in [
        OpenRouteServicePlanner.defaultEndpoint,
        'https://api.openrouteservice.org/v2/directions/foot-walking/geojson',
      ]) {
        var createdClients = 0;
        final planner = OpenRouteServicePlanner(
          endpoint: Uri.parse(endpoint),
          apiKey: '   ',
          createClient: () {
            createdClients++;
            return MockClient((_) async => http.Response('{}', 500));
          },
        );
        expect(planner.available, isFalse);
        await expectLater(
          planner.generate(start: plan.points.first, distance: 1200),
          throwsA(isA<RoutePlanningException>()),
        );
        expect(createdClients, 0);
        planner.dispose();
      }
    },
  );

  test('malformed geometry and distant starts are rejected', () async {
    for (final body in [
      'not json',
      '{}',
      '{"features":[]}',
      routeResponse(loopPlan(start: const GeoPoint(50, 50))),
    ]) {
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => MockClient((_) async => http.Response(body, 200)),
      );
      await expectLater(
        planner.generate(start: plan.points.first, distance: 1200),
        throwsA(isA<RoutePlanningException>()),
      );
    }
  });

  test(
    'routing HTTP errors do not leak response bodies or retry indefinitely',
    () async {
      for (final code in [401, 403, 429, 500]) {
        var calls = 0;
        final planner = OpenRouteServicePlanner(
          apiKey: 'test-key',
          createClient: () => MockClient((_) async {
            calls++;
            return http.Response('secret upstream content', code);
          }),
        );
        await expectLater(
          planner.generate(start: plan.points.first, distance: 1200),
          throwsA(
            isA<RoutePlanningException>().having(
              (e) => e.message,
              'message',
              isNot(contains('secret')),
            ),
          ),
        );
        expect(calls, 1);
      }
    },
  );

  test(
    'novelty ranks valid candidates without accepting an invalid length',
    () async {
      final other = loopPlan(start: const GeoPoint(-0.0002, 0.0005));
      final responses = [plan, loopPlan(distance: 10000), other];
      var calls = 0;
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => MockClient(
          (_) async => http.Response(routeResponse(responses[calls++]), 200),
        ),
      );
      final result = await planner.generate(
        start: plan.points.first,
        distance: 1200,
        exploredCells: plan.explorationSamples
            .map(ExplorationCell.at)
            .map((c) => c.id)
            .toSet(),
      );
      expect(result.points, other.points);
      expect(calls, 3);
    },
  );

  test('network errors do not expose upstream credentials', () async {
    final client = TrackedClient((_) async {
      throw http.ClientException(
        'secret upstream details',
        Uri.parse('https://routing.example/walk?token=secret'),
      );
    });
    final planner = OpenRouteServicePlanner(
      apiKey: 'test-key',
      createClient: () => client,
    );
    await expectLater(
      planner.generate(start: plan.points.first, distance: 1200),
      throwsA(
        isA<RoutePlanningException>().having(
          (error) => error.message,
          'message',
          'Cannot reach the routing service. Check your connection.',
        ),
      ),
    );
    expect(client.closed, isTrue);
  });

  test(
    'a valid candidate survives a later rate limit or server error',
    () async {
      for (final status in [429, 500]) {
        var calls = 0;
        final client = TrackedClient((_) async {
          calls++;
          return calls == 1
              ? http.Response(routeResponse(plan), 200)
              : http.Response('upstream failure', status);
        });
        final planner = OpenRouteServicePlanner(
          apiKey: 'test-key',
          createClient: () => client,
        );
        final result = await planner.generate(
          start: plan.points.first,
          distance: 1200,
          exploredCells: {'previously-explored'},
        );
        expect(result.points, plan.points);
        expect(calls, 2);
        expect(client.closed, isTrue);
      }
    },
  );

  test('cancellation also ignores a late network failure', () async {
    final response = Completer<http.Response>();
    final started = Completer<void>();
    final client = TrackedClient((_) {
      started.complete();
      return response.future;
    });
    final planner = OpenRouteServicePlanner(
      apiKey: 'test-key',
      createClient: () => client,
    );
    final result = planner.generate(start: plan.points.first, distance: 1200);
    final assertion = expectLater(result, throwsA(isA<PlanningCancelled>()));
    await started.future;
    planner.cancel();
    response.completeError(http.ClientException('Connection closed'));
    await assertion;
    expect(client.closed, isTrue);
  });

  test(
    'cancel closes the client and stale success cannot become a route',
    () async {
      final response = Completer<http.Response>();
      final started = Completer<void>();
      final client = TrackedClient((_) {
        started.complete();
        return response.future;
      });
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => client,
      );
      final result = planner.generate(start: plan.points.first, distance: 1200);
      await started.future;
      planner.cancel();
      final assertion = expectLater(result, throwsA(isA<PlanningCancelled>()));
      response.complete(http.Response(routeResponse(plan), 200));
      await assertion;
      expect(client.closed, isTrue);
    },
  );

  test(
    'timeout closes owned client and disposed planner cannot start',
    () async {
      final client = TrackedClient((_) => Completer<http.Response>().future);
      final planner = OpenRouteServicePlanner(
        apiKey: 'test-key',
        createClient: () => client,
        timeout: const Duration(milliseconds: 5),
      );
      await expectLater(
        planner.generate(start: plan.points.first, distance: 1200),
        throwsA(isA<RoutePlanningException>()),
      );
      expect(client.closed, isTrue);
      planner.dispose();
      expect(planner.available, isFalse);
    },
  );
}

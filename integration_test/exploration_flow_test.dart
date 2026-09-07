import 'dart:convert';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/composition.dart';
import 'package:footprint/app/config/application_config.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:footprint/app/resource_disposer.dart';
import 'package:footprint/app/root_context.dart';
import 'package:integration_test/integration_test.dart';
import 'package:map/map.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_planning/route_planning.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../packages/domain_models/test/walk_fixtures.dart';
import '../packages/features/map/test/fakes.dart';
import '../test/design_golden_test.dart' show tileFixture;

class WalkFixtureConfig extends ApplicationConfig {
  const WalkFixtureConfig(this.port);
  final int port;
  @override
  MapConfig get map => MapConfig(
    urlTemplate: 'http://127.0.0.1:$port/{z}/{x}/{y}.png',
    attribution: 'Fixture map',
  );
}

Future<void> until(WidgetTester tester, bool Function() ready) async {
  for (var i = 0; i < 100; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (ready()) return;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  fail('Timed out waiting for the walking workflow.');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  for (final mode in RoutePlanMode.values) {
    testWidgets(
      'generate ${mode.name} via HeiGIT HTTP, walk checkpoints, save and reopen native progress',
      (tester) async {
        final directory = await Directory.systemTemp.createTemp(
          'footprint-walk-flow-',
        );
        final tile = await tileFixture();
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final plan = mode == RoutePlanMode.loop
            ? loopPlan(distance: 3000)
            : pointToPointPlan();
        Map<String, dynamic>? requestedRoute;
        String? requestedMethod;
        final requests = server.listen((request) async {
          if (request.uri.path == '/heigit') {
            requestedMethod = request.method;
            requestedRoute = jsonDecode(
              await utf8.decoder.bind(request).join(),
            ) as Map<String, dynamic>;
            request.response.headers.contentType = ContentType.json;
            request.response.write(
              jsonEncode({
                'features': [
                  {
                    'geometry': {
                      'type': 'LineString',
                      'coordinates': plan.points
                          .map((p) => p.coordinates)
                          .toList(),
                    },
                  },
                ],
              }),
            );
          } else {
            request.response.headers.contentType = ContentType('image', 'png');
            request.response.headers.set(
              HttpHeaders.cacheControlHeader,
              'max-age=3600',
            );
            request.response.headers.set(
              HttpHeaders.dateHeader,
              HttpDate.format(DateTime.now().toUtc()),
            );
            request.response.add(tile);
          }
          await request.response.close();
        });
        final storage = await SqliteStorage.open(
          path: '${directory.path}/routes.db',
        );
        final now = DateTime.now();
        LocationDM fix(GeoPoint point, int seconds) => LocationDM(
          id: 'native:$seconds',
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: now.add(Duration(seconds: seconds)),
          accuracy: 5,
          speed: 0.8,
          speedAccuracy: 0.2,
        );
        final location = FakeLocationService()
          ..lastLocation = fix(plan.points.first, -600)
          ..currentFix = fix(plan.points.first, 0);
        final routes = RoutesRepository(sqliteStorage: storage);
        final walks = WalksRepository(storage: storage);
        final photos = FakeRoutePhotosRepository();
        final recording = RecordingService(
          locationService: location,
          routesRepository: routes,
        );
        final planner = OpenRouteServicePlanner(
          endpoint: Uri.parse('http://127.0.0.1:${server.port}/heigit'),
        );
        final resources = ResourceDisposer()
          ..add('storage', storage.close)
          ..add('location', location.dispose)
          ..add('planner', () async => planner.dispose())
          ..add('recording', recording.dispose);
        addTearDown(() async {
          await resources.dispose();
          await requests.cancel();
          await server.close(force: true);
          await directory.delete(recursive: true);
        });
        await recording.initialize();
        final dependencies = DependenciesContainer(
          foregroundLocationService: location,
          sqliteStorage: storage,
          routesRepository: routes,
          photosRepository: photos,
          geocodingManager: FakeGeocodingManager(),
          recordingService: recording,
          walksRepository: walks,
          routePlanner: planner,
          config: WalkFixtureConfig(server.port),
          resources: resources,
        );
        await tester.pumpWidget(
          RootContext(
            compositionResult: CompositionResult(
              dependencies: dependencies,
              millisecondsSpent: 0,
            ),
          ),
        );
        await until(
          tester,
          () => find.text('Explore').hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Explore'));
        await until(
          tester,
          () => find.text('Generate route').hitTestable().evaluate().isNotEmpty,
        );
        await tester.pumpAndSettle();
        if (mode == RoutePlanMode.pointToPoint) {
          await until(
            tester,
            () => find.text('A to B').hitTestable().evaluate().isNotEmpty,
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('A to B'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Destination'));
          await tester.pumpAndSettle();
          expect(find.byType(BottomSheet), findsNothing);
          final map = tester
              .widget<FlutterMap>(find.byType(FlutterMap))
              .mapController!;
          final bounds = tester.getRect(find.byType(FlutterMap));
          final pointOffset = Offset(0, -bounds.height * 0.2);
          map.move(plan.points.last.latLng, 15, offset: pointOffset);
          await tester.pumpAndSettle();
          await tester.tapAt(bounds.center + pointOffset);
          await tester.pump(const Duration(milliseconds: 350));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await until(
          tester,
          () => find.text('Start walk').hitTestable().evaluate().isNotEmpty,
        );
        expect(requestedMethod, 'POST');
        if (mode == RoutePlanMode.loop) {
          expect(requestedRoute?['options']['round_trip']['length'], 3000);
        } else {
          expect(requestedRoute?['options']['round_trip'], isNull);
          expect(requestedRoute?['coordinates'], hasLength(2));
          final destination = requestedRoute!['coordinates'].last as List;
          expect(destination[0], closeTo(plan.points.last.longitude, 0.00001));
          expect(destination[1], closeTo(plan.points.last.latitude, 0.00001));
        }
        expect(location.currentLocationRequests, 1);
        expect(recording.state.isRecording, isFalse);
        await tester.tap(find.byTooltip('Clear route'));
        await until(
          tester,
          () => find.text('Generate route').hitTestable().evaluate().isNotEmpty,
        );
        expect(find.text('Start walk'), findsNothing);
        expect(await routes.getRoutes(), isEmpty);
        expect(recording.state.isRecording, isFalse);
        await tester.tap(find.text('Generate route'));
        await until(
          tester,
          () => find.text('Start walk').hitTestable().evaluate().isNotEmpty,
        );
        await tester.tap(find.text('Start walk'));
        await until(
          tester,
          () => find.text('Stop recording').hitTestable().evaluate().isNotEmpty,
        );
        final id = recording.state.routeId!;
        expect((await walks.getProgress(id))!.reached, 0);
        for (final (i, checkpoint) in plan.checkpoints.indexed) {
          location.send(fix(checkpoint.point, (i + 1) * 45));
          location.send(fix(checkpoint.point, (i + 1) * 45 + 2));
          await until(
            tester,
            () => recording.state.points.length >= 1 + (i + 1) * 2,
          );
        }
        await until(
          tester,
          () => find
              .text(plan.isLoop ? 'Loop completed' : 'Walk completed')
              .evaluate()
              .isNotEmpty,
        );
        await tester.tap(find.text('Stop recording'));
        await until(
          tester,
          () => find.text('SAVE ROUTE').evaluate().isNotEmpty,
        );
        expect((await walks.getProfile()).completedWalks, 1);
        expect(
          (await walks.getProfile()).achievements,
          contains(ExplorationAchievement.firstWalk),
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await resources.dispose();
        final reopened = await SqliteStorage.open(
          path: '${directory.path}/routes.db',
        );
        try {
          final progress = (await WalksRepository(storage: reopened)
              .getProgress(id))!;
          expect(progress.completed, isTrue);
          expect(progress.recording, isFalse);
          expect(progress.plan.points, plan.points);
          expect(progress.plan.mode, mode);
        } finally {
          await reopened.close();
        }
      },
    );
  }
}

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/composition.dart';
import 'package:footprint/app/config/application_config.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:footprint/app/resource_disposer.dart';
import 'package:footprint/app/root_context.dart';
import 'package:integration_test/integration_test.dart';
import 'package:map/map.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:recording_service/recording_service.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../packages/features/map/test/fakes.dart';

Future<Uint8List> fixtureTile() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(Colors.blue, BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

Future<void> pumpUntil(WidgetTester tester, bool Function() ready) async {
  for (var attempt = 0; attempt < 100 && !ready(); attempt++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(ready(), isTrue);
}

class FixtureConfig extends ApplicationConfig {
  const FixtureConfig(this.port);
  final int port;
  @override
  MapConfig get map => MapConfig(
    urlTemplate: 'http://127.0.0.1:$port/{z}/{x}/{y}.png',
    attribution: 'Test tiles',
    attributionUrl: 'https://example.com',
  );
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native database survives recording, navigation and reopening', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'footprint-integration-',
    );
    final path = '${directory.path}/footprint.db';
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final pixel = await fixtureTile();
    var failTiles = true;
    final requests = server.listen((request) async {
      request.response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
      if (failTiles) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType('image', 'png');
      request.response.add(pixel);
      await request.response.close();
    });
    final storage = await SqliteStorage.open(path: path);
    final service = FakeLocationService()..lastLocation = location(1);
    final repository = RoutesRepository(sqliteStorage: storage);
    final recording = RecordingService(
      locationService: service,
      routesRepository: repository,
    );
    final resources = ResourceDisposer()
      ..add('database', storage.close)
      ..add('location', service.dispose)
      ..add('recording', recording.dispose);
    addTearDown(() async {
      await resources.dispose();
      await requests.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final dependencies = DependenciesContainer(
      foregroundLocationService: service,
      sqliteStorage: storage,
      routesRepository: repository,
      geocodingManager: FakeGeocodingManager(),
      recordingService: recording,
      config: FixtureConfig(server.port),
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
    await tester.pumpAndSettle();
    await pumpUntil(
      tester,
      () => find.text('Map tiles could not be loaded.').evaluate().isNotEmpty,
    );
    failTiles = false;
    await tester.tap(find.text('Retry'));
    await pumpUntil(
      tester,
      () => tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((widget) => widget.image?.width == 256),
    );
    expect(find.text('Map tiles could not be loaded.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Record route'));
    await tester.pumpAndSettle();
    service.send(location(2));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Routes'));
    await tester.pumpAndSettle();
    expect(find.text('Recording'), findsOneWidget);
    service.send(location(3));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Back to map'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Stop recording'));
    await tester.pumpAndSettle();
    final route = (await repository.getRoutes()).single;
    expect((await repository.getRoute(route.id))!.routePoints, hasLength(3));
    await tester.tap(find.byTooltip('Routes'));
    await tester.pumpAndSettle();
    expect(find.text('Saved'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    await resources.dispose();
    final reopened = await SqliteStorage.open(path: path);
    try {
      final saved = (await reopened.routes.getById(route.id))!;
      expect(saved.status, 'completed');
      expect(saved.routePoints, hasLength(3));
    } finally {
      await reopened.close();
    }
  });
}

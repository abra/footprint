import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:route_planning/route_planning.dart';
import 'package:route_snapshots/route_snapshots.dart';
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
import 'package:statistics/src/statistics_view.dart';
import 'package:route_list/src/route_thumbnail.dart';

import '../packages/features/map/test/fakes.dart';
import '../packages/component_library/test/pump_map_ui.dart';

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

class FixturePhotoPicker implements PhotoPicker {
  FixturePhotoPicker(this.path);
  final String path;
  @override
  Future<String?> pick(PhotoSource source) async => path;
  @override
  Future<String?> recover() async => null;
}

class FilteredFixtureLocationService extends FakeLocationService {
  FilteredFixtureLocationService() {
    lastLocation = _filter.add(_measured(location(1)));
  }
  final _filter = LocationFilter();

  static LocationDM _measured(LocationDM point) => LocationDM(
    id: point.id,
    latitude: point.latitude,
    longitude: point.longitude,
    timestamp: point.timestamp,
    accuracy: 5,
    speed: 11.1,
    speedAccuracy: 0.2,
  );

  @override
  void send(LocationDM value) {
    final filtered = _filter.add(
      value.accuracy == null ? _measured(value) : value,
    );
    if (filtered != null) super.send(filtered);
  }
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
    final photoFile = await File('${directory.path}/source.png')
        .writeAsBytes(pixel);
    final photos = RoutePhotosRepository(
      dao: storage.routePhotos,
      picker: FixturePhotoPicker(photoFile.path),
      files: LocalPhotoFiles(
        directory: () async => Directory('${directory.path}/photos'),
      ),
    );
    final service = FilteredFixtureLocationService();
    final repository = RoutesRepository(sqliteStorage: storage, photos: photos);
    final recording = RecordingService(
      locationService: service,
      routesRepository: repository,
    );
    final snapshots = RouteSnapshotRepository(
      config: FixtureConfig(server.port).map,
      store: FileSnapshotStore(
        directory: () async => Directory('${directory.path}/snapshots'),
      ),
    );
    final resources = ResourceDisposer()
      ..add('database', storage.close)
      ..add('photos', photos.dispose)
      ..add('location', service.dispose)
      ..add('snapshots', snapshots.dispose)
      ..add('recording', recording.dispose);
    addTearDown(() async {
      await resources.dispose();
      await requests.cancel();
      await server.close(force: true);
      await directory.delete(recursive: true);
    });
    final dependencies = DependenciesContainer(
      routeSnapshots: snapshots,
      routePlanner: OpenRouteServicePlanner(),
      walksRepository: WalksRepository(storage: storage),
      photosRepository: photos,
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
    await pumpMapUi(tester);
    await pumpUntil(
      tester,
      () => find.text('Map tiles could not be loaded.').evaluate().isNotEmpty,
    );
    failTiles = false;
    await tester.tap(find.byTooltip('Retry'));
    await pumpUntil(
      tester,
      () => tester
          .widgetList<RawImage>(find.byType(RawImage))
          .any((widget) => widget.image?.width == 256),
    );
    expect(find.text('Map tiles could not be loaded.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Record route'));
    await pumpMapUi(tester);
    final statsPanel = find.byKey(const ValueKey('recording-stats-panel'));
    await tester.tap(statsPanel);
    await pumpMapUi(tester);
    expect(tester.widget<RouteStats>(find.byType(RouteStats)).columns, 2);
    service.send(location(2));
    await pumpMapUi(tester);
    await tester.tap(find.byTooltip('Add route photo'));
    await pumpMapUi(tester);
    await tester.tap(find.text('Choose photo'));
    await pumpUntil(
      tester,
      () => tester
          .widgetList<RoutePhotoMarkers>(find.byType(RoutePhotoMarkers))
          .any((layer) => layer.photos.length == 1),
    );
    await tester.tap(find.byTooltip('Routes'));
    await pumpMapUi(tester);
    expect(find.text('Recording'), findsOneWidget);
    service.send(location(3));
    await pumpMapUi(tester);
    if (Platform.isIOS) {
      final size = tester.view.physicalSize / tester.view.devicePixelRatio;
      await tester.dragFrom(
        Offset(4, size.height / 2),
        Offset(size.width * 0.8, 0),
      );
    } else {
      await tester.tap(find.byTooltip('Back to map'));
    }
    await pumpMapUi(tester);
    expect(tester.widget<RouteStats>(find.byType(RouteStats)).columns, 2);
    await tester.tap(statsPanel);
    await pumpMapUi(tester);
    expect(tester.widget<RouteStats>(find.byType(RouteStats)).columns, isNull);
    final distanceBeforeStop =
        (await repository.getActiveRoute())!.metrics.distance;
    for (var step = 1; step <= 20; step++) {
      service.send(
        LocationDM(
          id: 'stationary:$step',
          latitude: location(3).latitude + (step.isEven ? 0.000005 : -0.000005),
          longitude: location(3).longitude,
          timestamp: location(3).timestamp.add(Duration(seconds: step * 30)),
          accuracy: 5,
          speed: 0,
          speedAccuracy: 0.2,
        ),
      );
    }
    await pumpUntil(tester, () => recording.state.points.length == 23);
    expect(
      (await repository.getActiveRoute())!.metrics.distance,
      distanceBeforeStop,
    );
    expect(recording.state.points.last.isStationary, isTrue);
    expect(recording.state.points.last.latitude, location(3).latitude);
    await tester.tap(find.text('Stop recording'));
    await pumpMapUi(tester);
    expect(find.text('Route saved'), findsOneWidget);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      '',
    );
    await tester.tap(find.byTooltip('Save route name'));
    await pumpMapUi(tester);
    expect(find.text('Record route'), findsOneWidget);
    expect(find.text('Last route'), findsOneWidget);
    final completedTrace = tester
        .widget<PolylineLayer>(
          find.byKey(const ValueKey('route-history-layer')),
        )
        .polylines
        .single;
    expect(completedTrace.color, AppTheme.route.withValues(alpha: 0.25));
    expect(completedTrace.strokeWidth, 4);
    await tester.tap(find.byTooltip('Hide last route'));
    await pumpMapUi(tester);
    expect(find.byKey(const ValueKey('route-history-layer')), findsNothing);
    expect(find.text('Last route'), findsNothing);
    final unnamed = (await repository.getRoutes()).single;
    expect(unnamed.name, isNull);
    expect(unnamed.status, Status.completed);
    final defaultTitle = RouteLabels.title(
      tester.element(find.byType(MapScreen)),
      unnamed,
    );
    await tester.tap(find.byTooltip('Routes'));
    await pumpMapUi(tester);
    expect(find.text(defaultTitle), findsOneWidget);
    final thumbnail = find.byType(RouteThumbnail);
    expect(
      find.descendant(of: thumbnail, matching: find.byType(FlutterMap)),
      findsNothing,
    );
    await pumpUntil(
      tester,
      () => tester
          .widgetList<RawImage>(
            find.descendant(of: thumbnail, matching: find.byType(RawImage)),
          )
          .any(
            (image) => image.image?.width == 720 && image.image?.height == 400,
          ),
    );
    final snapshotFiles = await Directory('${directory.path}/snapshots')
        .list()
        .toList();
    expect(
      snapshotFiles.where((entry) => entry.path.endsWith('.png')),
      isNotEmpty,
    );
    await tester.tap(find.text(defaultTitle));
    await pumpMapUi(tester);
    await tester.enterText(find.byType(EditableText), 'Morning walk');
    await tester.tap(find.byTooltip('Save route name'));
    await pumpMapUi(tester);
    await tester.tap(find.byTooltip('Back to map'));
    await pumpMapUi(tester);
    final route = (await repository.getRoutes()).single;
    final savedPhoto = (await photos.getPhotos(route.id)).single;
    expect(savedPhoto.latitude, location(2).latitude);
    expect(await File(savedPhoto.path).readAsBytes(), pixel);
    expect((await repository.getRoute(route.id))!.routePoints, hasLength(23));
    await tester.tap(find.byTooltip('Routes'));
    await pumpMapUi(tester);
    expect(find.text('Morning walk'), findsOneWidget);
    await tester.tap(find.byTooltip('Statistics'));
    await pumpMapUi(tester);
    await pumpUntil(
      tester,
      () => find.text('Recordings').evaluate().isNotEmpty,
    );
    await tester.tap(find.text('All time'));
    await pumpMapUi(tester);
    expect(find.byType(StatisticsView), findsOneWidget);
    final summary = (await repository.getRecordedSummaries()).single;
    expect(summary.id, route.id);
    expect(summary.distance, route.metrics.distance);
    expect(summary.duration, route.metrics.duration);
    await tester.tap(find.byTooltip('Back to routes'));
    await pumpMapUi(tester);
    expect(find.text('Morning walk'), findsOneWidget);
    await tester.tap(find.text('Morning walk'));
    await pumpMapUi(tester);
    await tester.tap(find.byTooltip('Route timeline'));
    await pumpMapUi(tester);
    await tester.scrollUntilVisible(find.text('Add comment'), 200);
    await pumpMapUi(tester);
    await tester.tap(find.text('Add comment'));
    await pumpMapUi(tester);
    await tester.enterText(
      find.byType(EditableText),
      'A photo from the morning walk',
    );
    await tester.ensureVisible(find.text('Save comment'));
    await pumpMapUi(tester);
    await tester.tap(find.text('Save comment'));
    await pumpUntil(
      tester,
      () => find.text('Photo comment').evaluate().isEmpty,
    );
    expect(find.text('A photo from the morning walk'), findsOneWidget);
    expect(
      (await photos.getPhotos(route.id)).single.comment,
      'A photo from the morning walk',
    );
    await tester.tap(find.byTooltip('Back to route'));
    await pumpMapUi(tester);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'Morning walk',
    );
    await tester.tap(find.byTooltip('Clear name'));
    await tester.tap(find.byTooltip('Save route name'));
    await pumpMapUi(tester);
    expect(find.text(defaultTitle), findsOneWidget);
    expect((await repository.getRoute(route.id))!.name, isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpMapUi(tester);
    await resources.dispose();
    final reopened = await SqliteStorage.open(path: path);
    try {
      final saved = (await reopened.routes.getById(route.id))!;
      expect(saved.status, 'completed');
      expect(saved.name, isNull);
      expect(saved.routePoints, hasLength(23));
      expect(saved.routePoints!.last.isStationary, isTrue);
      expect(saved.routePoints!.last.filteredSpeed, 0);
      expect(
        saved.routePoints!.last.rawLatitude,
        isNot(saved.routePoints!.last.latitude),
      );
      expect(await reopened.routePhotos.getForRoute(route.id), hasLength(1));
      expect(
        (await reopened.routePhotos.getForRoute(route.id)).single.comment,
        'A photo from the morning walk',
      );
      expect((await reopened.statistics.getSummaries()).single, summary);
      await reopened.routes.delete(route.id);
      expect(await reopened.statistics.getSummaries(), isEmpty);
    } finally {
      await reopened.close();
    }
  });
}

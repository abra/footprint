import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_state.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_details/route_details.dart';
import 'package:route_list/route_list.dart';

import '../packages/features/map/test/fakes.dart';

class FixtureTiles extends TileProvider {
  FixtureTiles(this.bytes);
  final Uint8List bytes;
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(bytes);
}

// A deliberately synthetic tile makes layout snapshots independent of providers.
Future<Uint8List> tileFixture() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawColor(const Color(0xFFF4F5F6), BlendMode.src);
  final paint = Paint()..color = const Color(0xFFE2E5E8);
  for (var x = 12.0; x < 256; x += 64) {
    for (var y = 12.0; y < 256; y += 64) {
      canvas.drawRect(Rect.fromLTWH(x, y, 40, 40), paint);
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(256, 256);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  picture.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List tile;
  setUpAll(() async {
    tile = await tileFixture();
    await (FontLoader('packages/component_library/RobotoCondensed')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/RobotoCondensed.ttf',
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  final start = DateTime(2026, 9, 6, 10);
  final points = [
    for (final (index, coordinates) in [
      (56.0, 60.0),
      (56.0005, 60.0),
      (56.0005, 60.0008),
      (56.001, 60.0008),
      (56.001, 60.0002),
    ].indexed)
      LocationDM(
        id: '$index',
        latitude: coordinates.$1,
        longitude: coordinates.$2,
        timestamp: start.add(Duration(minutes: index)),
      ),
  ];
  RouteDM route(int id) => RouteDM(
    id: id,
    name: id == 1
        ? 'Morning walk'
        : 'A route with a long name through the city park',
    startTime: start,
    endTime: start.add(const Duration(minutes: 5)),
    status: Status.completed,
    routePoints: [
      for (final (i, point) in points.indexed)
        RoutePointDM(
          id: i,
          routeId: id,
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: point.timestamp,
          address: '',
        ),
    ],
  );

  for (final (size, scale, variant) in [
    (const Size(428, 926), 1.0, 'phone'),
    (const Size(320, 568), 2.0, 'small_large_text'),
    (const Size(844, 390), 2.0, 'landscape_large_text'),
  ]) {
    for (final screen in [
      'idle',
      'recording',
      'recording_expanded',
      'recording_fast',
      'recording_fast_expanded',
      'recording_short_distance',
      'recording_short_distance_expanded',
      'saving',
      'routes',
      'photo',
    ]) {
      testWidgets('$screen design $variant', (tester) async {
        debugDisableShadows = false;
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          tester.view.padding = FakeViewPadding(
            top: variant == 'phone' ? 59 : 0,
            bottom: variant == 'phone' ? 34 : 0,
          );
          addTearDown(tester.view.resetPadding);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final config = MapTileConfig(
            urlTemplate: 'https://fixture.example/{z}/{x}/{y}.png',
            attribution: 'Fixture tiles',
            attributionUrl: 'https://example.com',
            tileProviderFactory: () => FixtureTiles(tile),
          );
          final repository = FakeRoutesRepository()
            ..saved.addAll({1: route(1), 2: route(2)});
          final photo = RoutePhotoDM(
            id: 'fixture',
            routeId: 1,
            path: File('test/fixtures/route_photo.png').absolute.path,
            latitude: points[1].latitude,
            longitude: points[1].longitude,
            capturedAt: start,
          );
          final photos = FakeRoutePhotosRepository()..photos.add(photo);
          final service = FakeLocationService();
          final recording = RecordingService(
            locationService: service,
            routesRepository: repository,
          );
          final cubit = MapCubit(
            photosRepository: photos,
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
          );
          final isRecording = screen.startsWith('recording');
          final measured = RouteMetrics.fromLocations(
            points,
            endedAt: start.add(const Duration(minutes: 5)),
          );
          cubit.emit(
            MapState(
              location: points.last,
              locationLoading: false,
              address: '243 Deer Run Dr S, Ponte Vedra Beach, FL',
              points: isRecording ? points : [],
              isRecording: isRecording,
              routeId: isRecording ? 1 : null,
              photos: isRecording ? [photo] : [],
              metrics: switch (screen) {
                'recording_fast' || 'recording_fast_expanded' => RouteMetrics(
                  currentSpeed: 120 / 3.6,
                  distance: 119000,
                  duration: const Duration(hours: 1),
                  speedHistory: measured.speedHistory,
                ),
                'recording_short_distance' ||
                'recording_short_distance_expanded' => RouteMetrics(
                  currentSpeed: 116.9 / 3.6,
                  distance: 8800,
                  duration: const Duration(minutes: 4, seconds: 20),
                  speedHistory: measured.speedHistory,
                ),
                _ => measured,
              },
            ),
          );
          final Widget home = switch (screen) {
            'saving' => RouteDetailsScreen(
              photosRepository: photos,
              routeId: 1,
              repository: repository,
              config: config,
              justRecorded: true,
              onClosed: (_) {},
            ),
            'routes' => RouteListScreen(
              routesRepository: repository,
              config: config,
              onPageChangeRequested: () {},
              onRouteRequested: (_) async {},
            ),
            _ => BlocProvider.value(
              value: cubit,
              child: MapView(config: config, onRoutesRequested: () {}),
            ),
          };
          // Warm the cache before widgets start image loads in the fake zone.
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          await tester.runAsync(() async {
            final context = tester.element(find.byType(MaterialApp));
            await precacheImage(MemoryImage(tile), context);
            await precacheImage(
              ResizeImage(FileImage(File(photo.path)), width: 384),
              context,
            );
            await precacheImage(FileImage(File(photo.path)), context);
          });
          await tester.pumpWidget(
            RepaintBoundary(
              key: const ValueKey('design'),
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: home,
              ),
            ),
          );
          if (screen == 'photo') {
            unawaited(
              showRoutePhotoViewer(
                tester.element(find.byType(MapView)),
                photos: [photo],
                selected: photo,
              ),
            );
          }
          await tester.pumpAndSettle();
          if (screen.endsWith('expanded')) {
            await tester.tap(
              find.byKey(const ValueKey('recording-stats-panel')),
            );
            await tester.pumpAndSettle();
            expect(cubit.state.statsExpanded, isTrue);
          }
          expect(tester.takeException(), isNull);
          if (isRecording) {
            expect(
              tester
                  .getRect(find.byTooltip('Center on location'))
                  .overlaps(
                    tester.getRect(
                      find.widgetWithText(FilledButton, 'Stop recording'),
                    ),
                  ),
              isFalse,
            );
          }
          if (variant == 'phone') {
            await expectLater(
              find.byKey(const ValueKey('design')),
              matchesGoldenFile('goldens/$screen.png'),
            );
          }
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          await cubit.close();
          await tester.runAsync(() async {
            await recording.dispose();
            await service.dispose();
          });
        } finally {
          debugDisableShadows = true;
        }
      });
    }
  }
}

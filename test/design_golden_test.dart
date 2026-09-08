import 'dart:ui' as ui;
import 'dart:async';
import 'dart:io';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';

import '../packages/component_library/test/load_fonts.dart';

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
import 'package:route_snapshots/route_snapshots.dart';

import '../packages/route_snapshots/test/fakes.dart';

import '../packages/features/map/test/fakes.dart';
import '../packages/domain_models/test/walk_fixtures.dart' as walking;

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
    await loadAppFonts();
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
      'last_route',
      'recording',
      'recording_walk',
      'recording_expanded',
      'recording_fast',
      'recording_fast_expanded',
      'recording_short_distance',
      'recording_short_distance_expanded',
      'saving',
      'routes',
      'photo',
      'zoom_in_pressed',
      'zoom_out_pressed',
      'center_pressed',
      'recording_photo_pressed',
      'center_uncentered',
      'center_transition',
      'course_up',
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
          final snapshots = RouteSnapshotRepository(
            config: config,
            store: MemorySnapshotStore(),
          );
          addTearDown(snapshots.dispose);
          if (screen == 'routes') {
            await tester.runAsync(() async {
              for (final id in [1, 2]) {
                await snapshots.request(RouteSnapshotScene(route(id))).image;
              }
            });
          }
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
              points: isRecording || screen == 'last_route' ? points : [],
              isRecording: isRecording,
              walk: screen == 'recording_walk'
                  ? WalkProgress(
                      routeId: 1,
                      plan: walking.loopPlan(
                        start: GeoPoint(
                          points.first.latitude,
                          points.first.longitude,
                        ),
                      ),
                      reached: 1,
                      newCells: 4,
                      recording: true,
                    )
                  : null,
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
              snapshots: snapshots,
              onStatisticsRequested: () {},
              routesRepository: repository,
              config: config,
              onPageChangeRequested: () {},
              onRouteRequested: (_) async {},
            ),
            _ => BlocProvider.value(
              value: cubit,
              child: MapView(
                config: config,
                onRoutesRequested: () {},
                onExploreRequested: () {},
              ),
            ),
          };
          // Warm the cache before widgets start image loads in the fake zone.
          await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
          await tester.runAsync(() async {
            final context = tester.element(find.byType(MaterialApp));
            await precacheImage(MemoryImage(tile), context);
            if (screen == 'routes') {
              for (final id in [1, 2]) {
                final image = await snapshots
                    .request(RouteSnapshotScene(route(id)))
                    .image;
                if (context.mounted) {
                  await precacheImage(MemoryImage(image), context);
                }
              }
            }
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
                // Keep ink snapshots independent of asynchronous shader compilation.
                theme: screen.endsWith('_pressed')
                    ? AppTheme.light.copyWith(
                        splashFactory: InkRipple.splashFactory,
                      )
                    : AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    disableAnimations: screen != 'center_transition',
                  ),
                  child: AppTheme.builder(context, child),
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
          if (screen == 'center_transition') {
            await tester.pump();
            await tester.pump(const Duration(seconds: 1));
          } else {
            await tester.pumpAndSettle();
          }
          if (screen == 'center_uncentered' || screen == 'center_transition') {
            cubit.setCentered(false);
            await tester.pump();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 100));
            if (screen == 'center_transition') {
              final filled = tester.widget<FadeTransition>(
                find.byKey(const ValueKey('follow-active-opacity')),
              );
              expect(filled.opacity.value, inExclusiveRange(0, 1));
            }
          }
          if (screen == 'course_up') {
            final last = points.last;
            cubit.emit(
              cubit.state.copyWith(
                location: LocationDM(
                  id: 'east',
                  latitude: last.latitude,
                  longitude: last.longitude + 0.0002,
                  timestamp: last.timestamp.add(const Duration(seconds: 1)),
                ),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byTooltip('Follow direction of travel'));
            await tester.pumpAndSettle();
            expect(find.byTooltip('Keep north up'), findsOneWidget);
            expect(find.byIcon(Icons.navigation_rounded), findsOneWidget);
          }
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
                  .getRect(find.byKey(const ValueKey('map-follow-button')))
                  .overlaps(
                    tester.getRect(
                      find.widgetWithText(AppButton, 'Stop recording'),
                    ),
                  ),
              isFalse,
            );
          }
          final pressedTooltip = switch (screen) {
            'zoom_in_pressed' => 'Zoom in',
            'zoom_out_pressed' => 'Zoom out',
            'center_pressed' => 'Follow direction of travel',
            'recording_photo_pressed' => 'Add route photo',
            _ => null,
          };
          TestGesture? press;
          if (pressedTooltip != null) {
            press = await tester.startGesture(
              tester.getCenter(find.byTooltip(pressedTooltip)),
            );
            await tester.pump(const Duration(milliseconds: 100));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            final button = find.byWidgetPredicate(
              (widget) =>
                  widget is AppIconButton && widget.tooltip == pressedTooltip,
            );
            expect(tester.getSize(button), const Size(48, 48));
            expect(
              find.descendant(of: button, matching: find.byType(FButton)),
              findsOneWidget,
            );
          }
          if (variant == 'phone' ||
              screen == 'idle' ||
              screen == 'last_route' ||
              screen == 'recording' ||
              screen == 'course_up' ||
              (variant == 'landscape_large_text' &&
                  screen.startsWith('zoom_'))) {
            final suffix = variant == 'phone' ? '' : '_$variant';
            await expectLater(
              find.byKey(const ValueKey('design')),
              matchesGoldenFile('goldens/$screen$suffix.png'),
            );
          }
          await press?.cancel();
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

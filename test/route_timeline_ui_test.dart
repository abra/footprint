import 'dart:io';
import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:route_details/route_details.dart';

import '../packages/component_library/test/load_fonts.dart';
import '../packages/features/map/test/fakes.dart';
import '../packages/features/route_details/test/timeline_fakes.dart';
import 'design_golden_test.dart' show FixtureTiles, tileFixture;

void main() {
  late Uint8List tile;
  setUpAll(() async {
    tile = await tileFixture();
    await loadAppFonts();
  });

  Future<void> open(
    WidgetTester tester,
    CommentPhotosRepository photos, {
    double scale = 1,
    RouteDM? route,
  }) async {
    final repository = FakeRoutesRepository()
      ..saved[1] = route ?? timelineRoute();
    addTearDown(photos.dispose);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.runAsync(() async {
      final context = tester.element(find.byType(MaterialApp));
      await precacheImage(MemoryImage(tile), context);
      for (final photo in photos.photos) {
        if (await File(photo.path).exists()) {
          await precacheImage(
            ResizeImage(FileImage(File(photo.path)), width: 384),
            context,
          );
          await precacheImage(FileImage(File(photo.path)), context);
        }
      }
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('timeline-design'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: AppTheme.builder(context, child),
          ),
          home: RouteTimelineScreen(
            routeId: 1,
            repository: repository,
            photosRepository: photos,
            config: MapTileConfig(
              urlTemplate: 'https://fixture.example/{z}/{x}/{y}.png',
              attribution: 'Fixture tiles',
              attributionUrl: 'https://example.com',
              tileProviderFactory: () => FixtureTiles(tile),
            ),
            onBack: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  RoutePhotoDM fixturePhoto({String comment = ''}) => RoutePhotoDM(
    id: 'photo',
    routeId: 1,
    path: File('test/fixtures/route_photo.png').absolute.path,
    latitude: 56.0005,
    longitude: 60,
    capturedAt: timelineStart.add(const Duration(minutes: 30)),
    comment: comment,
  );

  testWidgets('timeline edits, reopens and clears a persisted photo comment', (
    tester,
  ) async {
    final photos = CommentPhotosRepository()..photos.add(fixturePhoto());
    await open(tester, photos);
    await tester.scrollUntilVisible(find.text('Add comment'), 240);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add comment'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(EditableText),
      'A quiet spot by the river',
    );
    await tester.tap(find.text('Save comment'));
    await tester.pumpAndSettle();
    expect(find.text('A quiet spot by the river'), findsOneWidget);
    expect(photos.photos.single.comment, 'A quiet spot by the river');
    await tester.tap(find.text('Edit comment'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).controller.text,
      'A quiet spot by the river',
    );
    await tester.enterText(find.byType(EditableText), '');
    await tester.tap(find.text('Save comment'));
    await tester.pumpAndSettle();
    expect(find.text('Add comment'), findsOneWidget);
    expect(photos.photos.single.comment, '');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'no photos still shows start and finish, including unavailable legacy timestamps',
    (tester) async {
      await open(
        tester,
        CommentPhotosRepository(),
        route: RouteDM(
          id: 1,
          startTime: timelineStart,
          status: Status.completed,
        ),
      );
      await tester.scrollUntilVisible(find.text('Finish'), 200);
      await tester.pumpAndSettle();
      expect(find.text('Time unavailable'), findsOneWidget);
      expect(find.text('No route points'), findsOneWidget);
      expect(find.text('Add comment'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'timeline endpoints use the same meanings and colors as the map',
    (tester) async {
      await open(tester, CommentPhotosRepository());
      for (final (key, label, icon, color) in [
        ('start', 'Start', FLucideIcons.flag, AppTheme.coral),
        ('finish', 'Finish', Icons.location_on, AppTheme.success),
      ]) {
        await tester.scrollUntilVisible(find.text(label), 180);
        await tester.pumpAndSettle();
        final event = find.byKey(ValueKey(key));
        final symbol = find.descendant(of: event, matching: find.byType(Icon));
        expect(tester.widget<Icon>(symbol).icon, icon);
        expect(tester.widget<Icon>(symbol).color, color);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
  );

  testWidgets('photo read failures can be retried without hiding the route', (
    tester,
  ) async {
    final photos = CommentPhotosRepository()..failRead = true;
    await open(tester, photos);
    expect(find.text('Morning walk'), findsOneWidget);
    expect(find.text('Photos could not be loaded.'), findsOneWidget);
    photos
      ..failRead = false
      ..photos.add(fixturePhoto());
    await tester.ensureVisible(find.byTooltip('Retry photos'));
    await tester.tap(find.byTooltip('Retry photos'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add comment'), 200);
    await tester.pumpAndSettle();
    expect(find.text('Photos could not be loaded.'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  for (final (size, scale, name) in [
    (const Size(428, 926), 1.0, 'phone'),
    (const Size(320, 568), 2.0, 'small_large_text'),
    (const Size(844, 390), 2.0, 'landscape_large_text'),
  ]) {
    testWidgets('timeline and comment sheet layout $name', (tester) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final photos = CommentPhotosRepository()
          ..photos.add(
            fixturePhoto(
              comment:
                  'A quiet spot by the river. Stopped here on the way back.',
            ),
          );
        await open(tester, photos, scale: scale);
        await tester.scrollUntilVisible(find.text('Edit comment'), 200);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('timeline-design')),
          matchesGoldenFile('goldens/timeline_$name.png'),
        );
        await tester.tap(find.text('Edit comment'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byType(EditableText),
          'A new comment\nWith a second line',
        );
        await tester.ensureVisible(find.text('Save comment'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await expectLater(
          find.byKey(const ValueKey('timeline-design')),
          matchesGoldenFile('goldens/photo_comment_$name.png'),
        );
        await tester.tap(find.text('Save comment'));
        await tester.pumpAndSettle();
        expect(
          photos.photos.single.comment,
          'A new comment\nWith a second line',
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import '../packages/component_library/test/load_fonts.dart';
import 'design_golden_test.dart' show FixtureTiles, tileFixture;

void main() {
  late Uint8List tile;
  setUpAll(() async {
    await loadAppFonts();
    tile = await tileFixture();
  });

  for (final (size, name) in [
    (const Size(48, 48), 'button'),
    (const Size(48, 97), 'toolbar'),
    (const Size(300, 120), 'panel'),
  ]) {
    testWidgets('$name surface is borderless with a soft exterior shadow', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 300);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        final boundaryKey = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              builder: AppTheme.builder,
              home: Scaffold(
                backgroundColor: Colors.white,
                body: Center(
                  child: MapSurface(child: SizedBox.fromSize(size: size)),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final surface = find.byType(MapSurface);
        final material = tester.widget<Material>(
          find.descendant(of: surface, matching: find.byType(Material)).first,
        );
        final decoration =
            tester
                    .widget<DecoratedBox>(
                      find
                          .descendant(
                            of: surface,
                            matching: find.byType(DecoratedBox),
                          )
                          .first,
                    )
                    .decoration
                as ShapeDecoration;
        expect(material.shape, AppTheme.controlShape);
        expect(material.clipBehavior, Clip.antiAlias);
        expect(decoration.shape, material.shape);
        final bounds = tester.getRect(surface);
        expect(bounds.size, size);

        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        addTearDown(image.dispose);
        final pixels = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        int red(Offset point) => pixels.getUint8(
          (point.dy.floor() * image.width + point.dx.floor()) * 4,
        );

        expect(red(Offset(bounds.left + 1, bounds.center.dy)), 255);
        final shadow = red(bounds.bottomCenter + const Offset(0, 2));
        expect(shadow, inExclusiveRange(220, 250));
        expect(
          red(bounds.bottomCenter + const Offset(0, 16)),
          greaterThan(shadow),
        );
        expect(red(bounds.bottomCenter + const Offset(0, 40)), 255);
        await expectLater(
          image,
          matchesGoldenFile('goldens/map_surface_$name.png'),
        );
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }

  for (final size in [const Size(288, 160), const Size(700, 300)]) {
    testWidgets(
      'preview retry uses the shared surface with an inset at $size',
      (tester) async {
        final start = DateTime(2026, 9, 9, 10);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: AppTheme.builder,
            home: Scaffold(
              body: Center(
                child: SizedBox.fromSize(
                  size: size,
                  child: RoutePreview(
                    route: RouteDM(
                      id: 1,
                      startTime: start,
                      endTime: start.add(const Duration(minutes: 1)),
                      status: Status.completed,
                      routePoints: [
                        RoutePointDM(
                          id: 1,
                          routeId: 1,
                          latitude: 56,
                          longitude: 60,
                          timestamp: start,
                          address: '',
                        ),
                      ],
                    ),
                    config: MapTileConfig(
                      urlTemplate: 'https://fixture.example/{z}/{x}/{y}.png',
                      tileProviderFactory: () => FixtureTiles(tile),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final previousMapKey = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .key;
        tester.widget<MapTiles>(find.byType(MapTiles)).onError();
        await tester.pumpAndSettle();
        final retry = find.byTooltip('Retry map tiles');
        expect(retry.hitTestable(), findsOneWidget);
        expect(
          find.ancestor(of: retry, matching: find.byType(MapSurface)),
          findsOneWidget,
        );
        final bounds = tester.getRect(find.byType(RoutePreview));
        final button = tester.getRect(retry);
        expect(button.size, const Size(48, 48));
        expect(bounds.right - button.right, 16);
        expect(button.top - bounds.top, 16);
        await tester.tap(retry);
        await tester.pumpAndSettle();
        expect(retry, findsNothing);
        expect(
          tester.widget<FlutterMap>(find.byType(FlutterMap)).key,
          isNot(previousMapKey),
        );
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
      },
    );
  }
}

import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../packages/component_library/test/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final modal in [false, true]) {
    final scenario = modal ? 'modal' : 'white_background';
    testWidgets('sheet shadow remains visible outside its bounds: $scenario', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
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
                body: modal
                    ? const SizedBox.expand()
                    : const Align(
                        alignment: Alignment.bottomCenter,
                        child: AppSheet(
                          child: SizedBox(width: double.infinity, height: 240),
                        ),
                      ),
              ),
            ),
          ),
        );

        Future<String?>? result;
        if (modal) {
          result = showAppActionSheet<String>(
            tester.element(find.byType(Scaffold)),
            title: 'Sort routes',
            actions: const [
              SheetAction(
                value: 'newest',
                label: 'Newest first',
                icon: FLucideIcons.arrowDown,
                selected: true,
              ),
              SheetAction(
                value: 'name',
                label: 'Name',
                icon: FLucideIcons.arrowDownAZ,
              ),
            ],
          );
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final bounds = tester.getRect(find.byType(AppSheet));
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        addTearDown(image.dispose);
        final pixels = (await tester.runAsync(
          () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
        ))!;
        int redAboveSheet(int distance) {
          final x = bounds.center.dx.floor();
          final y = bounds.top.floor() - distance;
          return pixels.getUint8((y * image.width + x) * 4);
        }

        // Inspect the exterior, which a golden cropped to AppSheet would omit.
        final background = redAboveSheet(48);
        final nearEdge = redAboveSheet(2);
        expect(nearEdge, lessThan(background - 5));
        expect(nearEdge, greaterThan(background - 35));
        expect(redAboveSheet(12), greaterThan(nearEdge));
        if (!modal) expect(background, 255);
        await expectLater(
          image,
          matchesGoldenFile('goldens/sheet_shadow_$scenario.png'),
        );

        if (modal) {
          await tester.tapAt(Offset(bounds.center.dx, bounds.top - 24));
          await tester.pumpAndSettle();
          expect(await result, isNull);
          expect(find.byType(AppSheet), findsNothing);
          expect(tester.takeException(), isNull);
        }
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}

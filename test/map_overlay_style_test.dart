import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import '../packages/component_library/test/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets('arrow shadow stays centered on its silhouette at every heading', (
    tester,
  ) async {
    debugDisableShadows = false;
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(160, 160);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final position = ValueNotifier<LatLng?>(const LatLng(56, 60));
    final heading = ValueNotifier<double?>(0);
    final map = MapController();
    const key = ValueKey('centered-shadow');
    Widget scene(Widget layer, {required bool shadowOnly}) => MaterialApp(
      home: RepaintBoundary(
        key: key,
        child: IconTheme(
          // Hide only the fill, leaving the production glyph's shadow visible.
          data: IconThemeData(opacity: shadowOnly ? 0 : 1),
          child: FlutterMap(
            mapController: map,
            options: const MapOptions(
              initialCenter: LatLng(56, 60),
              initialZoom: 2,
              backgroundColor: Colors.transparent,
            ),
            children: [layer],
          ),
        ),
      ),
    );
    try {
      for (final zoom in [2.0, 19.0]) {
        for (final course in [0.0, 45.0, 90.0, 180.0, 270.0]) {
          heading.value = course;
          await tester.pumpWidget(
            scene(
              CurrentLocationLayer(position: position, heading: heading),
              shadowOnly: true,
            ),
          );
          map.move(position.value!, zoom);
          await tester.pumpAndSettle();
          final arrow = tester.widget<Icon>(
            find.byIcon(Icons.navigation_rounded),
          );
          final shadow = await _pixels(tester, key);
          await tester.pumpWidget(
            scene(
              MarkerLayer(
                markers: [
                  Marker(
                    point: position.value!,
                    width: 40,
                    height: 40,
                    child: Center(
                      child: Transform.rotate(
                        angle: course * math.pi / 180,
                        child: Icon(
                          arrow.icon,
                          size: arrow.size,
                          color: arrow.color,
                          applyTextScaling: false,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              shadowOnly: false,
            ),
          );
          await tester.pumpAndSettle();
          final silhouette = await _pixels(tester, key);
          // Blurring preserves the alpha centroid; a directional offset moves
          // it. Compare to the actual glyph, whose centroid is not its anchor.
          expect(
            (_alphaCenter(shadow, 160) - _alphaCenter(silhouette, 160))
                .distance,
            lessThan(0.4),
            reason: 'Shadow offset at zoom $zoom, heading $course',
          );
          expect(tester.binding.transientCallbackCount, 0);
        }
      }
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      position.dispose();
      heading.dispose();
      map.dispose();
      debugDisableShadows = true;
    }
  });

  for (final (name, background) in [
    ('light', const Color(0xFFF3F5F4)),
    ('dark', const Color(0xFF29313B)),
  ]) {
    for (final zoom in [2.0, 13.0, 19.0]) {
      testWidgets(
        'arrow has a visible, restrained shadow on $name at zoom $zoom',
        (tester) async {
          debugDisableShadows = false;
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = const Size(160, 160);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final position = ValueNotifier<LatLng?>(const LatLng(56, 60));
          final heading = ValueNotifier<double?>(45);
          final map = MapController();
          const key = ValueKey('arrow-style');
          Widget scene(Widget marker) => MaterialApp(
            home: RepaintBoundary(
              key: key,
              child: FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: position.value!,
                  initialZoom: zoom,
                  backgroundColor: background,
                ),
                children: [marker],
              ),
            ),
          );
          try {
            await tester.pumpWidget(
              scene(CurrentLocationLayer(position: position, heading: heading)),
            );
            await tester.pumpAndSettle();
            final arrow = tester.widget<Icon>(
              find.byIcon(Icons.navigation_rounded),
            );
            await expectLater(
              find.byKey(key),
              matchesGoldenFile(
                'goldens/location_arrow_${name}_${zoom.toInt()}.png',
              ),
            );
            final shaded = await _pixels(tester, key);
            // Compare with the same glyph without shadows to measure only the
            // visible shadow outside its silhouette, not the purple fill.
            await tester.pumpWidget(
              scene(
                MarkerLayer(
                  markers: [
                    Marker(
                      point: position.value!,
                      width: 40,
                      height: 40,
                      child: Center(
                        child: Transform.rotate(
                          angle: math.pi / 4,
                          child: Icon(
                            arrow.icon,
                            size: arrow.size,
                            color: arrow.color,
                            applyTextScaling: false,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
            await tester.pumpAndSettle();
            final plain = await _pixels(tester, key);
            final rgb = [
              background.r,
              background.g,
              background.b,
            ].map((channel) => (channel * 255).round()).toList();
            var shadowPixels = 0;
            var strongest = 0;
            for (var offset = 0; offset < shaded.length; offset += 4) {
              if (plain[offset] != rgb[0] ||
                  plain[offset + 1] != rgb[1] ||
                  plain[offset + 2] != rgb[2]) {
                continue;
              }
              var darkening = 0;
              for (var channel = 0; channel < 3; channel++) {
                darkening = math.max(
                  darkening,
                  plain[offset + channel] - shaded[offset + channel],
                );
              }
              if (darkening > 0) shadowPixels++;
              strongest = math.max(strongest, darkening);
            }
            expect(shadowPixels, greaterThan(25));
            expect(
              strongest,
              name == 'light'
                  ? inInclusiveRange(5, 40)
                  : inInclusiveRange(1, 12),
            );
            expect(find.byType(ImageFiltered), findsNothing);
            expect(find.byType(BackdropFilter), findsNothing);
            expect(tester.binding.transientCallbackCount, 0);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            position.dispose();
            heading.dispose();
            map.dispose();
            debugDisableShadows = true;
          }
        },
      );
    }

    testWidgets('recorded path and location contrast on $name map', (
      tester,
    ) async {
      debugDisableShadows = false;
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(360, 260);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const joint = LatLng(56, 60);
      const end = LatLng(56, 60.0012);
      final position = ValueNotifier<LatLng?>(end);
      final heading = ValueNotifier<double?>(90);
      final map = MapController();
      try {
        await tester.pumpWidget(
          MaterialApp(
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: RepaintBoundary(
              key: const ValueKey('map-overlay'),
              child: FlutterMap(
                mapController: map,
                options: MapOptions(
                  initialCenter: joint,
                  initialZoom: 17,
                  backgroundColor: background,
                ),
                children: [
                  const RecordedRouteLayer(
                    points: [
                      LatLng(56.0004, 59.9992),
                      LatLng(56, 59.9992),
                      joint,
                    ],
                    tail: [joint, end],
                  ),
                  CurrentLocationLayer(position: position, heading: heading),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final capture = find.byKey(const ValueKey('map-overlay'));
        await expectLater(
          capture,
          matchesGoldenFile('goldens/map_overlay_$name.png'),
        );
        final boundary = tester.renderObject<RenderRepaintBoundary>(capture);
        final image = (await tester.runAsync(() => boundary.toImage()))!;
        try {
          final bytes = (await tester.runAsync(
            () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
          ))!;
          Color pixel(int x, int y) {
            final offset = (y * image.width + x) * 4;
            return Color.fromARGB(
              bytes.getUint8(offset + 3),
              bytes.getUint8(offset),
              bytes.getUint8(offset + 1),
              bytes.getUint8(offset + 2),
            );
          }

          final center = map.camera.latLngToScreenOffset(joint);
          // The history/tail join remains continuous and has no white edge.
          for (var dx = -5; dx <= 5; dx++) {
            expect(
              pixel(center.dx.round() + dx, center.dy.round()),
              AppTheme.route,
            );
          }
          final x = center.dx.round() - 25;
          final y = center.dy.round();
          expect(
            pixel(x, y + 4).computeLuminance(),
            lessThan(background.computeLuminance()),
          );
          expect(
            (pixel(x, y + 5).r - background.r).abs(),
            lessThan(0.05),
            reason: 'The shadow should be barely visible, not a dark outline',
          );
          expect(pixel(center.dx.round(), y + 7), pixel(x, y + 7));
          expect(pixel(x, y - 10), background);
          expect(
            pixel(x, y + 9).computeLuminance(),
            lessThanOrEqualTo(background.computeLuminance()),
          );
        } finally {
          image.dispose();
        }
        expect(find.byType(ImageFiltered), findsNothing);
        expect(find.byType(BackdropFilter), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        position.dispose();
        heading.dispose();
        map.dispose();
        debugDisableShadows = true;
      }
    });
  }
}

Future<Uint8List> _pixels(WidgetTester tester, Key key) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(key));
  final image = (await tester.runAsync(() => boundary.toImage()))!;
  try {
    final data = (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!;
    return data.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

Offset _alphaCenter(Uint8List pixels, int width) {
  var weight = 0.0;
  var x = 0.0;
  var y = 0.0;
  for (var offset = 0; offset < pixels.length; offset += 4) {
    final alpha = pixels[offset + 3];
    final pixel = offset ~/ 4;
    weight += alpha;
    x += (pixel % width + 0.5) * alpha;
    y += (pixel ~/ width + 0.5) * alpha;
  }
  expect(weight, greaterThan(0));
  return Offset(x / weight, y / weight);
}

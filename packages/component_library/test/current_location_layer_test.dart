import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  testWidgets(
    'initial camera fitting uses the latest zoom, not queued resize events',
    (tester) async {
      final harness = _Harness()..heading.value = 90;
      try {
        await harness.show(
          tester,
          initialZoom: 2,
          onReady: () {
            harness.map.move(harness.position.value!, 16);
          },
        );
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(find.byIcon(Icons.navigation_rounded)).size,
          36,
        );
        for (final zoom in [10.0, 16.0, 13.0]) {
          harness.map.move(harness.position.value!, zoom);
        }
        await tester.pumpAndSettle();
        expect(
          tester.widget<Icon>(find.byIcon(Icons.navigation_rounded)).size,
          30,
        );
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('unmounting with queued zoom and heading updates is safe', (
    tester,
  ) async {
    final harness = _Harness()..heading.value = 90;
    try {
      await harness.show(tester);
      harness.map.move(harness.position.value!, 2);
      harness.heading.value = 180;
      await tester.pumpWidget(const SizedBox.shrink());
      harness.heading.value = 270;
      await tester.pumpAndSettle();
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets(
    'arrow sizing has a lower and upper bound without moving its anchor',
    (tester) async {
      final harness = _Harness()..heading.value = 90;
      try {
        await harness.show(tester);
        final bounds = tester.getRect(_dot);
        final markerChild = harness.layer(tester).markers.single.child;
        for (final (zoom, size) in [
          (2.0, 24.0),
          (8.0, 24.0),
          (10.0, 24.0),
          (10.75, 25.5),
          (13.0, 30.0),
          (15.25, 34.5),
          (16.0, 36.0),
          (19.0, 36.0),
          (22.0, 36.0),
          (2.0, 24.0),
        ]) {
          harness.map.move(harness.position.value!, zoom);
          await tester.pumpAndSettle();
          final icon = find.byIcon(Icons.navigation_rounded);
          expect(tester.widget<Icon>(icon).size, size);
          expect(tester.getSize(icon), Size.square(size));
          expect(tester.getRect(_dot), bounds);
          expect(
            (tester.getCenter(icon) - bounds.center).distance,
            lessThan(0.001),
          );
          expect(harness.layer(tester).markers.single.child, same(markerChild));
          expect(_turn(tester), 0.25);
          expect(tester.binding.transientCallbackCount, 0);
        }
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets(
    'zoom does not restart a turn; clamped zoom, pan and rotate keep the glyph',
    (tester) async {
      final harness = _Harness()..heading.value = 90;
      try {
        await harness.show(tester);
        harness.heading.value = 180;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final beforeZoom = _turn(tester);
        harness.map.move(harness.position.value!, 13);
        await tester.pump();
        expect(_turn(tester), beforeZoom);
        expect(
          tester.widget<Icon>(find.byIcon(Icons.navigation_rounded)).size,
          30,
        );
        await tester.pumpAndSettle();
        expect(_turn(tester), 0.5);

        for (final zooms in [
          [8.0, 4.0, 2.0],
          [17.0, 18.0, 19.0],
        ]) {
          harness.map.move(harness.position.value!, zooms.first);
          await tester.pumpAndSettle();
          final icon = tester.widget<Icon>(
            find.byIcon(Icons.navigation_rounded),
          );
          final rebuilt = <Type>[];
          final oldObserver = debugOnRebuildDirtyWidget;
          debugOnRebuildDirtyWidget = (element, builtOnce) {
            oldObserver?.call(element, builtOnce);
            rebuilt.add(element.widget.runtimeType);
          };
          try {
            for (final zoom in zooms.skip(1)) {
              harness.map.moveAndRotate(const LatLng(56.0001, 60), zoom, 45);
              await tester.pumpAndSettle();
              expect(
                tester.widget<Icon>(find.byIcon(Icons.navigation_rounded)),
                same(icon),
              );
            }
            expect(rebuilt, isNot(contains(Icon)));
            expect(tester.binding.transientCallbackCount, 0);
          } finally {
            debugOnRebuildDirtyWidget = oldObserver;
          }
        }
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets('unknown course uses a static dot; known course uses an arrow', (
    tester,
  ) async {
    final harness = _Harness()..position.value = null;
    try {
      await harness.show(tester);
      expect(harness.layer(tester).markers, isEmpty);
      expect(tester.binding.transientCallbackCount, 0);
      harness.position.value = const LatLng(56, 60);
      await tester.pump();
      final marker = harness.layer(tester).markers.single;
      expect(marker.width, 40);
      expect(marker.height, 40);
      expect(marker.rotate, isFalse);
      expect(tester.getCenter(_dot), const Offset(400, 300));
      expect(tester.getSize(_dot), const Size(40, 40));
      expect(find.byIcon(Icons.navigation_rounded), findsNothing);
      final decorations = tester
          .widgetList<DecoratedBox>(
            find.descendant(of: _dot, matching: find.byType(DecoratedBox)),
          )
          .map((box) => box.decoration as BoxDecoration)
          .toList();
      expect(decorations, hasLength(3));
      expect(decorations[1].color, AppTheme.route);
      expect(decorations.every((box) => box.border == null), isTrue);
      final still = await _markerPixels(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(await _markerPixels(tester), orderedEquals(still));
      expect(tester.binding.transientCallbackCount, 0);

      harness.heading.value = 90;
      await tester.pump();
      final arrow = tester.widget<Icon>(find.byIcon(Icons.navigation_rounded));
      expect(arrow.size, 36);
      expect(arrow.color, AppTheme.route);
      expect(arrow.shadows!.single.color.a, inExclusiveRange(0.15, 0.2));
      expect(arrow.shadows!.single.blurRadius, 4);
      expect(arrow.shadows!.single.offset, Offset.zero);
      expect(_turn(tester), closeTo(0.25, 0.000001));
      expect(tester.getSize(_dot), const Size(40, 40));
      expect(tester.binding.transientCallbackCount, 0);
      final pointed = await _markerPixels(tester);
      await tester.pump(const Duration(seconds: 5));
      expect(await _markerPixels(tester), orderedEquals(pointed));
      harness.position.value = const LatLng(56.001, 60);
      await tester.pump();
      expect(harness.layer(tester).markers.single.child, same(marker.child));
      expect(
        harness.layer(tester).markers.single.point,
        harness.position.value,
      );
      for (final invalid in [null, double.nan, double.infinity]) {
        harness.heading.value = invalid;
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.navigation_rounded), findsNothing);
        expect(tester.binding.transientCallbackCount, 0);
      }
      harness.position.value = null;
      await tester.pump();
      expect(harness.layer(tester).markers, isEmpty);
      expect(find.bySemanticsLabel('Current location'), findsNothing);
    } finally {
      await harness.dispose(tester);
    }
  });

  testWidgets(
    'turn crosses north by the short arc and settles without idle frames',
    (tester) async {
      final harness = _Harness()..heading.value = 350;
      try {
        await harness.show(tester);
        final bounds = tester.getRect(_dot);
        harness.heading.value = 10;
        await tester.pump();
        expect(_turn(tester) * 360, closeTo(350, 0.001));
        await tester.pump(const Duration(milliseconds: 120));
        expect(_turn(tester) * 360, closeTo(360, 1));
        expect(tester.getRect(_dot), bounds);
        await tester.pumpAndSettle();
        expect(_turn(tester) * 360, closeTo(370, 0.001));
        harness.heading.value = 350;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        expect(_turn(tester) * 360, closeTo(360, 1));
        await tester.pumpAndSettle();
        expect(_turn(tester) * 360, closeTo(350, 0.001));
        harness.heading.value = 350.5;
        await tester.pump();
        expect(_turn(tester) * 360, closeTo(350, 0.001));
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await harness.dispose(tester);
      }
    },
  );

  testWidgets(
    'retargeting a turn starts from the visible angle and stays local',
    (tester) async {
      final harness = _Harness()..heading.value = 0;
      final previousObserver = debugOnRebuildDirtyWidget;
      try {
        await harness.show(tester);
        final bounds = tester.getRect(_dot);
        final paintCount = harness.mapPaint.paints;
        final rebuilt = <Type>[];
        debugOnRebuildDirtyWidget = (element, builtOnce) {
          previousObserver?.call(element, builtOnce);
          rebuilt.add(element.widget.runtimeType);
        };
        harness.heading.value = 90;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 120));
        final visible = _turn(tester);
        expect(visible, inExclusiveRange(0, 0.25));
        harness.heading.value = 180;
        await tester.pump();
        expect(_turn(tester), closeTo(visible, 0.0001));
        for (var frame = 0; frame < 15; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          expect(tester.getRect(_dot), bounds);
        }
        await tester.pump(const Duration(milliseconds: 16));
        expect(_turn(tester), closeTo(0.5, 0.0001));
        expect(rebuilt, contains(RotationTransition));
        for (final type in [FlutterMap, MarkerLayer, CurrentLocationLayer]) {
          expect(rebuilt, isNot(contains(type)));
        }
        expect(harness.mapPaint.paints, paintCount);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        debugOnRebuildDirtyWidget = previousObserver;
        await harness.dispose(tester);
      }
    },
  );

  for (final reducedInitially in [false, true]) {
    testWidgets(
      'reduced motion and hidden views snap finite turns ($reducedInitially)',
      (tester) async {
        final harness = _Harness()..heading.value = 0;
        try {
          await harness.show(tester, reduced: reducedInitially);
          harness.heading.value = 90;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          if (reducedInitially) {
            expect(_turn(tester), 0.25);
          } else {
            expect(_turn(tester), inExclusiveRange(0, 0.25));
          }
          await harness.show(tester, reduced: true);
          await tester.pumpAndSettle();
          expect(_turn(tester), 0.25);
          expect(tester.binding.transientCallbackCount, 0);
          await harness.show(tester);
          harness.heading.value = 180;
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 100));
          expect(_turn(tester), inExclusiveRange(0.25, 0.5));
          await harness.show(tester, visible: false);
          await tester.pumpAndSettle();
          expect(_turn(tester), 0.5);
          harness.heading.value = 270;
          await tester.pumpAndSettle();
          expect(_turn(tester), 0.75);
          expect(tester.binding.transientCallbackCount, 0);
          await harness.show(tester);
          expect(_turn(tester), 0.75);
          expect(tester.binding.transientCallbackCount, 0);
        } finally {
          await harness.dispose(tester);
        }
      },
    );
  }

  testWidgets('backgrounding stops a turn and does not replay it on resume', (
    tester,
  ) async {
    final harness = _Harness()..heading.value = 0;
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await harness.show(tester);
      harness.heading.value = 90;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      for (final state in [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
        // Settling the transform needs one layout pass, but no more ticking.
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 0);
      }
      harness.heading.value = 180;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(_turn(tester), 0.5);
      expect(tester.binding.transientCallbackCount, 0);
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await harness.dispose(tester);
    }
  });

  for (final direction in TextDirection.values) {
    testWidgets('geographic arrow rotates with the map in $direction', (
      tester,
    ) async {
      final harness = _Harness()..heading.value = 0;
      try {
        await harness.show(tester, reduced: true, direction: direction);
        for (final heading in [0.0, 90.0, 180.0, 270.0]) {
          harness.heading.value = heading;
          for (final rotation in [0.0, 45.0, 135.0]) {
            harness.map.rotate(rotation);
            await tester.pumpAndSettle();
            final box = tester.renderObject<RenderBox>(
              find.byIcon(Icons.navigation_rounded),
            );
            expect(box.size, const Size(36, 36));
            final localCenter = box.size.center(Offset.zero);
            final center = box.localToGlobal(localCenter);
            final tip = box.localToGlobal(Offset(localCenter.dx, 0));
            final actual = tip - center;
            final radians = (heading + rotation) * math.pi / 180;
            final expected = Offset.fromDirection(
              radians - math.pi / 2,
              localCenter.dy,
            );
            expect((actual - expected).distance, lessThan(0.001));
            expect((center - const Offset(400, 300)).distance, lessThan(0.001));
            expect(tester.binding.transientCallbackCount, 0);
          }
        }
      } finally {
        await harness.dispose(tester);
      }
    });
  }

  testWidgets(
    'replacing a heading source unsubscribes and disposal cancels turns',
    (tester) async {
      final harness = _Harness()..heading.value = 0;
      final replacement = ValueNotifier<double?>(90);
      try {
        await harness.show(tester);
        await harness.show(tester, source: replacement);
        await tester.pumpAndSettle();
        expect(_turn(tester), 0.25);
        harness.heading.value = 180;
        await tester.pump();
        expect(_turn(tester), 0.25);
        replacement.value = 180;
        await tester.pump();
        expect(tester.binding.transientCallbackCount, 1);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, 0);
        replacement.value = 270;
        await tester.pump();
      } finally {
        await harness.dispose(tester);
        replacement.dispose();
      }
    },
  );
}

Finder get _dot => find.bySemanticsLabel('Current location');

double _turn(WidgetTester tester) => tester
    .widget<RotationTransition>(
      find.descendant(of: _dot, matching: find.byType(RotationTransition)),
    )
    .turns
    .value;

class _Harness {
  final position = ValueNotifier<LatLng?>(const LatLng(56, 60));
  final heading = ValueNotifier<double?>(null);
  final map = MapController();
  final mapPaint = _PaintCounter();

  Future<void> show(
    WidgetTester tester, {
    bool reduced = false,
    bool visible = true,
    TextDirection direction = TextDirection.ltr,
    ValueListenable<double?>? source,
    double initialZoom = 16,
    VoidCallback? onReady,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: reduced,
            textScaler: TextScaler.linear(3),
          ),
          child: Directionality(
            textDirection: direction,
            child: TickerMode(
              enabled: visible,
              child: CustomPaint(
                painter: mapPaint,
                child: FlutterMap(
                  mapController: map,
                  options: MapOptions(
                    initialCenter: const LatLng(56, 60),
                    initialZoom: initialZoom,
                    onMapReady: onReady,
                  ),
                  children: [
                    CurrentLocationLayer(
                      position: position,
                      heading: source ?? heading,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  MarkerLayer layer(WidgetTester tester) => tester.widget<MarkerLayer>(
    find.byKey(const ValueKey('current-location-layer')),
  );

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    position.dispose();
    heading.dispose();
    map.dispose();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  }
}

Future<Uint8List> _markerPixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.descendant(of: _dot, matching: find.byType(RepaintBoundary)),
  );
  final image = (await tester.runAsync(() => boundary.toImage(pixelRatio: 1)))!;
  try {
    return (await tester.runAsync(
      () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
    ))!.buffer.asUint8List();
  } finally {
    image.dispose();
  }
}

class _PaintCounter extends CustomPainter {
  int paints = 0;

  @override
  void paint(Canvas canvas, Size size) => paints++;

  @override
  bool shouldRepaint(covariant _PaintCounter oldDelegate) => false;
}

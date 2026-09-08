import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/map_follow_motion.dart';

import '../../../component_library/test/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets('course-up keeps the visible arrow upright on every turn frame', (
    tester,
  ) async {
    final h = _Harness(heading: 90);
    try {
      await h.show(tester);
      h.follow.update(following: true, courseUp: true);
      await tester.pump();
      expect(h.map.camera.rotation, 0);
      await tester.pump(const Duration(milliseconds: 120));
      expect(h.map.camera.rotation, inExclusiveRange(-90, 0));
      await tester.pumpAndSettle();
      for (final target in [180.0, 270.0, 350.0, 10.0, 350.0, 180.0]) {
        h.rawHeading.value = target;
        await tester.pump();
        final rotation = h.map.camera.rotation;
        for (var frame = 0; frame < 16; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          _expectUpright(tester);
          expect(h.map.camera.rotation + h.heading.value!, closeTo(0, 0.001));
          expect(h.map.camera.center, h.position.value);
          expect(h.map.camera.zoom, 16);
        }
        expect(
          (h.map.camera.rotation - rotation).abs(),
          lessThanOrEqualTo(180),
        );
        expect(tester.binding.transientCallbackCount, 0);
      }
      final still = h.map.camera;
      await tester.pump(const Duration(minutes: 10));
      expect(h.map.camera, same(still));
      expect(tester.binding.transientCallbackCount, 0);
    } finally {
      await h.dispose(tester);
    }
  });

  testWidgets(
    'rapid mode reversals start at the visible angle and retain zoom',
    (tester) async {
      final h = _Harness(heading: 90);
      try {
        await h.show(tester);
        h.map.move(h.position.value!, 18);
        h.follow.update(following: true, courseUp: true);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final first = h.map.camera.rotation;
        h.follow.update(following: true, courseUp: false);
        expect(h.map.camera.rotation, closeTo(first, 0.001));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        final second = h.map.camera.rotation;
        expect(second, greaterThan(first));
        h.follow.update(following: true, courseUp: true);
        expect(h.map.camera.rotation, closeTo(second, 0.001));
        await tester.pumpAndSettle();
        _expectUpright(tester);
        expect(h.map.camera.zoom, 18);
        h.follow.update(following: true, courseUp: false);
        await tester.pumpAndSettle();
        expect(h.map.camera.rotation, 0);
        expect(tester.binding.transientCallbackCount, 0);
      } finally {
        await h.dispose(tester);
      }
    },
  );

  testWidgets('free map cancels camera turns and ignores later fixes', (
    tester,
  ) async {
    final h = _Harness(heading: 90);
    try {
      await h.show(tester);
      h.follow.update(following: true, courseUp: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      h.follow.update(following: false, courseUp: true);
      h.map.moveAndRotate(const LatLng(56.01, 60.01), 17, 40);
      final free = h.map.camera;
      h.rawHeading.value = 180;
      h.position.value = const LatLng(56.001, 60.001);
      await tester.pumpAndSettle();
      expect(h.map.camera, same(free));
      h.follow.update(following: true, courseUp: true);
      await tester.pumpAndSettle();
      _expectUpright(tester);
      expect(h.map.camera.center, h.position.value);
      expect(h.map.camera.zoom, 17);
    } finally {
      await h.dispose(tester);
    }
  });

  testWidgets(
    'unknown course holds orientation then gently acquires a course',
    (tester) async {
      final h = _Harness();
      try {
        await h.show(tester);
        h.follow.update(following: true, courseUp: true);
        await tester.pumpAndSettle();
        expect(h.map.camera.rotation, 0);
        expect(find.byIcon(Icons.navigation_rounded), findsNothing);
        h.rawHeading.value = 90;
        await tester.pump();
        expect(h.map.camera.rotation, 0);
        await tester.pump(const Duration(milliseconds: 120));
        expect(h.map.camera.rotation, inExclusiveRange(-90, 0));
        await tester.pumpAndSettle();
        _expectUpright(tester);
        h.rawHeading.value = null;
        h.position.value = const LatLng(55, 61);
        await tester.pumpAndSettle();
        expect(h.map.camera.rotation, -90);
        expect(h.map.camera.center, h.position.value);
        expect(find.byIcon(Icons.navigation_rounded), findsNothing);
        h.rawHeading.value = 0;
        await tester.pumpAndSettle();
        _expectUpright(tester);
        expect(h.map.camera.rotation, 0);
      } finally {
        await h.dispose(tester);
      }
    },
  );

  testWidgets('late first position uses default zoom only once', (
    tester,
  ) async {
    final h = _Harness()..position.value = null;
    try {
      await h.show(tester);
      h.follow.update(following: true, courseUp: true);
      expect(h.map.camera.zoom, 2);
      h.position.value = const LatLng(56, 60);
      await tester.pumpAndSettle();
      expect(h.map.camera.zoom, 16);
      h.map.move(h.position.value!, 18);
      h.position.value = const LatLng(56.001, 60);
      await tester.pumpAndSettle();
      expect(h.map.camera.zoom, 18);
    } finally {
      await h.dispose(tester);
    }
  });

  testWidgets('reduced motion and background stop both turns without replay', (
    tester,
  ) async {
    final h = _Harness(heading: 90);
    try {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await h.show(tester);
      h.follow.update(following: true, courseUp: true);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      h.heading.enabled = false;
      h.follow.enabled = false;
      await tester.pumpAndSettle();
      _expectUpright(tester);
      h.rawHeading.value = 180;
      await tester.pumpAndSettle();
      _expectUpright(tester);
      expect(tester.binding.transientCallbackCount, 0);
      h.heading.enabled = true;
      h.follow.enabled = true;
      h.rawHeading.value = 270;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pumpAndSettle();
      _expectUpright(tester);
      h.rawHeading.value = 350;
      await tester.pumpAndSettle();
      _expectUpright(tester);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      _expectUpright(tester);
      expect(tester.binding.transientCallbackCount, 0);
      h.follow.update(following: true, courseUp: false);
      await tester.pump();
    } finally {
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await h.dispose(tester);
    }
  });
}

void _expectUpright(WidgetTester tester) {
  final box = tester.renderObject<RenderBox>(
    find.byIcon(Icons.navigation_rounded),
  );
  final localCenter = box.size.center(Offset.zero);
  final center = box.localToGlobal(localCenter);
  final tip = box.localToGlobal(Offset(localCenter.dx, 0));
  expect((tip - center - Offset(0, -localCenter.dy)).distance, lessThan(0.001));
  expect((center - const Offset(400, 300)).distance, lessThan(0.001));
}

class _Harness {
  _Harness({double? heading}) : rawHeading = ValueNotifier(heading) {
    this.heading = HeadingMotion(vsync: const TestVSync(), heading: rawHeading)
      ..enabled = true;
    follow = MapFollowMotion(
      vsync: const TestVSync(),
      controller: map,
      position: position,
      heading: this.heading,
      defaultZoom: 16,
    )..enabled = true;
  }

  final ValueNotifier<double?> rawHeading;
  final position = ValueNotifier<LatLng?>(const LatLng(56, 60));
  final map = MapController();
  late final HeadingMotion heading;
  late final MapFollowMotion follow;

  Future<void> show(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: FlutterMap(
          mapController: map,
          options: MapOptions(
            initialCenter: position.value ?? const LatLng(0, 0),
            initialZoom: 2,
            onMapReady: () => follow.attach(following: true, courseUp: false),
          ),
          children: [
            CurrentLocationLayer.withHeadingMotion(
              position: position,
              headingMotion: heading,
            ),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> dispose(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    follow.dispose();
    heading.dispose();
    position.dispose();
    rawHeading.dispose();
    map.dispose();
    await tester.pump();
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  }
}

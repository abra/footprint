import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/location_motion.dart';

void main() {
  late LocationMotion motion;
  const start = LatLng(56, 60);
  const target = LatLng(56.001, 60);

  setUp(() {
    motion = LocationMotion(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    );
  });
  tearDown(() => motion.dispose());

  testWidgets('first fix appears immediately without flying from zero', (
    tester,
  ) async {
    motion.moveTo(start);
    expect(motion.value, start);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, start);
  });

  testWidgets('nearby fixes interpolate and finish at exact GPS coordinates', (
    tester,
  ) async {
    motion.moveTo(start);
    motion.moveTo(target);
    expect(motion.value, start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(
      motion.value!.latitude,
      inExclusiveRange(start.latitude, target.latitude),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, target);
    await tester.pumpAndSettle();
  });

  testWidgets('new fixes retarget from the visible point without jumping', (
    tester,
  ) async {
    motion.moveTo(start);
    motion.moveTo(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final visible = motion.value;
    const next = LatLng(56.002, 60);
    motion.moveTo(next);
    expect(motion.value, visible);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, next);
    await tester.pumpAndSettle();
  });

  testWidgets('repeated fixes do not restart an in-flight animation', (
    tester,
  ) async {
    motion.moveTo(start);
    motion.moveTo(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    motion.moveTo(target);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, target);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'large GPS corrections cancel animation instead of long flights',
    (tester) async {
      motion.moveTo(start);
      motion.moveTo(target);
      await tester.pump();
      const farAway = LatLng(37, -122);
      motion.moveTo(farAway);
      expect(motion.value, farAway);
      await tester.pump(const Duration(seconds: 1));
      expect(motion.value, farAway);
    },
  );

  testWidgets('reduced motion snaps an in-flight animation to its target', (
    tester,
  ) async {
    motion.moveTo(start);
    motion.moveTo(target);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    motion.moveTo(target, animate: false);
    expect(motion.value, target);
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, target);
  });

  testWidgets('date line crossing takes the short path', (tester) async {
    motion.moveTo(const LatLng(0, 179.999));
    motion.moveTo(const LatLng(0, -179.999));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value!.longitude.abs(), greaterThan(179.998));
    expect(motion.value!.isValid, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, const LatLng(0, -179.999));
    await tester.pumpAndSettle();
  });
}

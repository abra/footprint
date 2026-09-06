import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/location_motion.dart';

void main() {
  late LocationMotion motion;
  const start = LatLng(56, 60);
  const target = LatLng(56.001, 60);
  final epoch = DateTime.utc(2026, 9, 6);

  void send(LatLng point, int milliseconds, {bool animate = true}) {
    motion.moveTo(
      point,
      timestamp: epoch.add(Duration(milliseconds: milliseconds)),
      animate: animate,
    );
  }

  setUp(() {
    motion = LocationMotion(vsync: const TestVSync());
  });
  tearDown(() => motion.dispose());

  testWidgets('first fix appears immediately without flying from zero', (
    tester,
  ) async {
    send(start, 0);
    expect(motion.value, start);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, start);
  });

  testWidgets(
    'playback time follows the visible point and clamps at both ends',
    (tester) async {
      expect(motion.displayedAt, isNull);
      send(start, 0);
      expect(motion.displayedAt, epoch);
      send(target, 1000);
      expect(motion.displayedAt, epoch);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(motion.displayedAt, epoch.add(const Duration(milliseconds: 500)));
      await tester.pumpAndSettle();
      expect(motion.displayedAt, epoch.add(const Duration(seconds: 1)));
    },
  );

  testWidgets(
    'a loop completion notifies even when its final position is unchanged',
    (tester) async {
      send(start, 0);
      send(target, 1000);
      send(start, 2000);
      var changes = 0;
      motion.addListener(() => changes++);
      await tester.pump();
      await tester.pump(const Duration(seconds: 3));
      expect(motion.value, start);
      expect(motion.displayedAt, epoch.add(const Duration(seconds: 2)));
      expect(changes, 1);
    },
  );

  testWidgets('nearby fixes interpolate and finish at exact GPS coordinates', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    expect(motion.value, start);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      motion.value!.latitude,
      inExclusiveRange(start.latitude, target.latitude),
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, target);
    await tester.pumpAndSettle();
  });

  testWidgets('new fixes enter the buffer without jumping or restarting', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    final visible = motion.value;
    const next = LatLng(56.002, 60);
    send(next, 2000);
    expect(motion.value, visible);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(motion.value, next);
    await tester.pumpAndSettle();
  });

  testWidgets('repeated fixes do not restart an in-flight animation', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    send(target, 1000);
    await tester.pump(const Duration(milliseconds: 700));
    expect(motion.value, target);
    await tester.pumpAndSettle();
  });

  testWidgets(
    'large GPS corrections cancel animation instead of long flights',
    (tester) async {
      send(start, 0);
      send(target, 1000);
      await tester.pump();
      const farAway = LatLng(37, -122);
      send(farAway, 2000);
      expect(motion.value, farAway);
      await tester.pump(const Duration(seconds: 1));
      expect(motion.value, farAway);
    },
  );

  testWidgets('reduced motion snaps an in-flight animation to its target', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    send(target, 1000, animate: false);
    expect(motion.value, target);
    await tester.pump(const Duration(seconds: 1));
    expect(motion.value, target);
  });

  testWidgets('date line crossing takes the short path', (tester) async {
    send(const LatLng(0, 179.999), 0);
    send(const LatLng(0, -179.999), 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 700));
    expect(motion.value!.longitude.abs(), greaterThan(179.998));
    expect(motion.value!.isValid, isTrue);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value, const LatLng(0, -179.999));
    await tester.pumpAndSettle();
  });

  testWidgets('regular fixes move at constant speed across sample boundaries', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    var previous = motion.value!;
    const distance = DistanceHaversine(roundResult: false);
    final expectedStep = distance(start, target) / 4;

    for (var second = 2; second <= 5; second++) {
      send(LatLng(56 + second * 0.001, 60), second * 1000);
      expect(motion.value, previous);
      for (var frame = 0; frame < 4; frame++) {
        await tester.pump(const Duration(milliseconds: 250));
        final current = motion.value!;
        expect(distance(previous, current), closeTo(expectedStep, 0.01));
        previous = current;
      }
    }
    await tester.pumpAndSettle();
    expect(motion.value, const LatLng(56.005, 60));
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('a late fix within the jitter margin does not stop movement', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1100));
    var previous = motion.value!;
    expect(previous.latitude, lessThan(target.latitude));
    send(const LatLng(56.002, 60), 2000);
    expect(motion.value, previous);
    for (var frame = 0; frame < 8; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
      expect(motion.value!.latitude, greaterThan(previous.latitude));
      previous = motion.value!;
    }
    await tester.pumpAndSettle();
  });

  testWidgets('buffered turns follow both legs instead of cutting the corner', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    const turn = LatLng(56.001, 60.001);
    send(turn, 2000);
    await tester.pump(const Duration(milliseconds: 400));
    expect(motion.value!.latitude, lessThan(target.latitude));
    expect(motion.value!.longitude, closeTo(start.longitude, 0.0000001));
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value!.latitude, closeTo(target.latitude, 0.0000001));
    expect(
      motion.value!.longitude,
      inExclusiveRange(target.longitude, turn.longitude),
    );
    await tester.pumpAndSettle();
    expect(motion.value, turn);
  });

  testWidgets('buffer adapts to a slower GPS cadence without repeated stops', (
    tester,
  ) async {
    send(start, 0);
    send(target, 3000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    final previous = motion.value!;
    expect(previous.latitude, lessThan(target.latitude));
    send(const LatLng(56.002, 60), 6000);
    expect(motion.value, previous);
    await tester.pump(const Duration(milliseconds: 500));
    expect(motion.value!.latitude, greaterThan(target.latitude));
    await tester.pumpAndSettle();
  });

  testWidgets(
    'signal loss drains playback without extrapolation or idle ticks',
    (tester) async {
      send(start, 0);
      send(target, 1000);
      await tester.pumpAndSettle();
      expect(motion.value, target);
      expect(tester.binding.transientCallbackCount, 0);
      var changes = 0;
      motion.addListener(() => changes++);
      await tester.pump(const Duration(seconds: 20));
      expect(motion.value, target);
      expect(changes, 0);
      send(const LatLng(56.002, 60), 21000);
      expect(motion.value, const LatLng(56.002, 60));
      expect(tester.binding.transientCallbackCount, 0);
    },
  );

  testWidgets('stationary fixes do not schedule animation frames', (
    tester,
  ) async {
    send(start, 0);
    var changes = 0;
    motion.addListener(() => changes++);
    for (var second = 1; second <= 5; second++) {
      send(start, second * 1000);
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pump(const Duration(seconds: 1));
    }
    expect(changes, 0);
    expect(motion.value, start);
  });

  testWidgets('out-of-order and invalid fixes cannot move the marker back', (
    tester,
  ) async {
    send(start, 0);
    send(target, 1000);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final previous = motion.value;
    send(start, 500);
    send(const LatLng(double.nan, 60), 2000);
    expect(motion.value, previous);
    await tester.pumpAndSettle();
    expect(motion.value, target);
  });

  testWidgets(
    'buffer overflow snaps instead of replaying an unbounded backlog',
    (tester) async {
      send(start, 0);
      for (var index = 1; index <= 32; index++) {
        send(LatLng(56 + index * 0.00001, 60), index * 10);
      }
      expect(motion.value, const LatLng(56.00032, 60));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'a timestamp backlog is bounded even below the sample count cap',
    (tester) async {
      send(start, 0);
      send(target, 1000);
      send(const LatLng(56.002, 60), 5000);
      send(const LatLng(56.003, 60), 9000);
      expect(motion.value, const LatLng(56.003, 60));
      expect(tester.binding.transientCallbackCount, 0);
      await tester.pumpAndSettle();
    },
  );
}

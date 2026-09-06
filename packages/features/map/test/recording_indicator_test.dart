import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/recording_indicator.dart';

Widget indicator({
  bool pulsing = true,
  bool visible = true,
  bool reducedMotion = false,
}) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: MediaQueryData(disableAnimations: reducedMotion),
    child: TickerMode(
      enabled: visible,
      child: Center(child: RecordingIndicator(pulsing: pulsing)),
    ),
  ),
);

double opacity(WidgetTester tester) =>
    tester.widget<FadeTransition>(find.byType(FadeTransition)).opacity.value;

void main() {
  testWidgets('dot pulses without resizing or rebuilding its widgets', (
    tester,
  ) async {
    await tester.pumpWidget(indicator());
    final bounds = tester.getRect(find.byType(RecordingIndicator));
    expect(bounds.size, const Size(24, 24));
    final initial = opacity(tester);
    var rebuilds = 0;
    final previousObserver = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousObserver?.call(element, builtOnce);
      rebuilds++;
    };
    try {
      await tester.pump(const Duration(milliseconds: 400));
      final middle = opacity(tester);
      expect(middle, lessThan(initial));
      await tester.pump(const Duration(milliseconds: 400));
      expect(opacity(tester), closeTo(0.4, 0.001));
      await tester.pump(const Duration(milliseconds: 800));
      expect(opacity(tester), closeTo(initial, 0.001));
      expect(tester.getRect(find.byType(RecordingIndicator)), bounds);
      expect(rebuilds, 0);
    } finally {
      debugOnRebuildDirtyWidget = previousObserver;
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('pending operations stop the pulse and it resumes afterwards', (
    tester,
  ) async {
    await tester.pumpWidget(indicator());
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpWidget(indicator(pulsing: false));
    expect(opacity(tester), 1);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(indicator());
    await tester.pump(const Duration(milliseconds: 400));
    expect(opacity(tester), lessThan(1));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      reducedMotion ? 'respects reduced motion' : 'stops on a hidden route',
      (tester) async {
        await tester.pumpWidget(indicator());
        await tester.pump(const Duration(milliseconds: 400));
        await tester.pumpWidget(
          indicator(visible: reducedMotion, reducedMotion: reducedMotion),
        );
        expect(opacity(tester), 1);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(indicator());
        await tester.pump(const Duration(milliseconds: 400));
        expect(opacity(tester), lessThan(1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, 0);
      },
    );
  }
}

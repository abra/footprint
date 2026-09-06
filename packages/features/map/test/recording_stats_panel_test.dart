import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/recording_stats_panel.dart';
import 'package:map/src/route_speed_chart.dart';

const history = [
  RouteSpeedSample(elapsed: Duration(seconds: 1), speed: 10),
  RouteSpeedSample(elapsed: Duration(seconds: 2), speed: 20),
  RouteSpeedSample(elapsed: Duration(seconds: 3), speed: 0),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    await (FontLoader('packages/component_library/RobotoCondensed')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/RobotoCondensed.ttf',
          ),
        ))
        .load();
  });
  for (final expanded in [false, true]) {
    testWidgets(
      'panel keeps its full width under loose constraints, expanded: $expanded',
      (tester) async {
        Rect? bounds;
        for (final metrics in [
          const RouteMetrics(),
          RouteMetrics(
            currentSpeed: 116.9 / 3.6,
            distance: 8800,
            duration: const Duration(minutes: 4, seconds: 20),
          ),
          RouteMetrics(
            currentSpeed: 120 / 3.6,
            distance: 119000,
            duration: const Duration(hours: 125),
          ),
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Center(
                child: SizedBox(
                  width: 396,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RecordingStatsPanel(
                        metrics: metrics,
                        expanded: expanded,
                        onToggle: () {},
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          final current = tester.getRect(
            find.byKey(const ValueKey('recording-stats-panel')),
          );
          bounds ??= current;
          expect(current.width, 396);
          expect(current, bounds);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
  testWidgets(
    'keyboard activation exposes the expanded state to accessibility',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        var expanded = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Center(
              child: SizedBox(
                width: 396,
                child: StatefulBuilder(
                  builder: (context, setState) => RecordingStatsPanel(
                    metrics: const RouteMetrics(),
                    expanded: expanded,
                    onToggle: () => setState(() => expanded = !expanded),
                  ),
                ),
              ),
            ),
          ),
        );
        final panel = find.bySemanticsLabel('Recording statistics');
        expect(
          tester.getSemantics(panel),
          isSemantics(
            isButton: true,
            hasExpandedState: true,
            isExpanded: false,
          ),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(expanded, isTrue);
        expect(tester.getSemantics(panel), isSemantics(isExpanded: true));
      } finally {
        semantics.dispose();
      }
    },
  );
  testWidgets(
    'tap switches between PDF layouts and back without changing metrics',
    (tester) async {
      var expanded = false;
      final metrics = RouteMetrics(
        currentSpeed: 120 / 3.6,
        speedHistory: history,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Center(
            child: SizedBox(
              width: 396,
              child: StatefulBuilder(
                builder: (context, setState) => RecordingStatsPanel(
                  metrics: metrics,
                  expanded: expanded,
                  onToggle: () => setState(() => expanded = !expanded),
                ),
              ),
            ),
          ),
        ),
      );
      final panel = find.byKey(const ValueKey('recording-stats-panel'));
      final height = tester.getSize(panel).height;
      expect(find.byType(RouteSpeedChart), findsNothing);
      await tester.tap(panel);
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, greaterThan(height));
      expect(
        tester.widget<RouteSpeedChart>(find.byType(RouteSpeedChart)).samples,
        same(history),
      );
      expect(
        tester.getRect(find.byType(RouteSpeedChart)).right,
        lessThan(tester.getRect(find.byType(RouteStats)).left),
      );
      expect(find.text('120.0'), findsOneWidget);
      await tester.tap(panel);
      await tester.pumpAndSettle();
      expect(tester.getSize(panel).height, height);
      expect(find.byType(RouteSpeedChart), findsNothing);
    },
  );

  testWidgets(
    'large text places the graph above metrics and respects reduced motion',
    (tester) async {
      var expanded = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(
              textScaler: TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: Center(
              child: SizedBox(
                width: 288,
                child: StatefulBuilder(
                  builder: (context, setState) => RecordingStatsPanel(
                    metrics: const RouteMetrics(speedHistory: history),
                    expanded: expanded,
                    onToggle: () => setState(() => expanded = !expanded),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('recording-stats-panel')));
      await tester.pumpAndSettle();
      expect(find.byType(AnimatedSize), findsNothing);
      expect(
        tester.getRect(find.byType(RouteSpeedChart)).bottom,
        lessThan(tester.getRect(find.byType(RouteStats)).top),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('a clock tick does not invalidate the speed chart', (
    tester,
  ) async {
    Future<void> show(RouteMetrics metrics) => tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 396,
            child: RecordingStatsPanel(
              metrics: metrics,
              expanded: true,
              onToggle: () {},
            ),
          ),
        ),
      ),
    );
    const metrics = RouteMetrics(speedHistory: history);
    await show(metrics);
    final chartPaint = find.descendant(
      of: find.byType(RouteSpeedChart),
      matching: find.byType(CustomPaint),
    );
    final painter = tester.widget<CustomPaint>(chartPaint).painter!;
    await show(
      metrics.atTime(
        start: DateTime(2026),
        lastSample: DateTime(2026),
        now: DateTime(2026).add(const Duration(seconds: 1)),
      ),
    );
    expect(
      tester.widget<CustomPaint>(chartPaint).painter!.shouldRepaint(painter),
      isFalse,
    );
    await show(const RouteMetrics(speedHistory: []));
    expect(
      tester.widget<CustomPaint>(chartPaint).painter!.shouldRepaint(painter),
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });
}

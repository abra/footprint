import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

Rect paintedBounds(WidgetTester tester, Finder finder) {
  final box = tester.renderObject<RenderBox>(finder);
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

Rect paintedTextBounds(WidgetTester tester, Finder finder) {
  final text = tester.widget<Text>(finder);
  final paragraph = tester.renderObject<RenderParagraph>(finder);
  final box = paragraph
      .getBoxesForSelection(
        TextSelection(baseOffset: 0, extentOffset: text.data!.length),
      )
      .single
      .toRect();
  return MatrixUtils.transformRect(paragraph.getTransformTo(null), box);
}

void expectCompactUnit(WidgetTester tester, int item) {
  final value = paintedTextBounds(
    tester,
    find.byKey(ValueKey('live-stat-value-$item')),
  );
  final unitFinder = find.byKey(ValueKey('live-stat-unit-$item'));
  final unit = paintedTextBounds(tester, unitFinder);
  final cell = paintedBounds(tester, find.byKey(ValueKey('live-stat-$item')));
  expect(unit.left - value.right, closeTo(4, 0.01));
  expect(
    paintedBounds(tester, unitFinder).right,
    lessThanOrEqualTo(cell.right + 0.01),
  );
}

void expectEvenStatSpacing(WidgetTester tester, {bool reserveSpeeds = true}) {
  final groups = <Rect>[];
  for (var i = 0; i < 4; i++) {
    if (reserveSpeeds && i < 2) {
      groups.add(paintedBounds(tester, find.byKey(ValueKey('live-stat-$i'))));
      continue;
    }
    final texts = find.descendant(
      of: find.byKey(ValueKey('live-stat-$i')),
      matching: find.byType(Text),
    );
    var bounds = paintedBounds(tester, texts.first);
    for (var index = 1; index < texts.evaluate().length; index++) {
      bounds = bounds.expandToInclude(paintedBounds(tester, texts.at(index)));
    }
    groups.add(bounds);
  }
  final gap = groups[1].left - groups[0].right;
  expect(gap, greaterThanOrEqualTo(12));
  for (var i = groups.length - 1; i >= 2; i--) {
    expect(
      groups[i].left - groups[i - 1].right,
      closeTo(gap, reserveSpeeds ? 0.01 : 1),
      reason: 'Gap before metric $i must match the gap between the speeds',
    );
  }
}

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

  for (final (width, scale) in [
    (364.0, 1.0),
    (240.0, 1.0),
    (240.0, 2.0),
    (748.0, 2.0),
  ]) {
    testWidgets(
      'live values stay on one line and left align at $width / $scale',
      (tester) async {
        double? height;
        for (final speed in [0.0, 6.3, 99.9, 120.0, 999.9]) {
          final metrics = RouteMetrics(
            currentSpeed: speed / 3.6,
            distance: 119000,
            duration: const Duration(hours: 125, minutes: 59, seconds: 59),
          );
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) =>
                  AppTheme.builder(context, Material(child: child)),
              home: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: Center(
                  child: SizedBox(
                    width: width,
                    child: RouteStats(metrics: metrics, live: true),
                  ),
                ),
              ),
            ),
          );
          for (var i = 0; i < 4; i++) {
            final cell = find.byKey(ValueKey('live-stat-$i'));
            final texts = find.descendant(
              of: cell,
              matching: find.byType(Text),
            );
            final value = texts.at(0);
            final label = texts.last;
            final bounds = paintedBounds(tester, cell);
            final valueBounds = paintedBounds(tester, value);
            final labelBounds = paintedBounds(tester, label);
            expect(valueBounds.left, closeTo(labelBounds.left, 0.01));
            expect(valueBounds.right, lessThanOrEqualTo(bounds.right + 0.01));
            expect(labelBounds.right, lessThanOrEqualTo(bounds.right + 0.01));
            expect(
              valueBounds.bottom,
              lessThanOrEqualTo(labelBounds.top + 0.01),
            );
            final text = tester.widget<Text>(value);
            final paragraph = tester.renderObject<RenderParagraph>(value);
            expect(
              paragraph.didExceedMaxLines,
              isFalse,
              reason: 'Field $i: ${text.data}, $valueBounds within $bounds',
            );
            expect(
              paragraph.getBoxesForSelection(
                TextSelection(baseOffset: 0, extentOffset: text.data!.length),
              ),
              hasLength(1),
            );
            if (i < 3) {
              expectCompactUnit(tester, i);
            }
          }
          if (tester.getTopLeft(find.byKey(const ValueKey('live-stat-0'))).dy ==
              tester.getTopLeft(find.byKey(const ValueKey('live-stat-3'))).dy) {
            expectEvenStatSpacing(tester);
          }
          final currentHeight = tester.getSize(find.byType(RouteStats)).height;
          height ??= currentHeight;
          expect(currentHeight, height);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets('expanded metrics use the PDF column order', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) =>
            AppTheme.builder(context, Material(child: child)),
        home: const Center(
          child: SizedBox(
            width: 200,
            child: RouteStats(metrics: RouteMetrics(), live: true, columns: 2),
          ),
        ),
      ),
    );
    final current = tester.getTopLeft(find.text('CURRENT SPEED'));
    final average = tester.getTopLeft(find.text('AVERAGE SPEED'));
    final distance = tester.getTopLeft(find.text('DISTANCE'));
    final duration = tester.getTopLeft(find.text('DURATION'));
    expect(current.dx, average.dx);
    expect(distance.dx, duration.dx);
    expect(current.dy, distance.dy);
    expect(average.dy, duration.dy);
    expect(average.dy, greaterThan(current.dy));
  });

  testWidgets('speed digit boundaries do not move the average speed group', (
    tester,
  ) async {
    List<Rect>? cells;
    Offset? labelPosition;
    Offset? valuePosition;
    for (final (current, average) in [
      (120.0, 100.1),
      (120.0, 99.9),
      (120.0, 100.0),
      (120.0, 99.9),
      (99.9, 99.9),
      (100.0, 100.1),
      (9.9, 99.9),
      (10.0, 100.1),
      (999.9, 9.9),
      (99.9, 10.0),
      (0.0, 9.9),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) =>
              AppTheme.builder(context, Material(child: child)),
          home: Center(
            child: SizedBox(
              width: 364,
              child: RouteStats(
                live: true,
                metrics: RouteMetrics(
                  currentSpeed: current / 3.6,
                  distance: 8800,
                  duration: Duration(
                    microseconds:
                        (8800 * 3.6 / average * Duration.microsecondsPerSecond)
                            .round(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      final value = find.byKey(const ValueKey('live-stat-value-1'));
      final label = find.text('AVERAGE SPEED');
      final currentCells = [
        for (var i = 0; i < 4; i++)
          paintedBounds(tester, find.byKey(ValueKey('live-stat-$i'))),
      ];
      cells ??= currentCells;
      labelPosition ??= tester.getTopLeft(label);
      valuePosition ??= tester.getTopLeft(value);
      expect(tester.widget<Text>(value).data, average.toStringAsFixed(1));
      expect(tester.getTopLeft(label), labelPosition);
      expect(tester.getTopLeft(value), valuePosition);
      expect(currentCells, cells);
      for (var i = 0; i < 3; i++) {
        expectCompactUnit(tester, i);
      }
      expectEvenStatSpacing(tester);
      if (current >= 100 && average >= 100) {
        expectEvenStatSpacing(tester, reserveSpeeds: false);
      }
      expect(tester.takeException(), isNull);
    }
  });

  for (final columns in [4, 2]) {
    testWidgets(
      '99 to 100 keeps glyph sizes and a balanced $columns-column layout',
      (tester) async {
        List<Rect>? cells;
        final unitsByDigitCount = <int, List<Rect>>{};
        List<Size>? digits;
        double? height;
        for (final speed in [
          9.9,
          8.8,
          99.9,
          88.8,
          100.0,
          99.9,
          120.0,
          999.9,
          0.0,
        ]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) =>
                  AppTheme.builder(context, Material(child: child)),
              home: Center(
                child: SizedBox(
                  width: columns == 4 ? 364 : 200,
                  child: RouteStats(
                    live: true,
                    columns: columns,
                    metrics: RouteMetrics(
                      currentSpeed: speed / 3.6,
                      distance: 8800,
                      duration: const Duration(minutes: 4, seconds: 20),
                    ),
                  ),
                ),
              ),
            ),
          );
          final currentCells = [
            for (var i = 0; i < 4; i++)
              paintedBounds(tester, find.byKey(ValueKey('live-stat-$i'))),
          ];
          final currentUnits = [
            for (var i = 0; i < 2; i++)
              paintedBounds(tester, find.byKey(ValueKey('live-stat-unit-$i'))),
          ];
          final currentDigits = <Size>[];
          for (var i = 0; i < 4; i++) {
            final finder = find.byKey(ValueKey('live-stat-value-$i'));
            final text = tester.widget<Text>(finder);
            expect(text.style!.fontSize, 20);
            final paragraph = tester.renderObject<RenderParagraph>(finder);
            final glyph = paragraph
                .getBoxesForSelection(
                  const TextSelection(baseOffset: 0, extentOffset: 1),
                )
                .single
                .toRect();
            currentDigits.add(
              MatrixUtils.transformRect(
                paragraph.getTransformTo(null),
                glyph,
              ).size,
            );
            expect(paragraph.didExceedMaxLines, isFalse);
            if (i < 3) {
              expectCompactUnit(tester, i);
            }
          }
          cells ??= currentCells;
          final digitCount = speed.toStringAsFixed(1).length;
          unitsByDigitCount.putIfAbsent(digitCount, () => currentUnits);
          digits ??= currentDigits;
          height ??= tester.getSize(find.byType(RouteStats)).height;
          expect(currentCells, cells);
          expect(currentUnits, unitsByDigitCount[digitCount]);
          expect(currentDigits, digits);
          final bounds = paintedBounds(tester, find.byType(RouteStats));
          expect(currentCells.first.left, bounds.left);
          expect(currentCells.last.right, closeTo(bounds.right, 0.01));
          if (columns == 4) {
            expectEvenStatSpacing(tester);
          } else {
            expect(
              currentCells[2].left - currentCells[0].right,
              closeTo(12, 0.01),
            );
          }
          expect(tester.getSize(find.byType(RouteStats)).height, height);
          expect(
            currentCells.map((rect) => rect.top).toSet(),
            hasLength(columns == 4 ? 1 : 2),
          );
          expect(
            find.descendant(
              of: find.byType(RouteStats),
              matching: find.byType(FittedBox),
            ),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        }
      },
    );
  }

  testWidgets(
    'distance and duration gain a digit without uneven gaps or clipping',
    (tester) async {
      for (final (distance, duration) in [
        (0.0, Duration.zero),
        (8.8, const Duration(seconds: 1)),
        (999.0, const Duration(seconds: 59)),
        (1000.0, const Duration(minutes: 1)),
        (8800.0, const Duration(minutes: 4, seconds: 20)),
        (999900.0, const Duration(hours: 99, minutes: 59, seconds: 59)),
        (1000000.0, const Duration(hours: 100)),
        (999900.0, const Duration(hours: 99, minutes: 59, seconds: 59)),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) =>
                AppTheme.builder(context, Material(child: child)),
            home: Center(
              child: SizedBox(
                width: 364,
                child: RouteStats(
                  live: true,
                  metrics: RouteMetrics(distance: distance, duration: duration),
                ),
              ),
            ),
          ),
        );
        expectEvenStatSpacing(tester);
        expectCompactUnit(tester, 2);
        for (var i = 2; i < 4; i++) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.byKey(ValueKey('live-stat-value-$i')),
          );
          expect(paragraph.didExceedMaxLines, isFalse);
        }
      }
    },
  );
}

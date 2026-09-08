import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/center_location_icon.dart';

Widget _button({
  required bool centered,
  bool courseUp = false,
  bool reducedMotion = false,
  bool visible = true,
  double textScale = 1,
}) => MaterialApp(
  theme: AppTheme.light,
  builder: AppTheme.builder,
  home: MediaQuery(
    data: MediaQueryData(
      disableAnimations: reducedMotion,
      textScaler: TextScaler.linear(textScale),
    ),
    child: TickerMode(
      enabled: visible,
      child: Scaffold(
        body: Center(
          child: MapSurface(
            child: AppIconButton(
              tooltip: 'Center on location',
              selected: centered,
              onPressed: () {},
              icon: CenterLocationIcon(centered: centered, courseUp: courseUp),
            ),
          ),
        ),
      ),
    ),
  ),
);

double _opacity(WidgetTester tester, IconData icon) => tester
    .widget<FadeTransition>(
      find.byKey(
        ValueKey(
          icon == Icons.near_me_outlined
              ? 'follow-free-opacity'
              : 'follow-active-opacity',
        ),
      ),
    )
    .opacity
    .value;

double _turns(WidgetTester tester, IconData icon) => tester
    .widget<RotationTransition>(
      find
          .ancestor(
            of: find.byIcon(icon),
            matching: find.byType(RotationTransition),
          )
          .first,
    )
    .turns
    .value;

void main() {
  testWidgets('orientation glyphs crossfade without moving the button', (
    tester,
  ) async {
    await tester.pumpWidget(_button(centered: true, textScale: 3));
    final bounds = tester.getRect(find.byType(CenterLocationIcon));
    await tester.pumpWidget(
      _button(centered: true, courseUp: true, textScale: 3),
    );
    await tester.pump(const Duration(milliseconds: 90));
    final switcher = find.descendant(
      of: find.byType(CenterLocationIcon),
      matching: find.byType(AnimatedSwitcher),
    );
    final fades = tester.widgetList<FadeTransition>(
      find.descendant(of: switcher, matching: find.byType(FadeTransition)),
    );
    expect(fades, hasLength(2));
    expect(
      fades.every((fade) => fade.opacity.value > 0 && fade.opacity.value < 1),
      isTrue,
    );
    expect(tester.getRect(find.byType(CenterLocationIcon)), bounds);
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(_button(centered: true, reducedMotion: true));
    expect(find.byIcon(Icons.explore), findsOneWidget);
    expect(find.byIcon(Icons.navigation), findsNothing);
    await tester.pumpWidget(_button(centered: true, courseUp: true));
    await tester.pump(const Duration(milliseconds: 90));
    await tester.pumpWidget(
      _button(centered: true, courseUp: true, visible: false),
    );
    expect(find.byIcon(Icons.navigation), findsOneWidget);
    expect(find.byIcon(Icons.explore), findsNothing);
    expect(tester.binding.transientCallbackCount, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final centered in [false, true]) {
    testWidgets('initial centered=$centered renders without animation', (
      tester,
    ) async {
      await tester.pumpWidget(_button(centered: centered));
      expect(_opacity(tester, Icons.explore), centered ? 1 : 0);
      expect(_opacity(tester, Icons.near_me_outlined), centered ? 0 : 1);
      expect(
        _turns(tester, centered ? Icons.explore : Icons.near_me_outlined),
        0,
      );
      expect(tester.binding.transientCallbackCount, 0);
    });

    testWidgets(
      'transition to centered=$centered rotates and fades without resizing',
      (tester) async {
        await tester.pumpWidget(_button(centered: !centered, textScale: 2));
        final buttonBounds = tester.getRect(find.byType(AppIconButton));
        final iconBounds = tester.getRect(find.byType(CenterLocationIcon));
        expect(buttonBounds.size, const Size(48, 48));
        expect(iconBounds.size, const Size(28, 28));
        expect(iconBounds.center, buttonBounds.center);
        await tester.pumpWidget(_button(centered: centered, textScale: 2));
        expect(_opacity(tester, Icons.explore), centered ? 0 : 1);
        await tester.pump(const Duration(milliseconds: 100));
        final progress = _opacity(tester, Icons.explore);
        expect(progress, inExclusiveRange(0, 1));
        expect(
          _opacity(tester, Icons.near_me_outlined),
          closeTo(1 - progress, 0.001),
        );
        expect(
          _turns(tester, Icons.explore),
          closeTo(0.125 * (1 - progress), 0.001),
        );
        expect(
          _turns(tester, Icons.near_me_outlined),
          closeTo(-0.125 * progress, 0.001),
        );
        expect(tester.getRect(find.byType(AppIconButton)), buttonBounds);
        expect(tester.getRect(find.byType(CenterLocationIcon)), iconBounds);
        await tester.pump(const Duration(milliseconds: 100));
        expect(_opacity(tester, Icons.explore), centered ? 1 : 0);
        await tester.pump(const Duration(milliseconds: 16));
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('rapid reversals continue from the displayed state', (
    tester,
  ) async {
    await tester.pumpWidget(_button(centered: false));
    await tester.pumpWidget(_button(centered: true));
    await tester.pump(const Duration(milliseconds: 80));
    final beforeReverse = _opacity(tester, Icons.explore);
    expect(beforeReverse, inExclusiveRange(0, 1));
    await tester.pumpWidget(_button(centered: false));
    expect(_opacity(tester, Icons.explore), beforeReverse);
    await tester.pump(const Duration(milliseconds: 40));
    final beforeForward = _opacity(tester, Icons.explore);
    expect(beforeForward, lessThan(beforeReverse));
    await tester.pumpWidget(_button(centered: true));
    expect(_opacity(tester, Icons.explore), beforeForward);
    await tester.pump(const Duration(milliseconds: 200));
    expect(_opacity(tester, Icons.explore), 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  for (final reducedMotion in [false, true]) {
    testWidgets(
      reducedMotion
          ? 'reduced motion snaps to the latest state'
          : 'hidden icon stops animating',
      (tester) async {
        await tester.pumpWidget(_button(centered: false));
        await tester.pumpWidget(_button(centered: true));
        await tester.pump(const Duration(milliseconds: 80));
        expect(_opacity(tester, Icons.explore), inExclusiveRange(0, 1));
        for (final centered in [true, false]) {
          await tester.pumpWidget(
            _button(
              centered: centered,
              visible: reducedMotion,
              reducedMotion: reducedMotion,
            ),
          );
          expect(_opacity(tester, Icons.explore), centered ? 1 : 0);
          expect(tester.binding.transientCallbackCount, 0);
        }
        await tester.pumpWidget(_button(centered: false));
        expect(_opacity(tester, Icons.explore), 0);
        expect(tester.binding.transientCallbackCount, 0);
        await tester.pumpWidget(_button(centered: true));
        await tester.pump(const Duration(milliseconds: 100));
        expect(_opacity(tester, Icons.explore), inExclusiveRange(0, 1));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.binding.transientCallbackCount, 0);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('animation frames only rebuild the local rotation transitions', (
    tester,
  ) async {
    await tester.pumpWidget(_button(centered: false));
    await tester.pumpWidget(_button(centered: true));
    final rebuilt = <Type>[];
    final previousObserver = debugOnRebuildDirtyWidget;
    debugOnRebuildDirtyWidget = (element, builtOnce) {
      previousObserver?.call(element, builtOnce);
      rebuilt.add(element.widget.runtimeType);
    };
    try {
      for (var frame = 0; frame < 10; frame++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(rebuilt, contains(RotationTransition));
      expect(rebuilt, isNot(contains(CenterLocationIcon)));
      expect(rebuilt, isNot(contains(AppIconButton)));
      expect(rebuilt, isNot(contains(MapSurface)));
      expect(rebuilt, isNot(contains(Icon)));
    } finally {
      debugOnRebuildDirtyWidget = previousObserver;
      await tester.pumpWidget(const SizedBox.shrink());
    }
    expect(tester.binding.transientCallbackCount, 0);
    expect(tester.takeException(), isNull);
  });
}

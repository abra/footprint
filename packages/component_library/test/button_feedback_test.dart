import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const _controlShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.all(Radius.circular(16)),
);

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in ['enabled', 'selected', 'disabled']) {
      testWidgets('$platform $mode icon feedback matches its surface', (
        tester,
      ) async {
        var taps = 0;
        final states = WidgetStatesController();
        addTearDown(states.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light.copyWith(platform: platform),
            home: Scaffold(
              body: Center(
                child: MapSurface(
                  child: IconButton(
                    tooltip: 'Action',
                    statesController: states,
                    isSelected: mode == 'selected',
                    onPressed: mode == 'disabled' ? null : () => taps++,
                    icon: const Icon(Icons.add),
                  ),
                ),
              ),
            ),
          ),
        );
        final button = find.byType(IconButton);
        final ink = find.descendant(of: button, matching: find.byType(InkWell));
        final surface = tester.widget<Material>(
          find
              .descendant(
                of: find.byType(MapSurface),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(surface.shape, _controlShape);
        expect(surface.clipBehavior, Clip.antiAlias);
        expect(tester.widget<InkWell>(ink).customBorder, _controlShape);
        final bounds = tester.getRect(button);
        expect(bounds.size, const Size(48, 48));

        if (mode != 'disabled') {
          for (final state in [WidgetState.hovered, WidgetState.focused]) {
            states.update(state, true);
            await tester.pump();
            expect(tester.widget<InkWell>(ink).customBorder, _controlShape);
            expect(tester.getRect(button), bounds);
            states.update(state, false);
          }
        }
        final gesture = await tester.startGesture(bounds.center);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));
        expect(states.value.contains(WidgetState.pressed), mode != 'disabled');
        expect(tester.widget<InkWell>(ink).customBorder, _controlShape);
        expect(tester.getRect(button), bounds);
        await gesture.up();
        await tester.pumpAndSettle();
        expect(taps, mode == 'disabled' ? 0 : 1);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }

  testWidgets('an explicitly circular button keeps circular feedback', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: IconButton(
            style: IconButton.styleFrom(shape: const CircleBorder()),
            onPressed: () {},
            icon: const Icon(Icons.close),
          ),
        ),
      ),
    );
    final ink = tester.widget<InkWell>(
      find.descendant(
        of: find.byType(IconButton),
        matching: find.byType(InkWell),
      ),
    );
    expect(ink.customBorder, const CircleBorder());
  });
}

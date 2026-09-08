import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

void main() {
  for (final dimension in [20.0, 22.0, 28.0, 32.0]) {
    testWidgets(
      '$dimension px icons keep their size and center in the button',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: AppTheme.builder,
            home: Scaffold(
              body: Center(
                child: AppIconButton(
                  tooltip: 'Action',
                  icon: Icon(
                    FLucideIcons.navigation,
                    size: dimension,
                    applyTextScaling: false,
                  ),
                  onPressed: () {},
                ),
              ),
            ),
          ),
        );
        final button = tester.getRect(find.byType(AppIconButton));
        final icon = tester.getRect(find.byIcon(FLucideIcons.navigation));
        expect(button.size, const Size(48, 48));
        expect(icon.size, Size.square(dimension));
        expect(icon.center, button.center);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    for (final mode in ['enabled', 'selected', 'disabled']) {
      for (final square in [false, true]) {
        testWidgets(
          '$platform $mode square=$square control keeps its shape and bounds',
          (tester) async {
            var taps = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light.copyWith(platform: platform),
                builder: AppTheme.builder,
                home: Scaffold(
                  body: Center(
                    child: MapSurface(
                      child: AppIconButton(
                        tooltip: 'Action',
                        selected: mode == 'selected',
                        square: square,
                        onPressed: mode == 'disabled' ? null : () => taps++,
                        icon: const Icon(FLucideIcons.plus),
                      ),
                    ),
                  ),
                ),
              ),
            );
            final button = find.byType(AppIconButton);
            final surface = tester.widget<Material>(
              find
                  .descendant(
                    of: find.byType(MapSurface),
                    matching: find.byType(Material),
                  )
                  .first,
            );
            expect(surface.shape, AppTheme.controlShape);
            final clip = tester.widget<ClipRRect>(
              find
                  .descendant(of: button, matching: find.byType(ClipRRect))
                  .first,
            );
            expect(clip.borderRadius, BorderRadius.circular(square ? 0 : 8));
            expect(
              find.descendant(of: button, matching: find.byType(InkWell)),
              findsNothing,
            );
            expect(
              find.descendant(of: button, matching: find.byType(FButton)),
              findsOneWidget,
            );
            final bounds = tester.getRect(button);
            expect(bounds.size, const Size(48, 48));
            final gesture = await tester.startGesture(bounds.center);
            await tester.pump(const Duration(milliseconds: 200));
            expect(tester.getRect(button), bounds);
            await gesture.up();
            await tester.pumpAndSettle();
            expect(taps, mode == 'disabled' ? 0 : 1);
            expect(tester.getRect(button), bounds);
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }

  testWidgets('commands support keyboard activation and wrap large labels', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => AppTheme.builder(
          context,
          MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
        ),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 200,
              child: AppButton(
                onPressed: () => taps++,
                label: 'Generate another route',
                prefix: const Icon(FLucideIcons.route),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(taps, 1);
    expect(tester.getSize(find.byType(AppButton)).width, 200);
    expect(tester.takeException(), isNull);
  });
}

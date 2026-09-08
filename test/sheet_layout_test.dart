import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../packages/component_library/test/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final (size, scale, viewport) in [
    (const Size(390, 844), 1.0, 'phone'),
    (const Size(320, 568), 2.0, 'small_large_text'),
    (const Size(844, 390), 2.0, 'landscape_large_text'),
  ]) {
    testWidgets('sheet actions are separated and reachable at $viewport', (
      tester,
    ) async {
      final previousShadows = debugDisableShadows;
      debugDisableShadows = false;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetPhysicalSize);
        String? selected;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: AppTheme.builder(context, child),
            ),
            home: Scaffold(
              body: Center(
                child: Builder(
                  builder: (context) => AppButton(
                    compact: true,
                    label: 'Sort routes',
                    onPressed: () async {
                      selected = await showAppActionSheet<String>(
                        context,
                        title: 'Sort routes',
                        actions: const [
                          SheetAction(
                            value: 'newest',
                            label: 'Newest first',
                            icon: FLucideIcons.arrowDown,
                            selected: true,
                          ),
                          SheetAction(
                            value: 'oldest',
                            label: 'Oldest first',
                            icon: FLucideIcons.arrowUp,
                          ),
                          SheetAction(
                            value: 'name',
                            label: 'Name',
                            icon: FLucideIcons.arrowDownAZ,
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        );
        Future<void> open() async {
          await tester.tap(find.widgetWithText(AppButton, 'Sort routes'));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
        }

        await open();
        final bounds = [
          for (final title in ['Newest first', 'Oldest first', 'Name'])
            tester.getRect(find.widgetWithText(FTile, title)),
        ];
        final heading = tester.getRect(find.text('Sort routes').last);
        expect(bounds.first.top - heading.bottom, greaterThanOrEqualTo(16));
        for (var i = 1; i < bounds.length; i++) {
          expect(bounds[i].top - bounds[i - 1].bottom, closeTo(8, 0.01));
          expect(bounds[i].left, bounds.first.left);
          expect(bounds[i].width, bounds.first.width);
          expect(bounds[i].height, greaterThanOrEqualTo(48));
        }
        final cancel = tester.getRect(find.widgetWithText(AppButton, 'Cancel'));
        expect(cancel.top - bounds.last.bottom, greaterThanOrEqualTo(12));
        await expectLater(
          find.byType(AppSheet),
          matchesGoldenFile('goldens/action_sheet_$viewport.png'),
        );
        await tester.ensureVisible(find.text('Name'));
        await tester.tap(find.text('Name'));
        await tester.pumpAndSettle();
        expect(selected, 'name');
        expect(find.byType(AppSheet), findsNothing);

        await open();
        await tester.ensureVisible(find.widgetWithText(AppButton, 'Cancel'));
        await tester.tap(find.widgetWithText(AppButton, 'Cancel'));
        await tester.pumpAndSettle();
        expect(selected, isNull);
        expect(find.byType(AppSheet), findsNothing);
        expect(tester.takeException(), isNull);
      } finally {
        debugDisableShadows = previousShadows;
      }
    });
  }
}

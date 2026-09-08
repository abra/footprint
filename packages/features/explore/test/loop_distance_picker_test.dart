import 'package:component_library/component_library.dart';
import 'package:explore/src/loop_distance_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';

import '../../../component_library/test/load_fonts.dart';

void main() {
  setUpAll(loadAppFonts);
  for (final (width, scale) in [(288.0, 2.0), (358.0, 1.0), (568.0, 2.0)]) {
    testWidgets('distance grid layout and selection at $width / $scale', (
      tester,
    ) async {
      var distance = 3000.0;
      var changes = 0;
      var customRequests = 0;
      var clearRequests = 0;
      var enabled = true;
      late StateSetter rebuild;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => AppTheme.builder(
            context,
            MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: width,
                height: scale == 1 ? 144 : 300,
                child: StatefulBuilder(
                  builder: (context, setState) {
                    rebuild = setState;
                    return LoopDistancePicker(
                      distance: distance,
                      hasPlan: true,
                      onSelected: enabled
                          ? (value) => setState(() {
                              distance = value;
                              changes++;
                            })
                          : null,
                      onCustomRequested: enabled
                          ? () => customRequests++
                          : null,
                      onClear: enabled ? () => clearRequests++ : null,
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );
      final bounds = [
        for (final km in [1, 3, 5, 10])
          tester.getRect(find.widgetWithText(FButton, '$km km')),
      ];
      expect(bounds[0].top, bounds[1].top);
      expect(bounds[2].top, bounds[3].top);
      expect(bounds[0].left, bounds[2].left);
      expect(bounds[1].left, bounds[3].left);
      expect(bounds[1].left - bounds[0].right, 8);
      expect(bounds[2].top - bounds[0].bottom, 8);
      for (final rect in bounds) {
        expect(rect.size, bounds.first.size);
        expect(rect.height, greaterThanOrEqualTo(48));
      }
      final pickerBounds = tester.getRect(find.byType(LoopDistancePicker));
      for (final km in [3, 1, 5, 10, 3]) {
        await tester.tap(find.text('$km km'));
        await tester.pumpAndSettle();
        expect(distance, km * 1000);
        expect(tester.getRect(find.byType(LoopDistancePicker)), pickerBounds);
        for (final option in [1, 3, 5, 10]) {
          expect(
            tester
                .widget<FButton>(find.widgetWithText(FButton, '$option km'))
                .selected,
            option == km,
          );
        }
      }
      expect(
        changes,
        4,
        reason: 'Selecting the active preset must preserve the preview.',
      );
      await tester.tap(find.byTooltip('Change distance'));
      await tester.tap(find.byTooltip('Clear route'));
      expect(customRequests, 1);
      expect(clearRequests, 1);
      rebuild(() => distance = 2500);
      await tester.pumpAndSettle();
      expect(find.text('Custom: 2.5 km'), findsOneWidget);
      for (final km in [1, 3, 5, 10]) {
        expect(
          tester
              .widget<FButton>(find.widgetWithText(FButton, '$km km'))
              .selected,
          isFalse,
        );
      }
      rebuild(() => distance = 2550);
      await tester.pumpAndSettle();
      expect(find.text('Custom: 2.55 km'), findsOneWidget);
      rebuild(() {
        distance = 2500;
        enabled = false;
      });
      await tester.pumpAndSettle();
      for (final km in [1, 3, 5, 10]) {
        expect(
          tester
              .widget<FButton>(find.widgetWithText(FButton, '$km km'))
              .onPress,
          isNull,
        );
        await tester.tap(find.text('$km km'));
      }
      await tester.tap(find.byTooltip('Change distance'));
      await tester.tap(find.byTooltip('Clear route'));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.pumpAndSettle();
      expect(distance, 2500);
      expect(changes, 4);
      expect(customRequests, 1);
      expect(clearRequests, 1);
      expect(tester.takeException(), isNull);
    });
  }
}

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final count in [0, 1, 3]) {
    testWidgets('tile list separates $count items without outer gaps', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 320,
              child: AppTileList(
                children: [
                  for (var i = 0; i < count; i++)
                    SizedBox(key: ValueKey(i), height: 48 + i * 24),
                ],
              ),
            ),
          ),
        ),
      );
      final list = tester.getRect(find.byType(AppTileList));
      if (count == 0) {
        expect(list.height, 0);
      } else {
        final bounds = [
          for (var i = 0; i < count; i++)
            tester.getRect(find.byKey(ValueKey(i))),
        ];
        expect(bounds.first.top, list.top);
        expect(bounds.last.bottom, list.bottom);
        for (final item in bounds) {
          expect(item.left, list.left);
          expect(item.right, list.right);
        }
        for (var i = 1; i < count; i++) {
          expect(bounds[i].top - bounds[i - 1].bottom, 8);
        }
      }
      expect(tester.takeException(), isNull);
    });
  }
}

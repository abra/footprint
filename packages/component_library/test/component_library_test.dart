import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'application theme supplies color extensions to feature widgets',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: ColoredBox(
                color: context.appColors.appWhite,
                child: const Text('Footprint'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Footprint'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

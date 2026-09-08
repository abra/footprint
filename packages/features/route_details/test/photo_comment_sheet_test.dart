import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_details/src/photo_comment_sheet.dart';

import 'timeline_fakes.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    String comment = '',
    required Future<bool> Function(String) save,
    void Function(String?)? onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: Builder(
          builder: (context) => Scaffold(
            body: AppButton(
              label: 'Open',
              onPressed: () async {
                final result = await showPhotoCommentSheet(
                  context,
                  photo: timelinePhoto(comment: comment),
                  onSave: save,
                );
                onResult?.call(result);
              },
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
  }

  testWidgets(
    'failure retains the draft; retry blocks duplicate saves without a spinner',
    (tester) async {
      var calls = 0;
      String? result;
      var gate = Completer<bool>();
      await open(
        tester,
        save: (comment) {
          expect(comment, 'By the river');
          calls++;
          return gate.future;
        },
        onResult: (value) => result = value,
      );
      await tester.enterText(find.byType(EditableText), '  By the river  ');
      await tester.tap(find.text('Save comment'));
      await tester.pump();
      await tester.tap(find.text('Save comment'));
      await tester.pump();
      expect(calls, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        '  By the river  ',
      );
      gate.complete(false);
      await tester.pumpAndSettle();
      expect(
        find.text('Comment could not be saved. Try again.'),
        findsOneWidget,
      );
      gate = Completer<bool>();
      await tester.tap(find.text('Save comment'));
      await tester.pump();
      gate.complete(true);
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(result, 'By the river');
      expect(find.text('Photo comment'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancel discards the draft without saving; an empty comment removes existing text',
    (tester) async {
      var calls = 0;
      String? saved;
      await open(
        tester,
        comment: 'Old comment',
        save: (text) async {
          calls++;
          saved = text;
          return true;
        },
      );
      await tester.enterText(find.byType(EditableText), 'Discard this');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<EditableText>(find.byType(EditableText)).controller.text,
        'Old comment',
      );
      await tester.enterText(find.byType(EditableText), '');
      await tester.tap(find.text('Save comment'));
      await tester.pumpAndSettle();
      expect(calls, 1);
      expect(saved, '');
    },
  );

  testWidgets('unchanged comments close without a redundant write', (
    tester,
  ) async {
    await open(
      tester,
      comment: 'Same',
      save: (_) => throw StateError('Unexpected write'),
    );
    await tester.tap(find.text('Save comment'));
    await tester.pumpAndSettle();
    expect(find.text('Photo comment'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

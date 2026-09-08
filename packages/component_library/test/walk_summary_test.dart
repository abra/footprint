import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../domain_models/test/walk_fixtures.dart';

void main() {
  for (final loop in [false, true]) {
    for (final recording in [false, true]) {
      for (final complete in [false, true]) {
        testWidgets(
          'walk summary loop=$loop recording=$recording complete=$complete',
          (tester) async {
            final plan = loop ? loopPlan() : pointToPointPlan();
            await tester.pumpWidget(
              MaterialApp(
                home: Scaffold(
                  body: WalkSummary(
                    progress: WalkProgress(
                      routeId: 1,
                      plan: plan,
                      reached: complete ? plan.checkpoints.length : 0,
                      newCells: 2,
                      recording: recording,
                    ),
                    location: walkFix(plan.points.first, 0),
                  ),
                ),
              ),
            );
            final title = complete
                ? loop
                      ? 'Loop completed'
                      : recording
                      ? 'Destination reached'
                      : 'Walk completed'
                : recording
                ? 'Walking route'
                : 'Walk ended early';
            expect(find.text(title), findsOneWidget);
            expect(
              find.text('Recording continues'),
              complete && recording ? findsOneWidget : findsNothing,
            );
            expect(
              find.textContaining('straight-line'),
              complete ? findsNothing : findsOneWidget,
            );
            expect(
              tester
                  .widget<LinearProgressIndicator>(
                    find.byType(LinearProgressIndicator),
                  )
                  .value,
              complete ? 1 : 0,
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
  }
}

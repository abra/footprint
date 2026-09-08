import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:explore/src/planning_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recording_service/recording_service.dart';

import '../../../component_library/test/load_fonts.dart';
import 'fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final reducedInitially in [false, true]) {
    testWidgets('planning fade and reduced motion ($reducedInitially)', (
      tester,
    ) async {
      final location = FakeLocationService();
      final recording = RecordingService(
        locationService: location,
        routesRepository: FakeRoutesRepository(),
      );
      final planner = FakePlanner();
      final cubit = ExploreCubit(
        planner: planner,
        walks: FakeWalks(),
        recording: recording,
      );
      var reduced = reducedInitially;
      late StateSetter rebuild;
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: AppTheme.builder,
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(disableAnimations: reduced),
                    child: BlocProvider.value(
                      value: cubit,
                      child: BlocBuilder<ExploreCubit, ExploreState>(
                        builder: (context, state) => Center(
                          child: SizedBox(
                            width: 358,
                            child: PlanningSettings(
                              state: state,
                              onPick: (_) {},
                              onCancelPick: () {},
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        List<double> opacities() =>
            tester
                .widgetList<FadeTransition>(
                  find.descendant(
                    of: find.byType(AnimatedCrossFade),
                    matching: find.byType(FadeTransition),
                  ),
                )
                .map((fade) => fade.opacity.value)
                .toList()
              ..sort();
        final bounds = tester.getRect(find.byType(PlanningSettings));
        expect(opacities(), [0, 1]);
        cubit.selectMode(RoutePlanMode.pointToPoint);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(tester.getRect(find.byType(PlanningSettings)), bounds);
        expect(find.byTooltip('Change distance').hitTestable(), findsNothing);
        if (reducedInitially) {
          expect(opacities(), [0, 1]);
        } else {
          expect(opacities().first, 0);
          expect(opacities().last, inExclusiveRange(0, 1));
          cubit.selectMode(RoutePlanMode.loop);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 20));
          expect(tester.getRect(find.byType(PlanningSettings)), bounds);
          expect(find.text('Start').hitTestable(), findsNothing);
          cubit.selectMode(RoutePlanMode.pointToPoint);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 30));
          rebuild(() => reduced = true);
          await tester.pump();
          expect(opacities(), [0, 1]);
          expect(find.byTooltip('Change distance').hitTestable(), findsNothing);
        }
        cubit.selectMode(RoutePlanMode.loop);
        await tester.pump();
        expect(opacities(), [0, 1]);
        expect(tester.getRect(find.byType(PlanningSettings)), bounds);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await cubit.close();
        planner.dispose();
        await tester.runAsync(() async {
          await recording.dispose();
          await location.dispose();
        });
      }
    });
  }
}

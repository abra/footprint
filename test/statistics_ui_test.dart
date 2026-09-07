import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:statistics/src/distance_chart.dart';
import 'package:statistics/src/statistics_cubit.dart';
import 'package:statistics/src/statistics_screen.dart';
import 'package:statistics/src/statistics_view.dart';

import '../packages/features/statistics/test/fakes.dart';

void main() {
  setUpAll(() async {
    await (FontLoader('packages/component_library/RobotoCondensed')..addFont(
          rootBundle.load(
            'packages/component_library/fonts/RobotoCondensed.ttf',
          ),
        ))
        .load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  Future<void> pumpView(
    WidgetTester tester,
    StatisticsCubit cubit,
    Size size,
    double scale,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      RepaintBoundary(
        key: const ValueKey('statistics-design'),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: BlocProvider.value(
            value: cubit,
            child: StatisticsView(onBack: () {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final (size, scale, name) in [
    (const Size(390, 844), 1.0, 'phone'),
    (const Size(320, 568), 2.0, 'small_large_text'),
    (const Size(844, 390), 2.0, 'landscape_large_text'),
    (const Size(1024, 768), 1.0, 'tablet'),
  ]) {
    testWidgets('statistics layout and interactions $name', (tester) async {
      final repository = StatisticsRepositoryFake();
      final cubit = StatisticsCubit(
        repository: repository,
        clock: statisticsNow,
      );
      addTearDown(cubit.close);
      await cubit.load();
      await pumpView(tester, cubit, size, scale);
      expect(find.text('25.5 km'), findsOneWidget);
      expect(find.text('Active days'), findsOneWidget);
      final semantics = tester.ensureSemantics();
      try {
        final bucketSemantics = tester.getSemantics(
          find.bySemanticsLabel(RegExp('Tuesday, September 8, 2026:')),
        );
        expect(
          bucketSemantics.getSemanticsData().hasAction(SemanticsAction.tap),
          isTrue,
        );
      } finally {
        semantics.dispose();
      }
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is IconButton && widget.tooltip == 'Next period',
              ),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
      if (name == 'phone' || name == 'tablet') {
        await expectLater(
          find.byKey(const ValueKey('statistics-design')),
          matchesGoldenFile('goldens/statistics_$name.png'),
        );
      }
      final bar = find.byKey(const ValueKey('statistics-bucket-1'));
      await tester.ensureVisible(bar);
      await tester.pumpAndSettle();
      await tester.tap(bar);
      await tester.pumpAndSettle();
      expect(cubit.state.selected, 1);
      expect(find.text('5.1 km'), findsOneWidget);
      await tester.ensureVisible(find.text('Month'));
      await tester.tap(find.text('Month'));
      await tester.pumpAndSettle();
      expect(cubit.state.data!.buckets, hasLength(30));
      expect(repository.reads, 1);
      await tester.tap(find.byTooltip('Previous period'));
      await tester.pumpAndSettle();
      expect(find.text('No recordings in this period'), findsOneWidget);
      await tester.ensureVisible(find.text('View all time'));
      await tester.tap(find.text('View all time'));
      await tester.pumpAndSettle();
      expect(find.text('Distance by month'), findsOneWidget);
      expect(find.byTooltip('Previous period'), findsNothing);
      await tester.tap(find.byTooltip('About statistics'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('Done'));
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      for (final paragraph
          in tester.allRenderObjects.whereType<RenderParagraph>()) {
        expect(
          paragraph.didExceedMaxLines,
          isFalse,
          reason: paragraph.text.toPlainText(),
        );
      }
    });
  }

  testWidgets(
    'loading, initial failure, retry, refresh failure and empty history',
    (tester) async {
      final gate = Completer<List<RecordedRouteSummary>>();
      final repository = StatisticsRepositoryFake()
        ..response = () => gate.future;
      final cubit = StatisticsCubit(
        repository: repository,
        clock: statisticsNow,
      );
      addTearDown(cubit.close);
      await pumpView(tester, cubit, const Size(390, 844), 1);
      final pending = cubit.load();
      await tester.pump();
      await tester.pump();
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      gate.completeError(StateError('Offline'));
      await pending;
      await tester.pumpAndSettle();
      expect(find.text('Statistics could not be loaded.'), findsOneWidget);
      expect(find.text('No recordings in this period'), findsNothing);
      repository.response = () async => statisticsRecords();
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('25.5 km'), findsOneWidget);
      repository.response = () async => throw StateError('Offline');
      await tester.tap(find.byTooltip('Refresh statistics'));
      await tester.pumpAndSettle();
      expect(find.text('Statistics could not be refreshed.'), findsOneWidget);
      expect(find.text('25.5 km'), findsOneWidget);
      repository.response = () async => [];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('View all time'));
      await tester.tap(find.text('View all time'));
      await tester.pumpAndSettle();
      expect(find.text('No saved recordings yet'), findsOneWidget);
      expect(find.byType(DistanceChart), findsNothing);
    },
  );

  testWidgets('large totals fit at 320px with 2x text', (tester) async {
    final repository = StatisticsRepositoryFake()
      ..response = () async => [
        RecordedRouteSummary(
          id: 1,
          startedAt: statisticsNow(),
          distance: 999999999,
          duration: const Duration(hours: 99999),
        ),
      ];
    final cubit = StatisticsCubit(repository: repository, clock: statisticsNow);
    addTearDown(cubit.close);
    await cubit.load();
    await pumpView(tester, cubit, const Size(320, 568), 2);
    expect(tester.takeException(), isNull);
    for (final paragraph
        in tester.allRenderObjects.whereType<RenderParagraph>()) {
      expect(
        paragraph.didExceedMaxLines,
        isFalse,
        reason: paragraph.text.toPlainText(),
      );
    }
  });

  testWidgets(
    'screen refreshes on resume and releases its lifecycle observer',
    (tester) async {
      final repository = StatisticsRepositoryFake();
      await tester.pumpWidget(
        MaterialApp(
          home: StatisticsScreen(repository: repository, onBack: () {}),
        ),
      );
      await tester.pumpAndSettle();
      final cubit = tester
          .element(find.byType(StatisticsView))
          .read<StatisticsCubit>();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();
      expect(repository.reads, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(cubit.isClosed, isTrue);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(repository.reads, 2);
    },
  );
}

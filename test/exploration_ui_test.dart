import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:explore/src/loop_distance_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_planning/route_planning.dart';

import '../packages/component_library/test/load_fonts.dart';
import '../packages/component_library/test/pump_map_ui.dart';
import '../packages/features/explore/test/fakes.dart';
import 'design_golden_test.dart' show FixtureTiles, tileFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List tile;
  setUpAll(() async {
    tile = await tileFixture();
    await loadAppFonts();
  });

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 2.0),
  ]) {
    testWidgets('planning, discovery and distance sheet fit $size at $scale', (
      tester,
    ) async {
      debugDisableShadows = false;
      try {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final service = FakeLocationService()
          ..lastLocation = walkFix(loopPlan().points.first, -600)
          ..currentLocationGate = Completer<LocationDM>();
        final recording = RecordingService(
          locationService: service,
          routesRepository: FakeRoutesRepository(),
        );
        final walks = FakeWalks()
          ..cells = [ExplorationCell.at(loopPlan().points.first)]
          ..profile = const ExplorationProfile(
            cells: 12,
            completedWalks: 1,
            achievements: {
              ExplorationAchievement.firstWalk,
              ExplorationAchievement.tenAreas,
            },
          );
        final planner = FakePlanner();
        final cubit = ExploreCubit(
          planner: planner,
          walks: walks,
          recording: recording,
          now: () => walkEpoch.add(const Duration(seconds: 1)),
        );
        var backRequests = 0;
        await tester.pumpWidget(
          MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()),
        );
        await tester.runAsync(
          () => precacheImage(
            MemoryImage(tile),
            tester.element(find.byType(SizedBox)),
          ),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale)),
              child: AppTheme.builder(context, child),
            ),
            home: BlocProvider(
              create: (_) => cubit..initialize(),
              child: RepaintBoundary(
                key: const ValueKey('explore-golden'),
                child: ExploreView(
                  config: MapTileConfig(
                    tileProviderFactory: () => FixtureTiles(tile),
                  ),
                  onBack: () => backRequests++,
                ),
              ),
            ),
          ),
        );
        await pumpMapUi(tester);
        expect(tester.takeException(), isNull);
        final clearRoute = find
            .byWidgetPredicate(
              (widget) =>
                  widget is AppIconButton && widget.tooltip == 'Clear route',
            )
            .hitTestable();
        expect(clearRoute, findsNothing);
        expect(find.byType(ExploredAreasLayer), findsNothing);
        final initialPanel = tester.getRect(
          find.byKey(const ValueKey('explore-panel')),
        );
        final initialPickerSize = tester.getSize(
          find.byType(LoopDistancePicker),
        );
        final viewport = scale == 1
            ? 'phone'
            : size.width < size.height
            ? 'small_large_text'
            : 'landscape_large_text';
        await expectLater(
          find.byKey(const ValueKey('explore-golden')),
          matchesGoldenFile('goldens/loop_distance_grid_$viewport.png'),
        );
        final actions = tester.widget<AppBar>(find.byType(AppBar)).actions!;
        expect(actions, hasLength(1));
        expect((actions.single as AppIconButton).tooltip, 'Center map');
        expect(find.byTooltip('Expand planner'), findsNothing);
        expect(find.byTooltip('Collapse planner'), findsNothing);
        await tester.tap(find.byTooltip('Center map'));
        await pumpMapUi(tester);
        expect(
          tester.getRect(find.byKey(const ValueKey('explore-panel'))),
          initialPanel,
        );
        expect(
          tester
              .widget<FButton>(find.byKey(const ValueKey('loop-distance-3000')))
              .selected,
          isTrue,
        );
        await tester.ensureVisible(find.text('5 km'));
        await tester.tap(find.text('5 km'));
        await pumpMapUi(tester);
        expect(cubit.state.distance, 5000);
        expect(find.byType(AppSheet), findsNothing);
        await tester.ensureVisible(find.byTooltip('Change distance'));
        await tester.tap(find.byTooltip('Change distance'));
        await pumpMapUi(tester);
        expect(find.byType(AppSheet), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        expect(
          find.descendant(
            of: find.byType(AppSheet),
            matching: find.byType(FTile),
          ),
          findsNothing,
        );
        await expectLater(
          find.byType(AppSheet),
          matchesGoldenFile('goldens/distance_sheet_$viewport.png'),
        );
        await tester.ensureVisible(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), '5');
        await tester.ensureVisible(find.text('Set distance'));
        await tester.tap(find.text('Set distance'));
        await pumpMapUi(tester);
        expect(cubit.state.distance, 5000);
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await tester.pump();
        expect(find.text('Getting current location...'), findsOneWidget);
        expect(cubit.state.visibleError, isNull);
        expect(cubit.state.plan, isNull);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Cancel'));
        await tester.tap(find.text('Cancel'));
        await pumpMapUi(tester);
        expect(find.text('Getting current location...'), findsNothing);
        expect(find.text('Generate route'), findsOneWidget);
        service.currentLocationGate!.completeError(
          TimeoutException('Cancelled fix'),
        );
        await pumpMapUi(tester);
        expect(cubit.state.visibleError, isNull);
        service.currentLocationGate = Completer<LocationDM>();
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await tester.pump();
        service.currentLocationGate!.complete(
          walkFix(loopPlan().points.first, 0),
        );
        await pumpMapUi(tester);
        expect(cubit.state.plan, isNotNull);
        expect(find.byType(LoopDistancePicker), findsNothing);
        expect(find.text('Your walk'), findsOneWidget);
        expect(find.byType(PlannedRouteLayer), findsOneWidget);
        expect(tester.takeException(), isNull);
        final startWalk = find.widgetWithText(AppButton, 'Start walk');
        final regenerate = find.byWidgetPredicate(
          (widget) =>
              widget is AppIconButton && widget.tooltip == 'Generate another',
        );
        void expectActionVisible(Finder action) {
          final bounds = tester.getRect(action);
          final panel = tester.getRect(
            find.byKey(const ValueKey('explore-panel')),
          );
          expect(
            panel.intersect(bounds),
            bounds,
            reason: 'The entire action must be visible without scrolling',
          );
          expect((Offset.zero & size).intersect(bounds), bounds);
          expect(action.hitTestable(), findsOneWidget);
          expect(bounds.height, greaterThanOrEqualTo(48));
        }

        expectActionVisible(startWalk);
        expectActionVisible(regenerate);
        final startBounds = tester.getRect(startWalk);
        final regenerateBounds = tester.getRect(regenerate);
        final editBounds = tester.getRect(find.byTooltip('Edit route'));
        final clearBounds = tester.getRect(find.byTooltip('Clear route'));
        final details = find.byKey(const ValueKey('plan-details-scroll'));
        await tester.drag(details, const Offset(0, -200));
        await pumpMapUi(tester);
        expect(tester.getRect(startWalk), startBounds);
        expect(tester.getRect(regenerate), regenerateBounds);
        expectActionVisible(startWalk);
        expectActionVisible(regenerate);
        await tester.drag(details, const Offset(0, 1000));
        await pumpMapUi(tester);
        final calls = planner.calls;
        await tester.tap(regenerate);
        await pumpMapUi(tester);
        expect(planner.calls, calls + 1);
        expect(cubit.state.previousPreview, isNotNull);
        expect(tester.getRect(find.byTooltip('Edit route')), editBounds);
        expect(tester.getRect(find.byTooltip('Clear route')), clearBounds);
        expectActionVisible(startWalk);
        expectActionVisible(regenerate);
        for (final tooltip in [
          'Edit route',
          'Clear route',
          'Restore previous route',
        ]) {
          final tool = find.byWidgetPredicate(
            (widget) => widget is AppIconButton && widget.tooltip == tooltip,
          );
          expectActionVisible(tool);
          final icon = find.descendant(of: tool, matching: find.byType(Icon));
          expect(IconTheme.of(tester.element(icon)).color, AppTheme.ink);
        }
        await expectLater(
          find.byKey(const ValueKey('explore-golden')),
          matchesGoldenFile(
            'goldens/walk_plan${scale == 1 ? '' : '_$viewport'}.png',
          ),
        );
        final previousPreview = cubit.state.previousPreview!;
        await tester.ensureVisible(find.byTooltip('Restore previous route'));
        await tester.tap(find.byTooltip('Restore previous route'));
        await pumpMapUi(tester);
        expect(cubit.state.plan, same(previousPreview.plan));
        expect(cubit.state.newAreas, previousPreview.newAreas);
        expect(planner.calls, calls + 1);
        expect(
          tester
              .widget<AppIconButton>(
                find.byWidgetPredicate(
                  (widget) =>
                      widget is AppIconButton &&
                      widget.tooltip == 'Restore previous route',
                ),
              )
              .onPressed,
          isNull,
        );
        planner.pending = Completer<RoutePlan>();
        await tester.tap(regenerate);
        await tester.pump();
        await tester.pump();
        expect(cubit.state.generating, isTrue);
        expect(find.byType(PlannedRouteLayer), findsOneWidget);
        expect(cubit.state.plan, same(previousPreview.plan));
        await tester.tap(find.text('Cancel'));
        planner.pending!.completeError(const RoutePlanningException('Offline'));
        await pumpMapUi(tester);
        expect(cubit.state.plan, same(previousPreview.plan));
        expect(cubit.state.visibleError, isNull);
        expectActionVisible(startWalk);
        planner.pending = Completer<RoutePlan>();
        await tester.tap(regenerate);
        await tester.pump();
        await tester.pump();
        await tester.tap(find.byTooltip('Edit route'));
        planner.pending!.complete(loopPlan(id: 'late'));
        await pumpMapUi(tester);
        expect(cubit.state.generating, isFalse);
        expect(cubit.state.plan, same(previousPreview.plan));
        expect(find.text('Show route'), findsOneWidget);
        await tester.tap(find.text('Show route'));
        await pumpMapUi(tester);
        expectActionVisible(startWalk);
        planner.pending = null;
        planner.error = const RoutePlanningException('Offline');
        await tester.tap(regenerate);
        await pumpMapUi(tester);
        expect(cubit.state.plan, same(previousPreview.plan));
        expect(find.text('Offline'), findsOneWidget);
        expect(tester.widget<AppButton>(startWalk).onPressed, isNotNull);
        planner.error = null;
        await tester.ensureVisible(clearRoute);
        final map = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        final camera = map.camera;
        await tester.tap(clearRoute);
        await pumpMapUi(tester);
        expect(find.byType(PlannedRouteLayer), findsNothing);
        expect(find.text('Start walk'), findsNothing);
        expect(clearRoute, findsNothing);
        expect(find.text('Generate route'), findsOneWidget);
        expect(find.byType(AppSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(map.camera.center, camera.center);
        expect(map.camera.zoom, camera.zoom);
        expect(cubit.state.distance, 5000);
        expect(cubit.state.newAreas, 0);
        expect(cubit.state.profile, walks.profile);
        expect(find.byType(ExploredAreasLayer), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await pumpMapUi(tester);
        expect(find.byType(PlannedRouteLayer), findsOneWidget);
        expect(clearRoute, findsOneWidget);
        await tester.tap(find.text('Exploration'));
        await pumpMapUi(tester);
        expect(
          tester
              .widget<ExploredAreasLayer>(find.byType(ExploredAreasLayer))
              .cells,
          walks.cells,
        );
        expect(find.text('12 areas explored'), findsOneWidget);
        final achievementBounds = [
          for (final achievement in ExplorationAchievement.values)
            tester.getRect(find.widgetWithText(FTile, achievement.title)),
        ];
        for (var i = 1; i < achievementBounds.length; i++) {
          expect(
            achievementBounds[i].top - achievementBounds[i - 1].bottom,
            closeTo(8, 0.01),
          );
        }
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byKey(const ValueKey('explore-golden')),
            matchesGoldenFile('goldens/exploration.png'),
          );
        }
        await tester.tap(find.text('Plan a walk').last);
        await pumpMapUi(tester);
        expect(find.byType(ExploredAreasLayer), findsNothing);
        expect(cubit.state.cells, walks.cells);
        final previousPlan = cubit.state.plan;
        await tester.ensureVisible(find.byTooltip('Edit route'));
        await tester.tap(find.byTooltip('Edit route'));
        await pumpMapUi(tester);
        expect(cubit.state.plan, same(previousPlan));
        await tester.tap(find.text('Show route'));
        await pumpMapUi(tester);
        expect(cubit.state.plan, same(previousPlan));
        await tester.ensureVisible(find.byTooltip('Edit route'));
        await tester.tap(find.byTooltip('Edit route'));
        await pumpMapUi(tester);
        await tester.ensureVisible(find.byTooltip('Change distance'));
        await tester.tap(find.byTooltip('Change distance'));
        await pumpMapUi(tester);
        await tester.ensureVisible(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), '4');
        await tester.binding.handlePopRoute();
        await pumpMapUi(tester);
        expect(find.byType(AppSheet), findsNothing);
        expect(cubit.state.distance, 5000);
        expect(cubit.state.plan, same(previousPlan));
        await tester.ensureVisible(find.byTooltip('Change distance'));
        await tester.tap(find.byTooltip('Change distance'));
        await pumpMapUi(tester);
        await tester.ensureVisible(find.byType(EditableText));
        await tester.enterText(find.byType(EditableText), '99');
        await tester.ensureVisible(find.text('Set distance'));
        await tester.tap(find.text('Set distance'));
        await pumpMapUi(tester);
        expect(
          find.text('Enter a distance between 1 and 20 km'),
          findsOneWidget,
        );
        final validation = tester.renderObject<RenderParagraph>(
          find.descendant(
            of: find.text('Enter a distance between 1 and 20 km'),
            matching: find.byType(RichText),
          ),
        );
        expect(validation.didExceedMaxLines, isFalse);
        expect(tester.takeException(), isNull);
        await tester.enterText(find.byType(EditableText), '2,5');
        await tester.ensureVisible(find.text('Set distance'));
        await tester.tap(find.text('Set distance'));
        await pumpMapUi(tester);
        expect(cubit.state.distance, 2500);
        expect(find.byType(AppSheet), findsNothing);
        expect(find.text('Custom: 2.5 km'), findsOneWidget);
        expect(
          tester.getRect(find.byKey(const ValueKey('explore-panel'))),
          initialPanel,
        );
        expect(
          tester.getSize(find.byType(LoopDistancePicker)),
          initialPickerSize,
        );
        for (final meters in [1000, 3000, 5000, 10000]) {
          expect(
            tester
                .widget<FButton>(find.byKey(ValueKey('loop-distance-$meters')))
                .selected,
            isFalse,
          );
        }
        await cubit.generate();
        await cubit.start();
        await pumpMapUi(tester);
        expect(backRequests, 1);
        for (final meters in [1000, 3000, 5000, 10000]) {
          expect(
            tester
                .widget<FButton>(find.byKey(ValueKey('loop-distance-$meters')))
                .onPress,
            isNull,
          );
        }
        final disabledClear = find.descendant(
          of: find.byType(LoopDistancePicker),
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is AppIconButton && widget.tooltip == 'Clear route',
          ),
        );
        expect(tester.widget<AppIconButton>(disabledClear).onPressed, isNull);
        service.send(walkFix(loopPlan().points.first, 2));
        await cubit.refreshProfile();
        await pumpMapUi(tester);
        expect(
          backRequests,
          1,
          reason: 'GPS updates during exit must not pop another screen',
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await recording.dispose();
          await service.dispose();
        });
      } finally {
        debugDisableShadows = true;
      }
    });
  }

  testWidgets(
    'action sheet cancellation is nondestructive and actions return typed results',
    (tester) async {
      String? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: AppTheme.builder,
          home: Scaffold(
            body: Builder(
              builder: (context) => IconButton(
                tooltip: 'Actions',
                icon: const Icon(Icons.more_horiz),
                onPressed: () async {
                  result = await showAppActionSheet<String>(
                    context,
                    title: 'Route actions',
                    actions: const [
                      SheetAction(
                        value: 'delete',
                        label: 'Delete',
                        icon: Icons.delete_outline,
                        destructive: true,
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(find.byTooltip('Actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(result, 'delete');
    },
  );
}

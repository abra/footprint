import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recording_service/recording_service.dart';

import '../packages/features/explore/test/fakes.dart';
import 'design_golden_test.dart' show FixtureTiles, tileFixture;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List tile;
  setUpAll(() async {
    tile = await tileFixture();
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
        final cubit = ExploreCubit(
          planner: FakePlanner(),
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
              child: child!,
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
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('Clear route'), findsNothing);
        await tester.tap(find.byTooltip('Change distance'));
        await tester.pumpAndSettle();
        expect(find.byType(BottomSheet), findsOneWidget);
        expect(find.byType(AlertDialog), findsNothing);
        await tester.tap(find.text('5 km'));
        await tester.pumpAndSettle();
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
        await tester.pumpAndSettle();
        expect(find.text('Getting current location...'), findsNothing);
        expect(find.text('Generate route'), findsOneWidget);
        service.currentLocationGate!.completeError(
          TimeoutException('Cancelled fix'),
        );
        await tester.pumpAndSettle();
        expect(cubit.state.visibleError, isNull);
        service.currentLocationGate = Completer<LocationDM>();
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await tester.pump();
        service.currentLocationGate!.complete(
          walkFix(loopPlan().points.first, 0),
        );
        await tester.pumpAndSettle();
        expect(cubit.state.plan, isNotNull);
        expect(find.byType(PlannedRouteLayer), findsOneWidget);
        expect(tester.takeException(), isNull);
        if (scale == 1) {
          await expectLater(
            find.byKey(const ValueKey('explore-golden')),
            matchesGoldenFile('goldens/walk_plan.png'),
          );
        }
        await tester.ensureVisible(find.byTooltip('Clear route'));
        final map = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        final camera = map.camera;
        await tester.tap(find.byTooltip('Clear route'));
        await tester.pumpAndSettle();
        expect(find.byType(PlannedRouteLayer), findsNothing);
        expect(find.text('Start walk'), findsNothing);
        expect(find.byTooltip('Clear route'), findsNothing);
        expect(find.text('Generate route'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.byType(AlertDialog), findsNothing);
        expect(map.camera.center, camera.center);
        expect(map.camera.zoom, camera.zoom);
        expect(cubit.state.distance, 5000);
        expect(cubit.state.newAreas, 0);
        expect(cubit.state.profile, walks.profile);
        expect(
          tester
              .widget<ExploredAreasLayer>(find.byType(ExploredAreasLayer))
              .cells,
          walks.cells,
        );
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.text('Generate route'));
        await tester.tap(find.text('Generate route'));
        await tester.pumpAndSettle();
        expect(find.byType(PlannedRouteLayer), findsOneWidget);
        expect(find.byTooltip('Clear route'), findsOneWidget);
        await tester.tap(find.text('Exploration'));
        await tester.pumpAndSettle();
        expect(find.text('12 areas explored'), findsOneWidget);
        if (scale == 1) {
          await expectLater(
            find.byKey(const ValueKey('explore-golden')),
            matchesGoldenFile('goldens/exploration.png'),
          );
        }
        await tester.tap(find.text('Plan a walk').last);
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Change distance'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.byType(TextFormField));
        await tester.enterText(find.byType(TextFormField), '99');
        await tester.ensureVisible(find.text('Set distance'));
        await tester.tap(find.text('Set distance'));
        await tester.pumpAndSettle();
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
        await tester.enterText(find.byType(TextFormField), '2,5');
        await tester.ensureVisible(find.text('Set distance'));
        await tester.tap(find.text('Set distance'));
        await tester.pumpAndSettle();
        expect(cubit.state.distance, 2500);
        expect(find.byType(BottomSheet), findsNothing);
        await cubit.generate();
        await cubit.start();
        await tester.pumpAndSettle();
        expect(backRequests, 1);
        expect(
          tester
              .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.close))
              .onPressed,
          isNull,
        );
        service.send(walkFix(loopPlan().points.first, 2));
        await cubit.refreshProfile();
        await tester.pumpAndSettle();
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

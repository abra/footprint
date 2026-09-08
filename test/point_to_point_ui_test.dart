import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:explore/src/loop_distance_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:latlong2/latlong.dart';
import 'package:recording_service/recording_service.dart';

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
    final viewport = scale == 1
        ? ''
        : size.width < size.height
        ? '_small_large_text'
        : '_landscape_large_text';
    testWidgets(
      'manual endpoints, cancellation, swapping and generation at $size / $scale',
      (tester) async {
        debugDisableShadows = false;
        final semantics = tester.ensureSemantics();
        try {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final location = FakeLocationService()
            ..lastLocation = walkFix(loopPlan().points.first, 0);
          final recording = RecordingService(
            locationService: location,
            routesRepository: FakeRoutesRepository(),
          );
          final planner = FakePlanner();
          final cubit = ExploreCubit(
            planner: planner,
            walks: FakeWalks(),
            recording: recording,
            now: () => walkEpoch,
          );
          // Finish UI transitions without aging the GPS fixture by two seconds
          // on every tap; freshness expiry is tested separately.
          Future<void> pumpUi() =>
              pumpMapUi(tester, duration: const Duration(milliseconds: 400));
          try {
            var backs = 0;
            await tester.pumpWidget(
              MaterialApp(theme: AppTheme.light, home: const SizedBox.shrink()),
            );
            await tester.runAsync(
              () => precacheImage(
                MemoryImage(tile),
                tester.element(find.byType(SizedBox)),
              ),
            );
            await cubit.initialize();
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: AppTheme.builder(context, child),
                ),
                home: BlocProvider(
                  create: (_) => cubit,
                  child: RepaintBoundary(
                    key: const ValueKey('point-to-point-golden'),
                    child: ExploreView(
                      config: MapTileConfig(
                        tileProviderFactory: () => FixtureTiles(tile),
                      ),
                      onBack: () => backs++,
                    ),
                  ),
                ),
              ),
            );
            await pumpUi();
            Future<void> tapText(String text) async {
              await tester.ensureVisible(find.text(text).last);
              await tester.tap(find.text(text).last);
              await pumpUi();
              expect(tester.takeException(), isNull);
            }

            Future<void> tapMap(double x) async {
              final bounds = tester.getRect(find.byType(FlutterMap));
              await tester.tapAt(
                Offset(
                  bounds.left + bounds.width * x,
                  bounds.top + bounds.height * 0.3,
                ),
              );
              await tester.pump(const Duration(milliseconds: 350));
              await pumpUi();
              expect(tester.takeException(), isNull);
            }

            Future<void> tapTool(String tooltip) async {
              await tester.ensureVisible(find.byTooltip(tooltip));
              await tester.tap(find.byTooltip(tooltip));
              await pumpUi();
              expect(tester.takeException(), isNull);
            }

            FTile endpointTile(String label) =>
                tester.widget<FTile>(find.widgetWithText(FTile, label));

            void expectEndpointSpacing() {
              final start = tester.getRect(find.widgetWithText(FTile, 'Start'));
              final destination = tester.getRect(
                find.widgetWithText(FTile, 'Destination'),
              );
              expect(destination.top - start.bottom, closeTo(8, 0.01));
            }

            Finder endpointBadge(String letter) => find.descendant(
              of: find.byType(FlutterMap),
              matching: find.byWidgetPredicate(
                (widget) =>
                    widget is RouteEndpointBadge && widget.letter == letter,
              ),
            );

            RouteEndpointMarker endpointMarker(String letter) => tester
                .widgetList<MarkerLayer>(find.byType(MarkerLayer))
                .expand((layer) => layer.markers)
                .whereType<RouteEndpointMarker>()
                .singleWhere((marker) => marker.letter == letter);

            final panel = find.byKey(const ValueKey('explore-panel'));
            final panelBounds = tester.getRect(panel);
            final generate = find.widgetWithText(AppButton, 'Generate route');
            final generateBounds = tester.getRect(generate);
            final modeBounds = tester.getRect(
              find.byType(AppSegmentedControl<RoutePlanMode>),
            );
            final mapBounds = tester.getRect(find.byType(FlutterMap));
            final locationMarker = find.descendant(
              of: find.byType(FlutterMap),
              matching: find.bySemanticsLabel('Current location'),
            );
            expect(
              tester.getCenter(locationMarker).dy,
              closeTo((mapBounds.top + panelBounds.top) / 2, 1),
            );
            var capturedMotion = false;
            for (final mode in ['A to B', 'Loop', 'A to B']) {
              await tester.tap(find.text(mode));
              await tester.pump();
              final crossFade = find.byType(AnimatedCrossFade);
              for (var frame = 0; frame < 3; frame++) {
                await tester.pump(const Duration(milliseconds: 60));
                expect(tester.getRect(panel), panelBounds);
                expect(tester.getRect(find.byType(FlutterMap)), mapBounds);
                if (frame == 0) {
                  final opacities = tester.widgetList<FadeTransition>(
                    find.descendant(
                      of: crossFade,
                      matching: find.byType(FadeTransition),
                    ),
                  );
                  expect(
                    opacities.where(
                      (fade) =>
                          fade.opacity.value > 0 && fade.opacity.value < 1,
                    ),
                    hasLength(1),
                  );
                }
                if (scale == 1 && frame == 1 && !capturedMotion) {
                  await expectLater(
                    find.byKey(const ValueKey('point-to-point-golden')),
                    matchesGoldenFile('goldens/planning_mode_transition.png'),
                  );
                  capturedMotion = true;
                }
              }
              await pumpUi();
              expect(tester.getRect(panel), panelBounds);
              expect(tester.getRect(find.byType(FlutterMap)), mapBounds);
              expect(
                tester.getRect(find.byType(AppSegmentedControl<RoutePlanMode>)),
                modeBounds,
              );
              if (scale == 1) {
                expect(tester.getRect(generate), generateBounds);
                expect(generate.hitTestable(), findsOneWidget);
              }
              final settingsBounds = tester.getRect(
                find.byKey(const ValueKey('route-endpoint-settings')),
              );
              if (mode == 'Loop') {
                expect(
                  tester.getRect(find.byType(LoopDistancePicker)),
                  settingsBounds,
                );
                expect(find.text('Start').hitTestable(), findsNothing);
                expect(find.text('Destination').hitTestable(), findsNothing);
                expect(
                  find.bySemanticsLabel(RegExp(r'^Start\b')),
                  findsNothing,
                );
                expect(
                  find.bySemanticsLabel(RegExp(r'^Destination\b')),
                  findsNothing,
                );
              }
              final detailsBounds = tester.getRect(
                find.byKey(const ValueKey('plan-details-scroll')),
              );
              final actionBounds = tester.getRect(generate);
              expect(panelBounds.intersect(actionBounds), actionBounds);
              expect(generate.hitTestable(), findsOneWidget);
              if (size.width > size.height) {
                expect(
                  actionBounds.left - detailsBounds.right,
                  closeTo(16, 0.01),
                );
              } else {
                expect(
                  actionBounds.top - detailsBounds.bottom,
                  closeTo(12, 0.01),
                );
              }
              if (scale == 1) {
                expect(
                  panelBounds.bottom - tester.getRect(generate).bottom,
                  closeTo(16, 0.01),
                );
                expect(panelBounds.top, closeTo(modeBounds.top - 16, 0.01));
              }
            }
            expect(cubit.state.mode, RoutePlanMode.pointToPoint);
            expectEndpointSpacing();
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('A').hitTestable(), findsOneWidget);
            expect(endpointMarker('A').point, loopPlan().points.first.latLng);
            await tapText('Destination');
            expect(find.byType(AppSheet), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(endpointTile('Destination').selected, isTrue);
            expectEndpointSpacing();
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('B'), findsNothing);
            expect(endpointMarker('A').point, loopPlan().points.first.latLng);
            await tapTool('Cancel point selection');
            expect(cubit.state.end, isNull);
            expect(
              find.byTooltip('Change distance').hitTestable(),
              findsNothing,
            );
            expect(
              tester
                  .widget<AppButton>(
                    find.widgetWithText(AppButton, 'Generate route'),
                  )
                  .onPressed,
              isNull,
            );
            await tapText('Start');
            expect(find.byType(AppSheet), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(endpointTile('Start').selected, isTrue);
            expectEndpointSpacing();
            final map = tester
                .widget<FlutterMap>(find.byType(FlutterMap))
                .mapController!;
            map.move(const LatLng(0.001, 0.001), map.camera.zoom);
            await pumpUi();
            expect(cubit.state.start, isNull);
            final bounds = tester.getRect(find.byType(FlutterMap));
            await tester.dragFrom(
              Offset(bounds.center.dx, bounds.top + bounds.height * 0.3),
              const Offset(32, 0),
            );
            await pumpUi();
            expect(cubit.state.start, isNull);
            expect(endpointTile('Start').selected, isTrue);
            await tapTool('Cancel point selection');
            expect(cubit.state.start, isNull);
            expect(backs, 0);
            await tapTool('Center map');

            await tapText('Start');
            await expectLater(
              find.byKey(const ValueKey('point-to-point-golden')),
              matchesGoldenFile('goldens/route_point_selection$viewport.png'),
            );
            await tapMap(0.25);
            final start = cubit.state.start;
            expect(start, isNotNull);
            expect(endpointTile('Start').selected, isFalse);
            expect(endpointBadge('A'), findsOneWidget);
            await tapText('Destination');
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('A').hitTestable(), findsOneWidget);
            expect(endpointMarker('A').point, start!.latLng);
            await expectLater(
              find.byKey(const ValueKey('point-to-point-golden')),
              matchesGoldenFile(
                'goldens/route_destination_selection$viewport.png',
              ),
            );
            await tapMap(0.75);
            final end = cubit.state.end;
            expect(end, isNotNull);
            expect(start.distanceTo(end!), greaterThan(100));
            expect(endpointTile('Destination').selected, isFalse);
            expect(endpointBadge('B'), findsOneWidget);
            await tapMap(0.5);
            expect(cubit.state.start, start);
            expect(cubit.state.end, end);
            await tapText('Start');
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('B'), findsOneWidget);
            expect(endpointMarker('B').point, end.latLng);
            await tapText('Start');
            expect(endpointTile('Start').selected, isFalse);
            expect(cubit.state.start, start);
            expect(cubit.state.end, end);
            await tester.ensureVisible(
              find.byTooltip('Swap start and destination'),
            );
            await tester.tap(find.byTooltip('Swap start and destination'));
            await pumpUi();
            expect(cubit.state.start, end);
            expect(cubit.state.end, start);

            location.currentLocationError = TimeoutException('No GPS');
            await tapText('Generate route');
            expect(planner.calls, 1);
            expect(cubit.state.plan!.mode, RoutePlanMode.pointToPoint);
            expect(cubit.state.plan!.points, [end, start]);
            expect(find.byType(PlannedRouteLayer), findsOneWidget);
            expect(find.byTooltip('Destination'), findsWidgets);
            expect(find.byTooltip('Return to start'), findsNothing);
            expect(location.currentLocationRequests, 0);
            expect(recording.state.isRecording, isFalse);
            if (scale == 1) {
              await expectLater(
                find.byKey(const ValueKey('point-to-point-golden')),
                matchesGoldenFile('goldens/point_to_point_plan.png'),
              );
            }
            final plan = cubit.state.plan;
            final startWalk = find.widgetWithText(AppButton, 'Start walk');
            final startBounds = tester.getRect(startWalk);
            expect(tester.getRect(panel).intersect(startBounds), startBounds);
            expect(startWalk.hitTestable(), findsOneWidget);
            expect(find.byTooltip('Generate another'), findsNothing);
            expect(tester.widget<AppButton>(startWalk).onPressed, isNull);
            expect(find.textContaining('Move within 100 m'), findsOneWidget);
            final readiness = tester.getRect(
              find.textContaining('Move within 100 m'),
            );
            expect(tester.getRect(panel).intersect(readiness), readiness);
            await tester.tap(startWalk);
            await pumpUi();
            expect(recording.state.isRecording, isFalse);
            expect(cubit.state.visibleError, isNull);
            expect(cubit.state.plan, same(plan));
            expect(cubit.state.start, end);
            expect(cubit.state.end, start);
            expect(find.byType(AppSheet), findsNothing);
            await tapTool('Edit route');
            final editorHeight = tester.getSize(panel).height;
            await tapText('Destination');
            expect(
              tester.getSize(panel).height,
              lessThanOrEqualTo(editorHeight),
            );
            expect(find.byType(PlannedRouteLayer), findsOneWidget);
            expect(
              tester
                  .widget<AppButton>(
                    find.widgetWithText(AppButton, 'Show route'),
                  )
                  .onPressed,
              isNull,
            );
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointMarker('A').point, end.latLng);
            map.move(const LatLng(0.001, 0.001), map.camera.zoom);
            await pumpUi();
            expect(cubit.state.plan, same(plan));
            await tapTool('Cancel point selection');
            expect(cubit.state.plan, same(plan));
            expect(tester.getSize(panel).height, editorHeight);
            expect(find.byType(PlannedRouteLayer), findsOneWidget);
            expect(endpointMarker('A').point, plan!.points.first.latLng);
            await tapText('Destination');
            await tapMap(0.5);
            expect(cubit.state.plan, isNull);
            expect(cubit.state.start, end);
            expect(cubit.state.end, isNot(start));
            cubit.selectEnd(start);
            await pumpUi();
            await tapText('Generate route');
            final clearRoute = find.byTooltip('Clear route').hitTestable();
            await tester.ensureVisible(clearRoute);
            await tester.tap(clearRoute);
            await pumpUi();
            expect(cubit.state.plan, isNull);
            expect(cubit.state.start, end);
            expect(cubit.state.end, start);
            await tapText('Destination');
            expect(endpointBadge('A'), findsOneWidget);
            await tapTool('Cancel point selection');
            expect(backs, 0);
            expect(cubit.state.end, start);
            await tapText('Start');
            await tapTool('Use current location for start');
            expect(cubit.state.start, isNull);
            expect(endpointTile('Start').selected, isFalse);
            expect(endpointMarker('A').point, loopPlan().points.first.latLng);
            await tapTool('Center map');
            expect(endpointBadge('A'), findsOneWidget);
            await tapText('Destination');
            await tapText('Loop');
            expect(cubit.state.mode, RoutePlanMode.loop);
            expect(find.byTooltip('Change distance'), findsOneWidget);
            expect(cubit.state.end, start);
            await tapText('A to B');
            expect(endpointTile('Destination').selected, isFalse);
            await tapText('Destination');
            await tapText('Exploration');
            expect(cubit.state.showProgress, isTrue);
            await tapText('Plan a walk');
            expect(endpointTile('Destination').selected, isFalse);
            await tapText('Destination');
            await tester.binding.handlePopRoute();
            await pumpUi();
            expect(endpointTile('Destination').selected, isFalse);
            expect(cubit.state.end, start);
            expect(backs, 0);
            await tapText('Destination');
            await recording.start();
            await pumpUi();
            expect(endpointTile('Destination').selected, isFalse);
            expect(endpointTile('Destination').enabled, isFalse);
            await tapMap(0.5);
            expect(cubit.state.end, start);
          } finally {
            await tester.pumpWidget(const SizedBox.shrink());
            await tester.pumpAndSettle();
            planner.dispose();
            await tester.runAsync(() async {
              await recording.dispose();
              await location.dispose();
            });
          }
        } finally {
          semantics.dispose();
          debugDisableShadows = true;
        }
      },
    );
  }
}

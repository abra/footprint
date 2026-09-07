import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:explore/explore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
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
    final viewport = scale == 1
        ? ''
        : size.width < size.height
        ? '_small_large_text'
        : '_landscape_large_text';
    testWidgets(
      'manual endpoints, cancellation, swapping and generation at $size / $scale',
      (tester) async {
        debugDisableShadows = false;
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
                  child: child!,
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
            await tester.pumpAndSettle();
            Future<void> tapText(String text) async {
              await tester.ensureVisible(find.text(text).last);
              await tester.tap(find.text(text).last);
              await tester.pumpAndSettle();
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
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            Future<void> tapTool(String tooltip) async {
              await tester.ensureVisible(find.byTooltip(tooltip));
              await tester.tap(find.byTooltip(tooltip));
              await tester.pumpAndSettle();
              expect(tester.takeException(), isNull);
            }

            ListTile endpointTile(String label) =>
                tester.widget<ListTile>(find.widgetWithText(ListTile, label));

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

            await tapText('A to B');
            expect(cubit.state.mode, RoutePlanMode.pointToPoint);
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('A').hitTestable(), findsOneWidget);
            expect(endpointMarker('A').point, loopPlan().points.first.latLng);
            await tapText('Destination');
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(endpointTile('Destination').selected, isTrue);
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointBadge('B'), findsNothing);
            expect(endpointMarker('A').point, loopPlan().points.first.latLng);
            await tapTool('Cancel point selection');
            expect(cubit.state.end, isNull);
            expect(find.byTooltip('Change distance'), findsNothing);
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Generate route'),
                  )
                  .onPressed,
              isNull,
            );
            await tapText('Start');
            expect(find.byType(BottomSheet), findsNothing);
            expect(find.byType(AlertDialog), findsNothing);
            expect(endpointTile('Start').selected, isTrue);
            final map = tester
                .widget<FlutterMap>(find.byType(FlutterMap))
                .mapController!;
            map.move(const LatLng(0.001, 0.001), map.camera.zoom);
            await tester.pumpAndSettle();
            expect(cubit.state.start, isNull);
            final bounds = tester.getRect(find.byType(FlutterMap));
            await tester.dragFrom(
              Offset(bounds.center.dx, bounds.top + bounds.height * 0.3),
              const Offset(32, 0),
            );
            await tester.pumpAndSettle();
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
            await tester.pumpAndSettle();
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
            await tapText('Destination');
            expect(find.byType(PlannedRouteLayer), findsOneWidget);
            expect(
              tester
                  .widget<FilledButton>(
                    find.widgetWithText(FilledButton, 'Start walk'),
                  )
                  .onPressed,
              isNull,
            );
            expect(endpointBadge('A'), findsOneWidget);
            expect(endpointMarker('A').point, end.latLng);
            map.move(const LatLng(0.001, 0.001), map.camera.zoom);
            await tester.pumpAndSettle();
            expect(cubit.state.plan, same(plan));
            await tapTool('Cancel point selection');
            expect(cubit.state.plan, same(plan));
            expect(find.byType(PlannedRouteLayer), findsOneWidget);
            expect(endpointMarker('A').point, plan!.points.first.latLng);
            await tapText('Destination');
            await tapMap(0.5);
            expect(cubit.state.plan, isNull);
            expect(cubit.state.start, end);
            expect(cubit.state.end, isNot(start));
            cubit.selectEnd(start);
            await tester.pumpAndSettle();
            await tapText('Generate route');
            await tester.ensureVisible(find.byTooltip('Clear route'));
            await tester.tap(find.byTooltip('Clear route'));
            await tester.pumpAndSettle();
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
            await tester.pumpAndSettle();
            expect(endpointTile('Destination').selected, isFalse);
            expect(cubit.state.end, start);
            expect(backs, 0);
            await tapText('Destination');
            await recording.start();
            await tester.pumpAndSettle();
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
          debugDisableShadows = true;
        }
      },
    );
  }
}

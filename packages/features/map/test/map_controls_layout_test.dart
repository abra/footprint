import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/map.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:map/src/recording_stats_panel.dart';
import 'package:recording_service/recording_service.dart';

import '../../../component_library/test/load_fonts.dart';
import 'fakes.dart';
import '../../../component_library/test/pump_map_ui.dart';

void main() {
  setUpAll(loadAppFonts);

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 2.0),
  ]) {
    for (final reducedMotion in [false, true]) {
      testWidgets('controls stay anchored through recording at $size / $scale, '
          'reduced motion: $reducedMotion', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final locationService = FakeLocationService()
          ..lastLocation = location(1);
        final recording = RecordingService(
          locationService: locationService,
          routesRepository: FakeRoutesRepository(),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: reducedMotion,
              ),
              child: AppTheme.builder(context, child),
            ),
            home: MapScreen(
              photosRepository: FakeRoutePhotosRepository(),
              recordingService: recording,
              geocodingManager: FakeGeocodingManager(),
              onPageChangeRequested: () {},
              onExploreRequested: () {},
            ),
          ),
        );
        await pumpMapUi(tester);
        final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
        final bounds = {
          for (final label in [
            'Follow direction of travel',
            'Zoom in',
            'Zoom out',
          ])
            label: tester.getRect(find.byTooltip(label)),
        };
        expect(find.byTooltip('Add route photo'), findsNothing);

        void expectAnchored() {
          final stats = find.byType(RecordingStatsPanel);
          final attribution = find.byTooltip('Attributions');
          expect(attribution.hitTestable(), findsOneWidget);
          final attributionBounds = tester.getRect(attribution);
          for (final entry in bounds.entries) {
            final button = find.byTooltip(entry.key);
            expect(button.hitTestable(), findsOneWidget);
            final current = tester.getRect(button);
            expect(current, entry.value, reason: '${entry.key} moved');
            expect(current.size, const Size(48, 48));
            expect(current.overlaps(attributionBounds), isFalse);
            if (stats.evaluate().isNotEmpty) {
              expect(current.overlaps(tester.getRect(stats)), isFalse);
            }
          }
          final photo = find.byTooltip('Add route photo');
          if (photo.evaluate().isNotEmpty) {
            expect(photo.hitTestable(), findsOneWidget);
            final photoBounds = tester.getRect(photo);
            expect(photoBounds.size, const Size(48, 48));
            for (final control in bounds.values) {
              expect(photoBounds.overlaps(control), isFalse);
            }
            expect(photoBounds.overlaps(attributionBounds), isFalse);
            if (stats.evaluate().isNotEmpty) {
              expect(photoBounds.overlaps(tester.getRect(stats)), isFalse);
            }
          }
          expect(tester.takeException(), isNull);
        }

        Future<void> checkTransition() async {
          await tester.pump();
          for (var frame = 0; frame < 15; frame++) {
            await tester.pump(const Duration(milliseconds: 20));
            expectAnchored();
          }
        }

        await tester.tap(find.widgetWithText(AppButton, 'Record route'));
        await checkTransition();
        expect(cubit.state.isRecording, isTrue);
        expect(find.byTooltip('Add route photo'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('recording-stats-panel')));
        await checkTransition();
        expect(cubit.state.statsExpanded, isTrue);
        cubit.emit(
          cubit.state.copyWith(
            metrics: RouteMetrics(
              currentSpeed: 120 / 3.6,
              distance: 119000,
              duration: const Duration(hours: 125),
            ),
            photoError: 'Photo could not be saved. Retry the pending photo.',
            tileError: true,
          ),
        );
        await checkTransition();
        await tester.ensureVisible(
          find.descendant(
            of: find.byType(RecordingStatsPanel),
            matching: find.text('DURATION'),
          ),
        );
        await checkTransition();
        cubit.toggleStats();
        await checkTransition();
        await tester.tap(find.widgetWithText(AppButton, 'Stop recording'));
        await checkTransition();
        expect(cubit.state.isRecording, isFalse);
        expect(find.byType(RecordingStatsPanel), findsNothing);
        expect(find.byTooltip('Add route photo'), findsNothing);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(() async {
          await recording.dispose();
          await locationService.dispose();
        });
      });
    }
  }
}

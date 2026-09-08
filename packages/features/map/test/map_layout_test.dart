import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/map.dart';
import 'package:map/src/center_location_icon.dart';
import 'package:map/src/map_app_bar.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

void main() {
  for (final size in [
    const Size(390, 844),
    const Size(320, 568),
    const Size(844, 390),
  ]) {
    testWidgets('map controls and tile retry fit $size at 2x text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var exploreRequests = 0;
      var historyRequests = 0;
      final service = FakeLocationService()..lastLocation = location(1);
      final recording = RecordingService(
        locationService: service,
        routesRepository: FakeRoutesRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: AppTheme.builder(context, child),
          ),
          home: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () => historyRequests++,
            onExploreRequested: () => exploreRequests++,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
      final controller = tester
          .widget<FlutterMap>(find.byType(FlutterMap))
          .mapController!;
      final header = find.byType(MapAppBar);
      final headerViewport = find.ancestor(
        of: header,
        matching: find.byType(SingleChildScrollView),
      );
      final viewportBounds = tester.getRect(headerViewport);
      final headerBounds = tester.getRect(header);
      expect(headerBounds.left - viewportBounds.left, 16);
      expect(headerBounds.top - viewportBounds.top, 16);
      expect(viewportBounds.right - headerBounds.right, 16);
      expect(
        tester.widget<SingleChildScrollView>(headerViewport).clipBehavior,
        Clip.hardEdge,
      );
      final explore = find.widgetWithText(AppButton, 'Explore');
      expect(explore.hitTestable(), findsOneWidget);
      expect(tester.getRect(explore).bottom, lessThan(size.height / 2));
      expect(tester.widget<AppButton>(explore).compact, isTrue);
      await tester.tap(explore);
      await tester.tap(find.byTooltip('Routes'));
      expect(exploreRequests, 1);
      expect(historyRequests, 1);
      final originalZoom = controller.camera.zoom;
      final centerBounds = tester.getRect(
        find.byKey(const ValueKey('map-follow-button')),
      );
      final iconBounds = tester.getRect(find.byType(CenterLocationIcon));
      expect(iconBounds.size, const Size(28, 28));
      expect(iconBounds.center, centerBounds.center);
      final zoomInBounds = tester.getRect(find.byTooltip('Zoom in'));
      final zoomOutBounds = tester.getRect(find.byTooltip('Zoom out'));
      if (zoomInBounds.top == zoomOutBounds.top) {
        expect(centerBounds.center.dy, zoomInBounds.center.dy);
        expect(find.byType(VerticalDivider), findsOneWidget);
        expect(zoomOutBounds.left - zoomInBounds.right, 1);
      } else {
        expect(centerBounds.center.dx, zoomInBounds.center.dx);
        expect(centerBounds.left, zoomInBounds.left);
        expect(centerBounds.right, zoomInBounds.right);
        expect(find.byType(Divider), findsOneWidget);
        expect(zoomOutBounds.top - zoomInBounds.bottom, 1);
      }
      for (final (tooltip, delta) in [('Zoom in', 1), ('Zoom out', 0)]) {
        final button = find.byWidgetPredicate(
          (widget) => widget is AppIconButton && widget.tooltip == tooltip,
        );
        expect(tester.widget<AppIconButton>(button).square, isTrue);
        expect(tester.getSize(button), const Size(48, 48));
        final surface = tester.widget<Material>(
          find
              .descendant(
                of: find.ancestor(
                  of: button,
                  matching: find.byType(MapSurface),
                ),
                matching: find.byType(Material),
              )
              .first,
        );
        expect(surface.shape, AppTheme.controlShape);
        expect(surface.clipBehavior, Clip.antiAlias);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(controller.camera.zoom, closeTo(originalZoom + delta, 0.001));
      }
      expect(find.byType(PolylineLayer), findsNothing);
      cubit.tilesFailed();
      await tester.pumpAndSettle();
      expect(find.text('Map tiles could not be loaded.'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Retry'));
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(cubit.state.tileGeneration, 1);
      final record = tester.getRect(
        find.widgetWithText(AppButton, 'Record route'),
      );
      final center = tester.getRect(
        find.byKey(const ValueKey('map-follow-button')),
      );
      expect(record.overlaps(center), isFalse);
      expect(record.left, greaterThanOrEqualTo(0));
      expect(record.right, lessThanOrEqualTo(size.width));
      expect(record.bottom, lessThanOrEqualTo(size.height));
      expect(
        record.overlaps(tester.getRect(find.byTooltip('Attributions'))),
        isFalse,
      );
      await cubit.startRecording();
      await tester.pumpAndSettle();
      expect(find.text('Explore'), findsNothing);
      expect(
        find.widgetWithText(AppButton, 'Stop recording').hitTestable(),
        findsOneWidget,
      );
      cubit.emit(
        cubit.state.copyWith(
          photoError:
              'Photo could not be saved. Retry or discard the pending photo.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add route photo').hitTestable(), findsOneWidget);
      for (final tooltip in [
        'Follow direction of travel',
        'Add route photo',
        'Routes',
      ]) {
        final button = find.byWidgetPredicate(
          (widget) => widget is AppIconButton && widget.tooltip == tooltip,
        );
        expect(tester.getSize(button), const Size(48, 48));
        expect(
          find.descendant(of: button, matching: find.byType(InkWell)),
          findsNothing,
        );
      }
      expect(find.byTooltip('Attributions').hitTestable(), findsOneWidget);
      for (final surface in tester.widgetList<Material>(
        find.descendant(
          of: find.byType(MapSurface),
          matching: find.byType(Material),
        ),
      )) {
        expect(surface.shape, AppTheme.controlShape);
        expect(surface.clipBehavior, Clip.antiAlias);
      }
      await tester.tap(find.byTooltip('Attributions'));
      await tester.pumpAndSettle();
      expect(find.text('Map data'), findsOneWidget);
      await tester.tap(find.text('Close attribution'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(cubit.isClosed, isTrue);
      await tester.runAsync(() async {
        await recording.dispose();
        await service.dispose();
      });
    });
  }
}

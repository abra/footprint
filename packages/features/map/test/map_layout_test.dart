import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/map.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import 'fakes.dart';

void main() {
  for (final size in [const Size(320, 568), const Size(844, 390)]) {
    testWidgets('map controls and tile retry fit $size at 2x text', (
      tester,
    ) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final service = FakeLocationService()..lastLocation = location(1);
      final recording = RecordingService(
        locationService: service,
        routesRepository: FakeRoutesRepository(),
      );
      await tester.pumpWidget(
        MaterialApp(
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: const TextScaler.linear(2),
              disableAnimations: true,
            ),
            child: child!,
          ),
          home: MapScreen(
            photosRepository: FakeRoutePhotosRepository(),
            recordingService: recording,
            geocodingManager: FakeGeocodingManager(),
            onPageChangeRequested: () {},
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      final cubit = tester.element(find.byType(MapView)).read<MapCubit>();
      expect(find.byType(PolylineLayer), findsNothing);
      cubit.tilesFailed();
      await tester.pumpAndSettle();
      expect(find.text('Map tiles could not be loaded.'), findsOneWidget);
      await tester.tap(find.byTooltip('Retry'));
      await tester.pump();
      expect(cubit.state.tileGeneration, 1);
      final record = tester.getRect(
        find.widgetWithText(FilledButton, 'Record route'),
      );
      final center = tester.getRect(find.byTooltip('Center on location'));
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
      cubit.emit(
        cubit.state.copyWith(
          photoError:
              'Photo could not be saved. Retry or discard the pending photo.',
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Add route photo').hitTestable(), findsOneWidget);
      expect(find.byTooltip('Attributions').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Attributions'));
      await tester.pumpAndSettle();
      expect(find.text('Map data'), findsOneWidget);
      await tester.tap(find.byTooltip('Close attribution'));
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

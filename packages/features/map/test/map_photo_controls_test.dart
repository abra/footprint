import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_photo_controls.dart';
import 'package:map/src/map_state.dart';
import 'package:recording_service/recording_service.dart';

import '../../../component_library/test/load_fonts.dart';
import 'fakes.dart';

void main() {
  setUpAll(loadAppFonts);

  testWidgets(
    'photo button preserves its camera icon while busy and after errors',
    (tester) async {
      final cubit = MapCubit(
        recordingService: _Recording(),
        photosRepository: FakeRoutePhotosRepository(),
        geocodingManager: FakeGeocodingManager(),
      );
      final recording = MapState(
        isRecording: true,
        routeId: 1,
        location: location(1),
      );
      cubit.emit(recording);
      try {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: AppTheme.builder,
            home: Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [MapPhotoButton(), MapPhotoError()],
                  ),
                ),
              ),
            ),
          ),
        );
        final button = find.descendant(
          of: find.byType(MapPhotoButton),
          matching: find.byType(AppIconButton),
        );
        final size = tester.getSize(button);
        for (final state in [
          recording,
          recording.copyWith(photoBusy: true),
          recording,
          recording.copyWith(photoBusy: true),
          recording.copyWith(photoError: 'Photo could not be saved.'),
          recording.copyWith(photoBusy: true),
          recording,
        ]) {
          cubit.emit(state);
          await tester.pump();
          await tester.pump();
          expect(find.byType(CircularProgressIndicator), findsNothing);
          final camera = find.descendant(
            of: button,
            matching: find.byIcon(FLucideIcons.camera),
          );
          expect(camera, findsOneWidget);
          expect(tester.widget<Icon>(camera).color, AppTheme.route);
          expect(tester.getSize(button), size);
          expect(
            tester.widget<AppIconButton>(button).onPressed != null,
            !state.photoBusy,
          );
          if (state.photoBusy) {
            await tester.tap(button);
            await tester.pump(const Duration(milliseconds: 200));
            expect(find.byType(AppSheet), findsNothing);
          }
          expect(
            find.text('Photo could not be saved.'),
            state.photoError == null ? findsNothing : findsOneWidget,
          );
        }
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.byType(AppSheet), findsOneWidget);
        expect(find.text('Take photo'), findsOneWidget);
        expect(find.text('Choose photo'), findsOneWidget);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(find.byType(AppSheet), findsNothing);
        expect(cubit.state.photoBusy, isFalse);
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        await tester.runAsync(cubit.close);
      }
    },
  );
}

class _Recording extends Fake implements RecordingService {}

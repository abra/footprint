import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/map.dart';
import 'package:map/src/last_route_notice.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import '../../../component_library/test/load_fonts.dart';
import '../../../component_library/test/pump_map_ui.dart';
import 'fakes.dart';
import 'map_recording_ui_test.dart' show StreamRecording;

class _Tiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(TileProvider.transparentImage);
}

void main() {
  setUpAll(loadAppFonts);

  for (final (size, scale) in [
    (const Size(390, 844), 1.0),
    (const Size(320, 568), 2.0),
    (const Size(844, 390), 2.0),
  ]) {
    testWidgets(
      'completed trace is muted and dismissible without moving controls at $size',
      (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final recording = StreamRecording()
          ..state = RecordingState(
            phase: RecordingPhase.recording,
            routeId: 1,
            location: location(2),
            points: [location(1), location(2)],
          );
        final cubit = MapCubit(
          recordingService: recording,
          photosRepository: FakeRoutePhotosRepository(),
          geocodingManager: FakeGeocodingManager(),
        );
        await cubit.initialize();
        addTearDown(() async {
          await cubit.close();
          await recording.controller.close();
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                textScaler: TextScaler.linear(scale),
                disableAnimations: true,
              ),
              child: AppTheme.builder(context, child),
            ),
            home: BlocProvider.value(
              value: cubit,
              child: MapView(
                config: MapConfig(
                  urlTemplate: 'https://fixture.example/{z}/{x}/{y}.png',
                  tileProviderFactory: _Tiles.new,
                ),
                onRoutesRequested: () {},
                onExploreRequested: () {},
              ),
            ),
          ),
        );
        await pumpMapUi(tester);
        final line = find.byKey(const ValueKey('route-history-layer'));
        Polyline trace() => tester.widget<PolylineLayer>(line).polylines.single;
        expect(trace().color, AppTheme.route);
        expect(find.byType(LastRouteNotice), findsNothing);
        final controls = {
          for (final label in [
            'Follow direction of travel',
            'Zoom in',
            'Zoom out',
          ])
            label: tester.getRect(find.byTooltip(label)),
        };
        recording.send(
          recording.state.copyWith(
            phase: RecordingPhase.idle,
            clearRoute: true,
          ),
        );
        await pumpMapUi(tester);
        expect(trace().color, AppTheme.route.withValues(alpha: 0.25));
        expect(trace().strokeWidth, 4);
        expect(
          find.byKey(const ValueKey('route-history-shadow')),
          findsNothing,
        );
        final geometry = trace().points;
        for (final (label, color) in [
          ('Route start', AppTheme.coral),
          ('Route end', AppTheme.success),
        ]) {
          final marker = find.descendant(
            of: find.byTooltip(label),
            matching: find.byType(Icon),
          );
          expect(
            tester.widget<Icon>(marker).color,
            color.withValues(alpha: 0.55),
          );
        }
        final hide = find.byTooltip('Hide last route');
        expect(hide.hitTestable(), findsOneWidget);
        expect(find.text('Last route').hitTestable(), findsOneWidget);
        expect(find.text('Record route').hitTestable(), findsOneWidget);
        final notice = tester.getRect(find.byType(LastRouteNotice));
        expect(
          notice.overlaps(
            tester.getRect(find.widgetWithText(AppButton, 'Record route')),
          ),
          isFalse,
        );
        for (final entry in controls.entries) {
          final current = tester.getRect(find.byTooltip(entry.key));
          expect(current, entry.value);
          expect(current.overlaps(notice), isFalse);
        }
        recording.send(recording.state.copyWith(location: location(3)));
        await pumpMapUi(tester);
        expect(trace().points, same(geometry));
        await tester.tap(hide);
        await pumpMapUi(tester);
        expect(find.byType(LastRouteNotice), findsNothing);
        expect(line, findsNothing);
        expect(find.byTooltip('Route start'), findsNothing);
        expect(find.byTooltip('Route end'), findsNothing);
        expect(find.byType(CurrentLocationLayer), findsOneWidget);
        recording.send(recording.state.copyWith(location: location(4)));
        await pumpMapUi(tester);
        expect(line, findsNothing);
        recording.send(
          RecordingState(
            phase: RecordingPhase.recording,
            routeId: 2,
            points: [location(3), location(4)],
            location: location(4),
          ),
        );
        await pumpMapUi(tester);
        expect(trace().color, AppTheme.route);
        expect(trace().strokeWidth, 7);
        expect(trace().points, isNot(geometry));
        expect(find.byType(LastRouteNotice), findsNothing);
        expect(find.byTooltip('Route end'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.runAsync(() async {
          await cubit.close();
          await recording.controller.close();
        });
        await tester.pumpAndSettle();
      },
    );
  }
}

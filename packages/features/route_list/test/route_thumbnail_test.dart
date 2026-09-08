import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_list/src/route_thumbnail.dart';
import 'package:route_list/src/route_thumbnail_cubit.dart';
import 'package:route_snapshots/route_snapshots.dart';

import '../../../component_library/test/load_fonts.dart';
import '../../../component_library/test/route_snapshot_scene_test.dart'
    show snapshotRoute;
import '../../../route_snapshots/test/fakes.dart';

class _Renderer implements SnapshotRenderer {
  Completer<Uint8List> next = Completer<Uint8List>();
  SnapshotCancellation? cancellation;
  int calls = 0;
  @override
  Future<Uint8List> render(
    RouteSnapshotScene scene,
    SnapshotCancellation cancellation,
  ) {
    calls++;
    this.cancellation = cancellation;
    return next.future;
  }

  @override
  Future<bool> isValid(Uint8List bytes) async => true;
}

void main() {
  late Uint8List png;
  setUpAll(() async {
    await loadAppFonts();
    final recorder = ui.PictureRecorder();
    Canvas(recorder).drawColor(AppTheme.surface, BlendMode.src);
    final picture = recorder.endRecording();
    final image = await picture.toImage(720, 400);
    png = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });

  testWidgets(
    'uses a static image, fits without cropping, retries and opens route',
    (tester) async {
      final renderer = _Renderer();
      final snapshots = RouteSnapshotRepository(
        config: const MapTileConfig(),
        store: MemorySnapshotStore(),
        renderer: renderer,
      );
      addTearDown(snapshots.dispose);
      var opened = false;
      await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
      await tester.runAsync(
        () => precacheImage(
          MemoryImage(png),
          tester.element(find.byType(MaterialApp)),
        ),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: AppTheme.builder,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: RouteThumbnail(
                  route: snapshotRoute(),
                  snapshots: snapshots,
                  config: const MapTileConfig(),
                  onTap: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      final preview = find.byType(RouteThumbnail);
      final bounds = tester.getRect(preview);
      renderer.next.completeError(StateError('Offline'));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry route map'), findsOneWidget);
      renderer.next = Completer<Uint8List>();
      await tester.tap(find.byTooltip('Retry route map'));
      await tester.pumpAndSettle();
      renderer.next.complete(png);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Retry route map'), findsNothing);
      final image = tester.widget<Image>(
        find.descendant(of: preview, matching: find.byType(Image)),
      );
      expect(image.fit, BoxFit.contain);
      expect(
        tester
            .widget<RawImage>(
              find.descendant(of: preview, matching: find.byType(RawImage)),
            )
            .image,
        isNotNull,
      );
      expect(find.text('\u00a9 OpenStreetMap contributors'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
      expect(tester.getRect(preview), bounds);
      await tester.tapAt(bounds.center);
      expect(opened, isTrue);
      expect(renderer.calls, 2);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'closing a thumbnail cancels its request and ignores late completion',
    (tester) async {
      final renderer = _Renderer();
      final store = MemorySnapshotStore();
      final snapshots = RouteSnapshotRepository(
        config: const MapTileConfig(),
        store: store,
        renderer: renderer,
      );
      addTearDown(snapshots.dispose);
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox(
            width: 320,
            child: RouteThumbnail(
              route: snapshotRoute(),
              snapshots: snapshots,
              config: const MapTileConfig(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(
        find.byType(BlocBuilder<RouteThumbnailCubit, RouteThumbnailState>),
      );
      final cubit = context.read<RouteThumbnailCubit>();
      await tester.pumpWidget(const SizedBox.shrink());
      expect(renderer.cancellation!.isCancelled, isTrue);
      renderer.next.complete(png);
      await tester.pumpAndSettle();
      expect(cubit.isClosed, isTrue);
      expect(store.images, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}

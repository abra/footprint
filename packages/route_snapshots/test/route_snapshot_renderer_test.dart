import 'dart:async';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_snapshots/route_snapshots.dart';

import '../../component_library/test/load_fonts.dart';
import '../../component_library/test/route_snapshot_scene_test.dart'
    show snapshotRoute;

class _Tiles extends TileProvider {
  _Tiles(this.source);
  final ImageProvider source;
  bool disposed = false;
  final coordinates = <TileCoordinates>[];
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) {
    this.coordinates.add(coordinates);
    return source;
  }

  @override
  void dispose() {
    disposed = true;
  }
}

class _PendingImage extends ImageProvider<_PendingImage> {
  final completion = Completer<ImageInfo>();
  @override
  Future<_PendingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
  @override
  ImageStreamCompleter loadImage(
    _PendingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(completion.future);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Uint8List tile;
  setUpAll(() async {
    await loadAppFonts();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(const Color(0xFFE0EEE7), BlendMode.src);
    canvas.drawRect(
      const Rect.fromLTWH(40, 0, 20, 256),
      Paint()..color = const Color(0xFFFFFFFF),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(256, 256);
    tile = (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
    image.dispose();
    picture.dispose();
  });

  test(
    'renders tiles, route and both anchored glyphs into a bounded PNG',
    () async {
      final tiles = _Tiles(MemoryImage(tile));
      final renderer = RouteSnapshotRenderer(
        config: MapTileConfig(tileProviderFactory: () => tiles),
      );
      final scene = RouteSnapshotScene(snapshotRoute());
      final png = await renderer.render(scene, SnapshotCancellation());
      expect(await renderer.isValid(png), isTrue);
      expect(tiles.disposed, isTrue);
      expect(tiles.headers['User-Agent'], contains('io.github.abra.footprint'));
      expect(tiles.coordinates.length, inInclusiveRange(1, 24));
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      try {
        expect(image.width, 720);
        expect(image.height, 400);
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var mapPixels = 0;
        var routePixels = 0;
        var startPixels = 0;
        var endPixels = 0;
        for (var y = 0; y < image.height; y++) {
          for (var x = 0; x < image.width; x++) {
            final i = (y * image.width + x) * 4;
            final r = pixels.getUint8(i);
            final g = pixels.getUint8(i + 1);
            final b = pixels.getUint8(i + 2);
            if (r == 224 && g == 238 && b == 231) mapPixels++;
            final argb = 0xff000000 | (r << 16) | (g << 8) | b;
            if (argb == AppTheme.route.toARGB32()) routePixels++;
            if (argb == AppTheme.coral.toARGB32()) {
              startPixels++;
              expect(
                (Offset(x.toDouble(), y.toDouble()) - scene.projected.first)
                    .distance,
                lessThan(70),
              );
            }
            if (argb == AppTheme.success.toARGB32()) {
              endPixels++;
              expect(
                (Offset(x.toDouble(), y.toDouble()) - scene.projected.last)
                    .distance,
                lessThan(70),
              );
            }
          }
        }
        expect(mapPixels, greaterThan(100000));
        expect(routePixels, greaterThan(1000));
        expect(startPixels, greaterThan(100));
        expect(endPixels, greaterThan(100));
      } finally {
        image.dispose();
      }
      expect(await renderer.isValid(Uint8List.fromList([1, 2])), isFalse);
      expect(await renderer.isValid(tile), isFalse);
    },
  );

  test(
    'image load errors are handled locally and never produce a partial PNG',
    () async {
      final source = _PendingImage();
      final tiles = _Tiles(source);
      final renderer = RouteSnapshotRenderer(
        config: MapTileConfig(tileProviderFactory: () => tiles),
      );
      final render = renderer.render(
        RouteSnapshotScene(snapshotRoute()),
        SnapshotCancellation(),
      );
      final result = expectLater(render, throwsStateError);
      source.completion.completeError(StateError('Tile unavailable'));
      await result;
      expect(tiles.disposed, isTrue);
    },
  );

  test(
    'a cancelled tile placeholder is not accepted as a finished basemap',
    () async {
      final tiles = _Tiles(MemoryImage(TileProvider.transparentImage));
      final renderer = RouteSnapshotRenderer(
        config: MapTileConfig(tileProviderFactory: () => tiles),
      );
      await expectLater(
        renderer.render(
          RouteSnapshotScene(snapshotRoute()),
          SnapshotCancellation(),
        ),
        throwsStateError,
      );
      expect(tiles.disposed, isTrue);
    },
  );

  for (final cancel in [false, true]) {
    test(
      'pending tile requests ${cancel ? 'cancel' : 'time out'} without a blank snapshot',
      () async {
        final source = _PendingImage();
        final tiles = _Tiles(source);
        final renderer = RouteSnapshotRenderer(
          config: MapTileConfig(tileProviderFactory: () => tiles),
          timeout: const Duration(milliseconds: 20),
        );
        final cancellation = SnapshotCancellation();
        final render = renderer.render(
          RouteSnapshotScene(snapshotRoute()),
          cancellation,
        );
        final result = expectLater(render, throwsA(isA<SnapshotCancelled>()));
        if (cancel) cancellation.cancel();
        await result;
        expect(tiles.disposed, isTrue);
        PaintingBinding.instance.imageCache.clear();
      },
    );
  }
}

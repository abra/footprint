import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:component_library/component_library.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_map/flutter_map.dart';

import 'snapshot_cancellation.dart';

abstract interface class SnapshotRenderer {
  Future<Uint8List> render(
    RouteSnapshotScene scene,
    SnapshotCancellation cancellation,
  );
  Future<bool> isValid(Uint8List bytes);
}

/// Uses flutter_map's projection and tile provider, never a mounted map widget.
class RouteSnapshotRenderer implements SnapshotRenderer {
  const RouteSnapshotRenderer({
    required this.config,
    this.timeout = const Duration(seconds: 12),
  });
  final MapTileConfig config;
  final Duration timeout;

  @override
  Future<Uint8List> render(
    RouteSnapshotScene scene,
    SnapshotCancellation cancellation,
  ) async {
    cancellation.check();
    final provider =
        config.tileProviderFactory?.call() ?? NetworkTileProvider();
    final options = TileLayer(
      urlTemplate: config.urlTemplate,
      tileProvider: provider,
      userAgentPackageName: config.userAgentPackageName,
      maxNativeZoom: 19,
    );
    final loading = SnapshotCancellation();
    unawaited(cancellation.whenCancelled.then((_) => loading.cancel()));
    final deadline = Timer(timeout, loading.cancel);
    final images = <({ui.Image image, Rect rect})>[];
    try {
      final camera = scene.camera;
      final zoom = camera.zoom.ceil().clamp(0, 19);
      final scale = math.pow(2, camera.zoom - zoom).toDouble();
      final tileSize = 256 * scale;
      final origin = camera.pixelOrigin;
      final count = 1 << zoom;
      final left = (origin.dx / tileSize).floor();
      final top = (origin.dy / tileSize).floor();
      final right = ((origin.dx + RouteSnapshotScene.size.width) / tileSize)
          .ceil();
      final bottom = ((origin.dy + RouteSnapshotScene.size.height) / tileSize)
          .ceil();
      final tiles = [
        for (var y = top; y < bottom; y++)
          for (var x = left; x < right; x++)
            if (y >= 0 && y < count)
              (
                coordinates: TileCoordinates(x % count, y, zoom),
                rect: Rect.fromLTWH(
                  x * tileSize - origin.dx,
                  y * tileSize - origin.dy,
                  tileSize,
                  tileSize,
                ),
              ),
      ];
      var next = 0;
      Future<void> worker() async {
        while (next < tiles.length) {
          loading.check();
          final tile = tiles[next++];
          final source = provider.supportsCancelLoading
              ? provider.getImageWithCancelLoadingSupport(
                  tile.coordinates,
                  options,
                  loading.whenCancelled,
                )
              : provider.getImage(tile.coordinates, options);
          // A distinct memory-cache key keeps live-map cancellation separate.
          // Both providers still share the normal HTTP/disk tile cache.
          final image = await _load(
            ResizeImage(source, width: 256, height: 256),
            loading,
          );
          images.add((image: image, rect: tile.rect));
        }
      }

      await Future.wait(
        List.generate(4, (_) async {
          try {
            await worker();
          } on Object {
            loading.cancel();
            rethrow;
          }
        }),
      );
      cancellation.check();
      loading.check();
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      canvas.drawColor(AppTheme.surface, BlendMode.src);
      final paint = Paint()..filterQuality = FilterQuality.low;
      for (final tile in images) {
        canvas.drawImageRect(
          tile.image,
          Rect.fromLTWH(
            0,
            0,
            tile.image.width.toDouble(),
            tile.image.height.toDouble(),
          ),
          tile.rect,
          paint,
        );
      }
      scene.paintRoute(canvas);
      final picture = recorder.endRecording();
      try {
        final image = await picture.toImage(
          RouteSnapshotScene.size.width.toInt(),
          RouteSnapshotScene.size.height.toInt(),
        );
        try {
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          cancellation.check();
          return data!.buffer.asUint8List();
        } finally {
          image.dispose();
        }
      } finally {
        picture.dispose();
      }
    } finally {
      deadline.cancel();
      loading.cancel();
      for (final tile in images) {
        tile.image.dispose();
      }
      provider.dispose();
    }
  }

  Future<ui.Image> _load(
    ImageProvider provider,
    SnapshotCancellation cancellation,
  ) async {
    cancellation.check();
    final stream = provider.resolve(ImageConfiguration.empty);
    final result = Completer<ui.Image>();
    final listener = ImageStreamListener(
      (info, synchronous) {
        if (!result.isCompleted) result.complete(info.image.clone());
        info.dispose();
      },
      onError: (Object error, StackTrace? stack) {
        if (!result.isCompleted) result.completeError(error, stack);
      },
    );
    stream.addListener(listener);
    unawaited(
      cancellation.whenCancelled.then((_) {
        if (!result.isCompleted) {
          result.completeError(const SnapshotCancelled());
        }
      }),
    );
    try {
      final image = await result.future;
      if (image.width < 2 || image.height < 2) {
        image.dispose();
        throw StateError('Tile loading returned an empty placeholder');
      }
      return image;
    } finally {
      stream.removeListener(listener);
    }
  }

  @override
  Future<bool> isValid(Uint8List bytes) async {
    try {
      final descriptor = await ui.ImmutableBuffer.fromUint8List(bytes);
      try {
        final image = await ui.ImageDescriptor.encoded(descriptor);
        try {
          if (image.width != RouteSnapshotScene.size.width ||
              image.height != RouteSnapshotScene.size.height) {
            return false;
          }
          final codec = await image.instantiateCodec();
          try {
            final frame = await codec.getNextFrame();
            frame.image.dispose();
            return true;
          } finally {
            codec.dispose();
          }
        } finally {
          image.dispose();
        }
      } finally {
        descriptor.dispose();
      }
    } on Object {
      return false;
    }
  }
}

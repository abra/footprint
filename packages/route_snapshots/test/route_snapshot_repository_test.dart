import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_snapshots/route_snapshots.dart';

import '../../component_library/test/route_snapshot_scene_test.dart'
    show snapshotRoute;
import 'fakes.dart';

class _Renderer implements SnapshotRenderer {
  final calls = <int>[];
  Future<Uint8List> Function(RouteSnapshotScene, SnapshotCancellation)?
  response;
  @override
  Future<Uint8List> render(
    RouteSnapshotScene scene,
    SnapshotCancellation cancellation,
  ) async {
    calls.add(scene.routeId);
    return response == null
        ? Uint8List.fromList([scene.routeId])
        : response!(scene, cancellation);
  }

  @override
  Future<bool> isValid(Uint8List bytes) async =>
      bytes.isNotEmpty && bytes.first != 0;
}

class _SlowStore extends MemorySnapshotStore {
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> write(String key, Uint8List bytes) async {
    entered.complete();
    await release.future;
    await super.write(key, bytes);
  }
}

class _BrokenStore extends MemorySnapshotStore {
  @override
  Future<Uint8List?> read(String key) async =>
      throw StateError('Unavailable disk');
  @override
  Future<void> write(String key, Uint8List bytes) async =>
      throw StateError('Disk full');
}

void main() {
  late _Renderer renderer;
  late MemorySnapshotStore store;
  late RouteSnapshotRepository repository;
  RouteSnapshotScene scene([int id = 1]) =>
      RouteSnapshotScene(snapshotRoute(id: id));
  setUp(() {
    renderer = _Renderer();
    store = MemorySnapshotStore();
    repository = RouteSnapshotRepository(
      config: const MapTileConfig(),
      store: store,
      renderer: renderer,
    );
    addTearDown(repository.dispose);
  });

  test('key changes with geometry and tile source, not the name', () {
    final renamed = RouteSnapshotScene(snapshotRoute(name: 'Renamed'));
    expect(repository.keyFor(renamed), repository.keyFor(scene()));
    final changed = RouteSnapshotScene(
      snapshotRoute(points: [(56, 60), (56.01, 61)]),
    );
    expect(repository.keyFor(changed), isNot(repository.keyFor(scene())));
    final other = RouteSnapshotRepository(
      config: const MapTileConfig(urlTemplate: 'https://other/{z}/{x}/{y}.png'),
      store: store,
      renderer: renderer,
    );
    addTearDown(other.dispose);
    expect(other.keyFor(scene()), isNot(repository.keyFor(scene())));
  });

  for (final version in ['route-snapshot-v1', 'route-snapshot-v2']) {
    test(
      'regenerates cached snapshots with the previous endpoint style ($version)',
      () async {
        final routeScene = scene();
        final oldDigest = sha256.convert(
          utf8.encode(
            jsonEncode([
              version,
              const MapTileConfig().urlTemplate,
              for (final point in routeScene.points)
                [point.latitude, point.longitude],
            ]),
          ),
        );
        final oldKey = '${routeScene.routeId}-$oldDigest';
        store.images[oldKey] = Uint8List.fromList([99]);

        expect(repository.keyFor(routeScene), isNot(oldKey));
        expect(await repository.request(routeScene).image, [1]);
        expect(renderer.calls, [1]);
        expect(store.images[repository.keyFor(routeScene)], [1]);
      },
    );
  }

  test(
    'deduplicates requests and reads persisted images after reopening',
    () async {
      final first = repository.request(scene());
      final second = repository.request(scene());
      expect(await first.image, [1]);
      expect(await second.image, [1]);
      expect(renderer.calls, [1]);
      expect(await repository.request(scene()).image, [1]);
      await repository.dispose();
      final reopened = RouteSnapshotRepository(
        config: const MapTileConfig(),
        store: store,
        renderer: renderer,
      );
      addTearDown(reopened.dispose);
      expect(await reopened.request(scene()).image, [1]);
      expect(renderer.calls, [1]);
    },
  );

  test('serializes rendering and skips cancelled queued work', () async {
    final gate = Completer<Uint8List>();
    final entered = Completer<void>();
    renderer.response = (_, cancellation) {
      entered.complete();
      return gate.future;
    };
    final first = repository.request(scene());
    await entered.future;
    final second = repository.request(scene(2));
    final cancelled = expectLater(
      second.image,
      throwsA(isA<SnapshotCancelled>()),
    );
    second.cancel();
    expect(renderer.calls, [1]);
    gate.complete(Uint8List.fromList([1]));
    await first.image;
    await cancelled;
    expect(renderer.calls, [1]);
    expect(store.images.length, 1);
  });

  test('one subscriber cannot cancel another subscriber', () async {
    final gate = Completer<Uint8List>();
    renderer.response = (_, cancellation) async {
      final result = await gate.future;
      cancellation.check();
      return result;
    };
    final first = repository.request(scene());
    final second = repository.request(scene());
    first.cancel();
    gate.complete(Uint8List.fromList([1]));
    expect(await first.image, [1]);
    expect(await second.image, [1]);
    expect(renderer.calls, [1]);
  });

  test('failed renders are not cached and can be retried', () async {
    renderer.response = (_, _) async => throw StateError('offline');
    await expectLater(repository.request(scene()).image, throwsStateError);
    expect(store.images, isEmpty);
    renderer.response = null;
    expect(await repository.request(scene()).image, [1]);
    expect(renderer.calls, [1, 1]);
  });

  test('corrupt disk cache is regenerated', () async {
    store.images[repository.keyFor(scene())] = Uint8List.fromList([0]);
    expect(await repository.request(scene()).image, [1]);
    expect(renderer.calls, [1]);
    expect(store.images.values.single, [1]);
  });

  test('deletion clears disk and memory and the queue keeps working', () async {
    await repository.request(scene()).image;
    await repository.removeRoute(1);
    expect(store.images, isEmpty);
    expect(await repository.request(scene(2)).image, [2]);
    expect(await repository.request(scene()).image, [1]);
    expect(renderer.calls, [1, 2, 1]);
  });

  test(
    'deletion waits for a write even after its consumer cancelled',
    () async {
      final slow = _SlowStore();
      final cache = RouteSnapshotRepository(
        config: const MapTileConfig(),
        store: slow,
        renderer: renderer,
      );
      addTearDown(cache.dispose);
      final request = cache.request(scene());
      final result = expectLater(
        request.image,
        throwsA(isA<SnapshotCancelled>()),
      );
      await slow.entered.future;
      request.cancel();
      final deleting = cache.removeRoute(1);
      slow.release.complete();
      await deleting;
      await result;
      expect(slow.images, isEmpty);
    },
  );

  test('unavailable disk does not prevent rendering or memory reuse', () async {
    final cache = RouteSnapshotRepository(
      config: const MapTileConfig(),
      store: _BrokenStore(),
      renderer: renderer,
    );
    addTearDown(cache.dispose);
    expect(await cache.request(scene()).image, [1]);
    expect(await cache.request(scene()).image, [1]);
    expect(renderer.calls, [1]);
  });

  test('memory eviction falls back to disk without rendering again', () async {
    final cache = RouteSnapshotRepository(
      config: const MapTileConfig(),
      store: store,
      renderer: renderer,
      maxMemoryBytes: 1,
    );
    addTearDown(cache.dispose);
    await cache.request(scene()).image;
    await cache.request(scene(2)).image;
    expect(await cache.request(scene()).image, [1]);
    expect(renderer.calls, [1, 2]);
  });

  test(
    'dispose cancels an active render without persisting its image',
    () async {
      final entered = Completer<void>();
      renderer.response = (_, cancellation) async {
        entered.complete();
        await cancellation.whenCancelled;
        cancellation.check();
        return Uint8List(0);
      };
      final request = repository.request(scene());
      final result = expectLater(
        request.image,
        throwsA(isA<SnapshotCancelled>()),
      );
      await entered.future;
      await repository.dispose();
      await result;
      expect(store.images, isEmpty);
      expect(() => repository.request(scene()), throwsStateError);
    },
  );
}

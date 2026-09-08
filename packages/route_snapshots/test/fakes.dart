import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:route_snapshots/route_snapshots.dart';

class MemorySnapshotStore implements SnapshotStore {
  final images = <String, Uint8List>{};
  @override
  Future<Uint8List?> read(String key) async => images[key];
  @override
  Future<void> write(String key, Uint8List bytes) async => images[key] = bytes;
  @override
  Future<void> remove(String key) async => images.remove(key);
  @override
  Future<void> removeRoute(int routeId) async =>
      images.removeWhere((key, _) => key.startsWith('$routeId-'));
}

class UnavailableSnapshotRenderer implements SnapshotRenderer {
  @override
  Future<Uint8List> render(
    RouteSnapshotScene scene,
    SnapshotCancellation cancellation,
  ) async => throw StateError('Fixture tiles unavailable');
  @override
  Future<bool> isValid(Uint8List bytes) async => false;
}

RouteSnapshotRepository unavailableSnapshots() => RouteSnapshotRepository(
  config: const MapTileConfig(),
  store: MemorySnapshotStore(),
  renderer: UnavailableSnapshotRenderer(),
);

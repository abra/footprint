import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:developer';
import 'dart:typed_data';

import 'package:component_library/component_library.dart';
import 'package:crypto/crypto.dart';

import 'route_snapshot_renderer.dart';
import 'snapshot_cancellation.dart';
import 'snapshot_store.dart';

class SnapshotRequest {
  SnapshotRequest(this.image, this._cancel);
  final Future<Uint8List> image;
  final void Function() _cancel;
  bool _cancelled = false;

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    _cancel();
  }
}

/// Composition-owned, lazy on-demand cache. Only one snapshot is rendered at a time.
class RouteSnapshotRepository {
  RouteSnapshotRepository({
    required MapTileConfig config,
    required this._store,
    SnapshotRenderer? renderer,
    this.maxMemoryBytes = 8 * 1024 * 1024,
  }) : _config = config,
       _renderer = renderer ?? RouteSnapshotRenderer(config: config);

  final MapTileConfig _config;
  final SnapshotStore _store;
  final SnapshotRenderer _renderer;
  final int maxMemoryBytes;
  final _memory = <String, Uint8List>{};
  final _pending = <String, _Job>{};
  final _jobs = <_Job>{};
  final _queue = Queue<_Job>();
  Future<void>? _worker;
  bool _closed = false;
  int _memoryBytes = 0;

  String keyFor(RouteSnapshotScene scene) {
    final digest = sha256.convert(
      utf8.encode(
        jsonEncode([
          'route-snapshot-v3',
          _config.urlTemplate,
          for (final point in scene.points) [point.latitude, point.longitude],
        ]),
      ),
    );
    return '${scene.routeId}-$digest';
  }

  SnapshotRequest request(RouteSnapshotScene scene) {
    if (_closed) throw StateError('Route snapshot repository is closed');
    final key = keyFor(scene);
    final cached = _memory.remove(key);
    if (cached != null) {
      _memory[key] = cached;
      return SnapshotRequest(Future.value(cached), () {});
    }
    var job = _pending[key];
    if (job == null) {
      job = _Job(key, scene);
      _pending[key] = job;
      _jobs.add(job);
      _queue.add(job);
    }
    final current = job;
    current.readers++;
    _startWorker();
    return SnapshotRequest(current.completion.future, () {
      current.readers--;
      if (current.readers == 0 && !current.completion.isCompleted) {
        current.cancellation.cancel();
        if (identical(_pending[key], current)) _pending.remove(key);
      }
    });
  }

  void _startWorker() {
    _worker ??= _drain().whenComplete(() {
      _worker = null;
      if (_queue.isNotEmpty) _startWorker();
    });
  }

  Future<void> _drain() async {
    while (_queue.isNotEmpty) {
      final job = _queue.removeFirst();
      try {
        job.cancellation.check();
        Uint8List? image;
        await _cacheOperation(() async {
          final bytes = await _store.read(job.key);
          if (bytes != null) {
            if (await _renderer.isValid(bytes)) {
              image = bytes;
            } else {
              await _store.remove(job.key);
            }
          }
        });
        job.cancellation.check();
        if (image == null) {
          image = await _renderer.render(job.scene, job.cancellation);
          job.cancellation.check();
          await _cacheOperation(() => _store.write(job.key, image!));
        }
        job.cancellation.check();
        _remember(job.key, image!);
        job.completion.complete(image);
      } on Object catch (error, stack) {
        job.completion.completeError(error, stack);
      } finally {
        _jobs.remove(job);
        if (identical(_pending[job.key], job)) _pending.remove(job.key);
      }
    }
  }

  void _remember(String key, Uint8List image) {
    final previous = _memory.remove(key);
    if (previous != null) _memoryBytes -= previous.length;
    _memory[key] = image;
    _memoryBytes += image.length;
    while (_memoryBytes > maxMemoryBytes && _memory.isNotEmpty) {
      _memoryBytes -= _memory.remove(_memory.keys.first)!.length;
    }
  }

  Future<void> removeRoute(int routeId) async {
    final jobs = _jobs.where((job) => job.scene.routeId == routeId).toList();
    for (final job in jobs) {
      job.cancellation.cancel();
      if (identical(_pending[job.key], job)) _pending.remove(job.key);
    }
    for (final job in jobs) {
      try {
        await job.completion.future;
      } on Object {
        // Wait for any in-flight atomic write before deleting the route's files.
      }
    }
    for (final key
        in _memory.keys.where((key) => key.startsWith('$routeId-')).toList()) {
      _memoryBytes -= _memory.remove(key)!.length;
    }
    await _cacheOperation(() => _store.removeRoute(routeId));
  }

  Future<void> _cacheOperation(Future<void> Function() action) async {
    try {
      await action();
    } on Object catch (error, stack) {
      log(
        'Snapshot cache unavailable',
        name: 'RouteSnapshots',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> dispose() async {
    if (_closed) return;
    _closed = true;
    for (final job in _jobs) {
      job.cancellation.cancel();
    }
    await _worker;
    _memory.clear();
    _memoryBytes = 0;
  }
}

class _Job {
  _Job(this.key, this.scene);
  final String key;
  final RouteSnapshotScene scene;
  final cancellation = SnapshotCancellation();
  final completion = Completer<Uint8List>();
  int readers = 0;
}

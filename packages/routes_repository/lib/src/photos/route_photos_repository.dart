import 'dart:async';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:uuid/uuid.dart';

import 'photo_files.dart';
import 'photo_picker.dart';

/// App-owned capture lifecycle. Closing a screen never cancels a photo write.
class RoutePhotosRepository {
  RoutePhotosRepository({
    required this._dao,
    required this._picker,
    required this._files,
    DateTime Function()? now,
    String Function()? createId,
  }) : _now = now ?? DateTime.now,
       _createId = createId ?? const Uuid().v4;

  final RoutePhotosDao _dao;
  final PhotoPicker _picker;
  final PhotoFiles _files;
  final DateTime Function() _now;
  final String Function() _createId;
  final _changes = StreamController<int>.broadcast();
  Future<void> _tail = Future.value();
  Future<void>? _closing;
  bool _capturing = false;
  bool _initialized = false;

  Stream<int> get changes => _changes.stream;

  Future<T> _serialize<T>(Future<T> Function() action) {
    if (_closing != null) return Future.error(StateError('Photos are closed.'));
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  Future<void> initialize() => _serialize(() async {
    if (_initialized) return;
    await _recover(checkLostData: true);
    await _prune();
    _initialized = true;
  });

  Future<List<RoutePhotoDM>> getPhotos(int routeId) => _serialize(
    () async => [
      for (final row in await _dao.getForRoute(routeId))
        RoutePhotoDM(
          id: row.id,
          routeId: row.routeId,
          path: await _files.resolve(row.fileName),
          latitude: row.latitude,
          longitude: row.longitude,
          capturedAt: row.capturedAt,
        ),
    ],
  );

  Future<void> capture({
    required int routeId,
    required LocationDM location,
    required PhotoSource source,
  }) {
    if (_capturing) {
      return Future.error(StateError('A photo is already being captured.'));
    }
    if (!location.hasValidCoordinates) {
      return Future.error(ArgumentError('Invalid location.'));
    }
    final id = _createId();
    final pending = RoutePhoto(
      id: id,
      routeId: routeId,
      fileName: '$id.image',
      latitude: location.latitude,
      longitude: location.longitude,
      capturedAt: _now(),
    );
    _capturing = true;
    return _serialize(() async {
      // Finish any previous interrupted copy before starting another picker.
      await _recover();
      await _dao.beginCapture(pending);
      String? sourcePath;
      try {
        sourcePath = await _picker.pick(source);
      } on Object {
        await _dao.cancelCapture(id);
        rethrow;
      }
      if (sourcePath == null) {
        await _dao.cancelCapture(id);
        return;
      }
      await _dao.setSource(id, sourcePath);
      await _finish(pending, sourcePath);
    }).whenComplete(() => _capturing = false);
  }

  Future<void> retryPending() => _serialize(_recover);

  Future<void> discardPending() => _serialize(() async {
    if (await _dao.getPending() case final pending?) {
      await _dao.cancelCapture(pending.id);
      await _prune();
    }
  });

  Future<void> _recover({bool checkLostData = false}) async {
    final pending = await _dao.getPending();
    final recovered =
        checkLostData || (pending != null && pending.sourcePath == null)
        ? await _picker.recover()
        : null;
    if (pending == null) return;
    final source = pending.sourcePath ?? recovered;
    if (await _files.exists(pending.fileName)) {
      await _dao.finishCapture(pending);
      _changes.add(pending.routeId);
    } else if (source != null) {
      await _dao.setSource(pending.id, source);
      await _finish(pending, source);
    } else {
      await _dao.cancelCapture(pending.id);
    }
  }

  Future<void> _finish(RoutePhoto pending, String source) async {
    await _files.import(source, pending.fileName);
    await _dao.finishCapture(pending);
    _changes.add(pending.routeId);
  }

  Future<void> deletePhoto(int routeId, String id) => _serialize(() async {
    await _dao.delete(routeId, id);
    _changes.add(routeId);
    await _prune();
  });

  Future<void> collectGarbage() => _serialize(_prune);

  Future<void> _prune() async {
    try {
      await _files.prune(await _dao.referencedFiles());
    } on Object catch (error, stack) {
      // Metadata is already committed; retry file cleanup on the next launch.
      log(
        'Photo cleanup deferred',
        name: 'RoutePhotos',
        error: error,
        stackTrace: stack,
      );
    }
  }

  Future<void> dispose() => _closing ??= _tail.then((_) => _changes.close());
}

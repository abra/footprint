import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'location_service.dart';
import 'device_location.dart';

class ForegroundLocationService implements LocationService {
  ForegroundLocationService({required this._backend});

  final LocationBackend _backend;
  final _locations = StreamController<LocationDM>.broadcast();
  StreamSubscription<LocationDM>? _subscription;
  Future<void> _operations = Future.value();
  Future<void>? _disposal;
  Future<LocationDM>? _currentLocation;
  LocationMode _mode = LocationMode.stopped;
  bool _needsStop = false;
  bool _failed = false;
  Object? _failure;
  bool _disposed = false;
  int _generation = 0;
  LocationDM? _lastLocation;

  static void initCommunicationPort() =>
      FlutterForegroundTask.initCommunicationPort();

  @override
  Stream<LocationDM> get locations => _locations.stream;

  @override
  LocationDM? get lastLocation => _lastLocation;

  @override
  Future<LocationDM> currentLocation() {
    if (_disposed) {
      return Future.error(StateError('Location service is closed.'));
    }
    // Share one bounded request, independently of the recording command queue.
    return _currentLocation ??= _backend
        .currentLocation()
        .timeout(DeviceLocation.acquisitionTimeout)
        .then((location) {
          if (_disposed) throw StateError('Location service is closed.');
          return location;
        })
        .whenComplete(() => _currentLocation = null);
  }

  @override
  Future<void> setMode(
    LocationMode mode, {
    bool restart = false,
    LocationDM? initialLocation,
  }) {
    if (_disposed) {
      return Future.error(StateError('Location service is closed.'));
    }
    final operation = _operations.then((_) {
      if (initialLocation != null &&
          (_lastLocation == null ||
              initialLocation.timestamp.isAfter(_lastLocation!.timestamp))) {
        _lastLocation = initialLocation;
      }
      return _setMode(mode, restart: restart);
    });
    // Callers receive failures; the next command must still be able to recover.
    _operations = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> _setMode(LocationMode mode, {bool restart = false}) async {
    if (_disposed && mode != LocationMode.stopped) return;
    if (_mode == mode && !_failed && !restart) return;
    ++_generation;
    await _subscription?.cancel();
    _subscription = null;
    try {
      if (_needsStop) await _backend.stop();
      _needsStop = false;
      _mode = LocationMode.stopped;
      _failed = false;
      _failure = null;
      if (mode == LocationMode.stopped || _disposed) return;
      final generation = _generation;
      _subscription = _backend.locations.listen(
        (location) {
          if (_disposed || generation != _generation) return;
          _lastLocation = location;
          _locations.add(location);
        },
        onError: (Object error, StackTrace stack) {
          if (_disposed || generation != _generation) return;
          _failed = true;
          _failure = error;
          _locations.addError(error, stack);
        },
        onDone: () {
          if (_disposed || generation != _generation) return;
          _failed = true;
          _failure = StateError('Location stream stopped unexpectedly.');
          _locations.addError(_failure!);
        },
      );
      _needsStop = true;
      await _backend.start(
        background: mode == LocationMode.recording,
        initialLocation: _lastLocation,
      );
      if (_failed) throw _failure!;
      _mode = mode;
    } on Object {
      _failed = true;
      rethrow;
    }
  }

  @override
  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _disposed = true;
    await _operations;
    try {
      await _setMode(LocationMode.stopped, restart: true);
    } finally {
      await _backend.dispose();
      await _locations.close();
    }
  }
}

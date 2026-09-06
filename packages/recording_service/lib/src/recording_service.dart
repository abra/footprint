import 'dart:async';
import 'dart:collection';
import 'dart:developer';

import 'package:domain_models/domain_models.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:routes_repository/routes_repository.dart';

import 'recording_state.dart';

/// Owns the recording session independently of any mounted screen.
class RecordingService {
  RecordingService({
    required LocationService locationService,
    required RoutesRepository routesRepository,
  }) : _location = locationService,
       _routes = routesRepository {
    _subscription = _location.locations.listen(
      _onLocation,
      onError: _onLocationError,
    );
  }

  final LocationService _location;
  final RoutesRepository _routes;
  final _states = StreamController<RecordingState>.broadcast();
  final _pending = Queue<LocationDM>();
  final _savedIds = <String>{};
  late final StreamSubscription<LocationDM> _subscription;
  RecordingState _state = const RecordingState();
  Future<void> _commands = Future.value();
  Future<void>? _initialization;
  Future<void>? _disposal;
  bool _initialized = false;
  bool _closing = false;
  bool _flushScheduled = false;
  int _previewClients = 0;
  LocationDM? _startLocation;
  DateTime? _stopTime;

  RecordingState get state => _state;
  Stream<RecordingState> get states => _states.stream;

  Future<void> initialize() {
    if (_closing || _initialized) return Future.value();
    return _initialization ??= _run(RecordingOperation.restore, () async {
      await _restore();
      _initialized = true;
      if (state.failure?.operation == RecordingOperation.restore) {
        _emit(state.copyWith(clearFailure: true));
      }
    }).whenComplete(() => _initialization = null);
  }

  Future<void> _restore() async {
    final route = await _routes.getActiveRoute();
    if (route == null) {
      _savedIds.clear();
      _emit(state.copyWith(phase: RecordingPhase.idle, clearRoute: true));
      return;
    }
    final points = [
      for (final point in route.routePoints)
        LocationDM(
          id: point.sourceId ?? 'stored:${point.id}',
          latitude: point.latitude,
          longitude: point.longitude,
          timestamp: point.timestamp,
        ),
    ];
    _savedIds
      ..clear()
      ..addAll(points.map((point) => point.id));
    _emit(
      state.copyWith(
        phase: RecordingPhase.recording,
        routeId: route.id,
        points: points,
        clearFailure: state.failure?.operation == RecordingOperation.restore,
      ),
    );
  }

  Future<void> attachPreview() async {
    if (_closing) return;
    _previewClients++;
    await initialize();
    await _updateLocation();
    if (_location.lastLocation case final location?
        when state.location == null) {
      _onLocation(location);
    }
  }

  Future<void> detachPreview() {
    if (_previewClients > 0) _previewClients--;
    return _updateLocation();
  }

  Future<void> setForeground(bool foreground) {
    if (_closing) return Future.value();
    final resumed = foreground && !state.foreground;
    _emit(state.copyWith(foreground: foreground));
    return _queue(() async {
      // A background worker can have persisted points while the UI was suspended.
      if (resumed &&
          state.routeId != null &&
          state.failure == null &&
          state.phase == RecordingPhase.recording) {
        try {
          await _restore();
        } on Object catch (error, stack) {
          _fail(RecordingOperation.restore, error, stack);
        }
      }
      await _applyLocation();
    });
  }

  LocationMode get _desiredMode {
    if (_closing || state.phase == RecordingPhase.stopping) {
      return LocationMode.stopped;
    }
    if (state.routeId != null) return LocationMode.recording;
    return state.foreground && _previewClients > 0
        ? LocationMode.preview
        : LocationMode.stopped;
  }

  Future<void> _updateLocation({bool restart = false}) =>
      _queue(() => _applyLocation(restart: restart));

  Future<void> _applyLocation({bool restart = false}) async {
    try {
      await _location.setMode(_desiredMode, restart: restart);
      _emit(state.copyWith(clearLocationError: true));
    } on Object catch (error, stack) {
      _onLocationError(error, stack);
    }
  }

  void _onLocation(LocationDM location) {
    if (_closing) return;
    if (!location.hasValidCoordinates) {
      _onLocationError(
        const FormatException('Invalid GPS coordinates.'),
        StackTrace.current,
      );
      return;
    }
    _emit(state.copyWith(location: location, clearLocationError: true));
    if (state.phase != RecordingPhase.recording &&
        state.phase != RecordingPhase.starting) {
      return;
    }
    _pending.add(location);
    if (_flushScheduled) return;
    _flushScheduled = true;
    unawaited(
      _run(RecordingOperation.savePoint, () async {
        try {
          await _flush();
        } finally {
          _flushScheduled = false;
        }
      }),
    );
  }

  Future<void> start() {
    if (_closing ||
        !_initialized ||
        state.isRecording ||
        state.location == null) {
      return Future.value();
    }
    _startLocation = state.location;
    _pending.clear();
    _emit(state.copyWith(phase: RecordingPhase.starting, clearFailure: true));
    return _run(RecordingOperation.start, _start);
  }

  Future<void> _start() async {
    if (state.routeId == null) {
      final location = _startLocation!;
      final id = await _routes.startRoute(location);
      _savedIds
        ..clear()
        ..add(location.id);
      _emit(state.copyWith(routeId: id, points: [location]));
    }
    await _flush();
    await _location.setMode(_desiredMode);
    _emit(
      state.copyWith(
        phase: RecordingPhase.recording,
        clearFailure: true,
        clearLocationError: true,
      ),
    );
  }

  Future<void> stop() {
    if (_closing || state.isBusy || state.routeId == null) {
      return Future.value();
    }
    _stopTime ??= DateTime.now();
    _emit(state.copyWith(phase: RecordingPhase.stopping, clearFailure: true));
    return _run(RecordingOperation.stop, _stop);
  }

  Future<void> _stop() async {
    await _location.setMode(LocationMode.stopped);
    await _flush();
    final id = state.routeId!;
    await _routes.finishRoute(id, _stopTime!);
    // Include points acknowledged by the background worker during its shutdown.
    final route = await _routes.getRoute(id);
    final points = route == null
        ? state.points
        : [
            for (final point in route.routePoints)
              LocationDM(
                id: point.sourceId ?? 'stored:${point.id}',
                latitude: point.latitude,
                longitude: point.longitude,
                timestamp: point.timestamp,
              ),
          ];
    _stopTime = null;
    _emit(
      state.copyWith(
        phase: RecordingPhase.idle,
        clearRoute: true,
        points: points,
        clearFailure: true,
      ),
    );
    await _applyLocation();
  }

  Future<void> retry() {
    if (_closing || state.isBusy) return Future.value();
    final failure = state.failure;
    if (failure == null) return _updateLocation(restart: true);
    switch (failure.operation) {
      case RecordingOperation.restore:
        _initialized = false;
        return initialize().then((_) => _updateLocation());
      case RecordingOperation.start:
        _emit(
          state.copyWith(phase: RecordingPhase.starting, clearFailure: true),
        );
        return _run(RecordingOperation.start, _start);
      case RecordingOperation.savePoint:
        return _run(RecordingOperation.savePoint, () async {
          await _flush();
          _emit(state.copyWith(clearFailure: true));
        });
      case RecordingOperation.stop:
        return stop();
    }
  }

  Future<void> _flush() async {
    final id = state.routeId;
    if (id == null) return;
    while (_pending.isNotEmpty) {
      final location = _pending.first;
      await _routes.addPoint(id, location);
      _pending.removeFirst();
      if (_savedIds.add(location.id)) {
        _emit(state.copyWith(points: [...state.points, location]));
      }
    }
  }

  Future<void> _run(
    RecordingOperation operation,
    Future<void> Function() work,
  ) => _queue(() async {
    try {
      await work();
    } on Object catch (error, stack) {
      _fail(operation, error, stack);
    }
  });

  Future<void> _queue(Future<void> Function() work) {
    if (_closing) return Future.value();
    final result = _commands.then((_) => work());
    _commands = result.then<void>(
      (_) {},
      onError: (Object error, StackTrace stack) {
        log(
          'Recording command failed',
          name: 'RecordingService',
          error: error,
          stackTrace: stack,
        );
      },
    );
    return result;
  }

  void _fail(RecordingOperation operation, Object error, StackTrace stack) {
    log(
      'Recording operation failed: ${operation.name}',
      name: 'RecordingService',
      error: error,
      stackTrace: stack,
    );
    final phase = state.phase == RecordingPhase.starting
        ? (state.routeId == null
              ? RecordingPhase.idle
              : RecordingPhase.recording)
        : state.phase;
    _emit(
      state.copyWith(
        phase: phase,
        failure: RecordingFailure(operation, error, stack),
      ),
    );
  }

  void _onLocationError(Object error, StackTrace stack) {
    log(
      'Location tracking failed',
      name: 'RecordingService',
      error: error,
      stackTrace: stack,
    );
    _emit(state.copyWith(locationError: error));
  }

  void _emit(RecordingState value) {
    _state = value;
    if (!_states.isClosed) _states.add(value);
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    _closing = true;
    await _commands;
    try {
      await _location.setMode(LocationMode.stopped);
    } finally {
      await _subscription.cancel();
      try {
        await _flush();
      } finally {
        await _states.close();
      }
    }
  }
}

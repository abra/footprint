import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:recording_service/recording_service.dart';
import 'package:routes_repository/routes_repository.dart';

import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit({
    required RecordingService recordingService,
    required RoutePhotosRepository photosRepository,
    required GeocodingManager geocodingManager,
    DateTime Function()? now,
    WalksRepository? walksRepository,
  }) : _recording = recordingService,
       _photos = photosRepository,
       _geocoding = geocodingManager,
       _now = now ?? DateTime.now,
       _walks = walksRepository,
       super(const MapState());

  final RecordingService _recording;
  final WalksRepository? _walks;
  int _walkRequest = 0;

  Future<void> retryWalk() async {
    final request = ++_walkRequest;
    final id = state.routeId;
    try {
      final walk = id == null ? null : await _walks?.getProgress(id);
      if (_closing != null || isClosed || request != _walkRequest) return;
      emit(
        state.copyWith(
          walk: walk,
          clearWalk: walk == null,
          clearWalkError: true,
        ),
      );
    } on Object catch (error, stack) {
      if (_closing != null || isClosed || request != _walkRequest) return;
      addError(error, stack);
      emit(state.copyWith(walkError: 'Walk progress could not be loaded.'));
    }
  }

  final RoutePhotosRepository _photos;
  StreamSubscription<int>? _photoSubscription;
  int _photoRequest = 0;
  final GeocodingManager _geocoding;
  final DateTime Function() _now;
  Timer? _metricsTimer;
  RouteMetrics _trace = const RouteMetrics();
  StreamSubscription<RecordingState>? _subscription;
  Timer? _addressDebounce;
  Future<void>? _initialization;
  Future<void>? _closing;
  LocationDM? _addressLocation;
  List<LocationDM>? _points;
  int _addressRequest = 0;
  bool _attached = false;

  Future<void> initialize() {
    if (_closing != null || isClosed) return Future.value();
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    _photoSubscription = _photos.changes.listen((id) {
      if (id == state.routeId) unawaited(_loadPhotos(id));
    });
    _subscription = _recording.states.listen(_onRecording);
    _onRecording(_recording.state);
    _attached = true;
    await _recording.attachPreview();
    await retryPhotos();
  }

  Future<void> _loadPhotos(int? routeId) async {
    final request = ++_photoRequest;
    try {
      final photos = routeId == null
          ? <RoutePhotoDM>[]
          : await _photos.getPhotos(routeId);
      if (_closing != null || isClosed || request != _photoRequest) return;
      emit(state.copyWith(photos: photos));
    } on Object catch (error, stack) {
      if (_closing != null || isClosed || request != _photoRequest) return;
      addError(error, stack);
      emit(state.copyWith(photoError: 'Route photos could not be loaded.'));
    }
  }

  Future<void> retryPhotos() async {
    if (_closing != null || isClosed || state.photoBusy) return;
    emit(state.copyWith(photoBusy: true, clearPhotoError: true));
    try {
      await _photos.initialize();
      await _photos.retryPending();
      if (_closing == null && !isClosed) await _loadPhotos(state.routeId);
    } on Object catch (error, stack) {
      if (_closing != null || isClosed) return;
      addError(error, stack);
      emit(
        state.copyWith(
          photoError: 'Photo could not be restored. Retry or discard the pending photo.',
        ),
      );
    } finally {
      if (_closing == null && !isClosed) emit(state.copyWith(photoBusy: false));
    }
  }

  Future<void> capturePhoto(PhotoSource source) async {
    if (_closing != null ||
        isClosed ||
        state.photoBusy ||
        state.recordingBusy ||
        !state.isRecording) {
      return;
    }
    final routeId = state.routeId;
    final location = state.location;
    if (routeId == null || location == null) return;
    emit(state.copyWith(photoBusy: true, clearPhotoError: true));
    try {
      await _photos.capture(
        routeId: routeId,
        location: location,
        source: source,
      );
      if (_closing == null && !isClosed && state.routeId == routeId) {
        await _loadPhotos(routeId);
      }
    } on Object catch (error, stack) {
      if (_closing != null || isClosed) return;
      addError(error, stack);
      emit(
        state.copyWith(
          photoError: error is PhotoSelectionException
              ? error.message
              : 'Photo could not be saved. Retry or discard the pending photo.',
        ),
      );
    } finally {
      if (_closing == null && !isClosed) emit(state.copyWith(photoBusy: false));
    }
  }

  Future<void> discardPendingPhoto() async {
    if (_closing != null || isClosed || state.photoBusy) return;
    emit(state.copyWith(photoBusy: true));
    try {
      await _photos.discardPending();
      if (_closing == null && !isClosed) {
        emit(state.copyWith(clearPhotoError: true));
      }
    } on Object catch (error, stack) {
      if (_closing == null && !isClosed) addError(error, stack);
    } finally {
      if (_closing == null && !isClosed) emit(state.copyWith(photoBusy: false));
    }
  }

  void _onRecording(RecordingState recording) {
    if (_closing != null || isClosed) return;
    final error = recording.failure == null
        ? recording.locationError?.toString()
        : switch (recording.failure!.operation) {
            RecordingOperation.restore =>
              'Route could not be restored. Please try again.',
            RecordingOperation.start =>
              'Recording could not be started. Please try again.',
            RecordingOperation.savePoint =>
              'Route could not be saved. Please try again.',
            RecordingOperation.stop =>
              'Recording could not be stopped. Please try again.',
          };
    final routeChanged = state.routeId != recording.routeId;
    // Starting a new recording must not briefly replay the previous route.
    final points = recording.isRecording && recording.routeId == null
        ? const <LocationDM>[]
        : recording.points;
    final pointsChanged = !identical(_points, points);
    _points = points;
    if (pointsChanged) _trace = RouteMetrics.fromLocations(points);
    final completedId = state.isRecording && !recording.isRecording
        ? state.routeId
        : null;
    if (recording.isRecording && recording.foreground) {
      _metricsTimer ??= Timer.periodic(
        const Duration(seconds: 1),
        (_) => _tick(),
      );
    } else {
      _metricsTimer?.cancel();
      _metricsTimer = null;
    }
    emit(
      state.copyWith(
        location: recording.location,
        locationLoading: recording.location == null && error == null,
        points: pointsChanged ? points : null,
        isRecording: recording.isRecording,
        recordingAction: recording.isBusy
            ? (recording.phase == RecordingPhase.stopping
                  ? RecordingAction.stop
                  : RecordingAction.start)
            : null,
        clearRecordingAction: !recording.isBusy,
        routeId: recording.routeId,
        clearRoute: recording.routeId == null,
        photos: routeChanged ? const [] : null,
        completedRouteId: completedId,
        lastRouteHidden: routeChanged && recording.routeId != null
            ? false
            : state.lastRouteHidden,
        metrics: _metrics(recording),
        statsExpanded: routeChanged || !recording.isRecording
            ? false
            : state.statsExpanded,
        error: error,
        clearError: error == null,
      ),
    );
    if (routeChanged) unawaited(_loadPhotos(recording.routeId));
    if (_walks != null && (routeChanged || pointsChanged)) {
      unawaited(retryWalk());
    }
    if (!recording.foreground) {
      _cancelAddress();
      _addressLocation = null;
      return;
    }
    final location = recording.location;
    if (location == null ||
        (location.latitude == _addressLocation?.latitude &&
            location.longitude == _addressLocation?.longitude)) {
      return;
    }
    _addressLocation = location;
    _cancelAddress();
    final request = _addressRequest;
    _addressDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_lookupAddress(location, request)),
    );
  }

  RouteMetrics _metrics(RecordingState recording) {
    if (!recording.isRecording ||
        recording.routeId == null ||
        recording.points.isEmpty) {
      return _trace;
    }
    return _trace.atTime(
      start: recording.points.first.timestamp,
      lastSample: recording.points.last.timestamp,
      now: _now(),
    );
  }

  void _tick() {
    if (_closing == null && !isClosed) {
      emit(state.copyWith(metrics: _metrics(_recording.state)));
    }
  }

  void _cancelAddress() {
    _addressDebounce?.cancel();
    ++_addressRequest;
  }

  Future<void> _lookupAddress(LocationDM location, int request) async {
    try {
      final address = await _geocoding.getAddressFromCoordinates(location);
      if (_closing != null || isClosed || request != _addressRequest) return;
      emit(state.copyWith(address: address?.address ?? 'Address unavailable'));
    } on Object catch (error, stack) {
      if (_closing != null || isClosed || request != _addressRequest) return;
      addError(error, stack);
      emit(state.copyWith(address: 'Address unavailable'));
    }
  }

  Future<void> startRecording() =>
      _closing != null ? Future.value() : _recording.start();
  Future<void> stopRecording() =>
      _closing != null || state.photoBusy ? Future.value() : _recording.stop();
  Future<void> retry() =>
      _closing != null ? Future.value() : _recording.retry();

  void setCentered(bool value) {
    if (_closing == null && !isClosed) emit(state.copyWith(centered: value));
  }

  void cycleFollowMode() {
    if (_closing != null || isClosed) return;
    if (!state.centered) {
      emit(state.copyWith(centered: true));
    } else {
      emit(
        state.copyWith(
          orientation: state.orientation == MapOrientation.northUp
              ? MapOrientation.courseUp
              : MapOrientation.northUp,
        ),
      );
    }
  }

  void toggleStats() {
    if (_closing != null || isClosed || !state.isRecording) return;
    emit(state.copyWith(statsExpanded: !state.statsExpanded));
  }

  void hideLastRoute() {
    if (_closing != null || isClosed || !state.showsLastRoute) return;
    emit(state.copyWith(lastRouteHidden: true));
  }

  void tilesFailed() {
    if (_closing == null && !isClosed && !state.tileError) {
      emit(state.copyWith(tileError: true));
    }
  }

  void retryTiles() {
    if (_closing == null && !isClosed) {
      emit(
        state.copyWith(
          tileError: false,
          tileGeneration: state.tileGeneration + 1,
        ),
      );
    }
  }

  @override
  Future<void> close() {
    if (_closing case final closing?) return closing;
    _cancelAddress();
    _metricsTimer?.cancel();
    if (_attached) unawaited(_recording.detachPreview());
    return _closing = Future.wait<void>([
      super.close(),
      ?_subscription?.cancel(),
      ?_photoSubscription?.cancel(),
    ]).then((_) {});
  }
}

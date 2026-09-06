import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:recording_service/recording_service.dart';

import 'map_state.dart';

class MapCubit extends Cubit<MapState> {
  MapCubit({
    required RecordingService recordingService,
    required GeocodingManager geocodingManager,
  }) : _recording = recordingService,
       _geocoding = geocodingManager,
       super(const MapState());

  final RecordingService _recording;
  final GeocodingManager _geocoding;
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
    _subscription = _recording.states.listen(_onRecording);
    _onRecording(_recording.state);
    _attached = true;
    await _recording.attachPreview();
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
    final pointsChanged = !identical(_points, recording.points);
    _points = recording.points;
    emit(
      state.copyWith(
        location: recording.location,
        locationLoading: recording.location == null && error == null,
        points: pointsChanged ? recording.points : null,
        isRecording: recording.isRecording,
        recordingBusy: recording.isBusy,
        error: error,
        clearError: error == null,
      ),
    );
    if (!recording.foreground) {
      _cancelAddress();
      _addressLocation = null;
      return;
    }
    final location = recording.location;
    if (location == null || location == _addressLocation) return;
    _addressLocation = location;
    _cancelAddress();
    final request = _addressRequest;
    _addressDebounce = Timer(
      const Duration(milliseconds: 300),
      () => unawaited(_lookupAddress(location, request)),
    );
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
      _closing != null ? Future.value() : _recording.stop();
  Future<void> retry() =>
      _closing != null ? Future.value() : _recording.retry();

  void setCentered(bool value) {
    if (_closing == null && !isClosed) emit(state.copyWith(centered: value));
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
    if (_attached) unawaited(_recording.detachPreview());
    return _closing = Future.wait<void>([
      super.close(),
      ?_subscription?.cancel(),
    ]).then((_) {});
  }
}

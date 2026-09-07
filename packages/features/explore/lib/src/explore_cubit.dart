import 'dart:async';
import 'dart:math' as math;

import 'package:domain_models/domain_models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_planning/route_planning.dart';
import 'package:routes_repository/routes_repository.dart';

import 'explore_state.dart';

class ExploreCubit extends Cubit<ExploreState> {
  ExploreCubit({
    required this._planner,
    required this._walks,
    required this._recording,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const ExploreState());

  final RoutePlanner _planner;
  final WalksRepository _walks;
  final RecordingService _recording;
  final DateTime Function() _now;
  StreamSubscription<RecordingState>? _subscription;
  Timer? _viewportTimer;
  Completer<LocationDM?>? _locationRequest;
  int _generation = 0;
  int _viewportRequest = 0;
  bool _closing = false;
  bool _attached = false;
  bool get planningAvailable => _planner.available;

  Future<void> initialize() async {
    if (_attached || _closing) return;
    _attached = true;
    _subscription = _recording.states.listen((recording) {
      if (_closing) return;
      final needsLocation =
          state.mode == RoutePlanMode.loop ||
          state.start == null ||
          state.starting;
      emit(
        state.copyWith(
          location: recording.location,
          recording: recording.isRecording,
          locationError: !needsLocation || recording.locationError == null
              ? null
              : _locationMessage(recording.locationError!),
          clearLocationError:
              !needsLocation ||
              (recording.locationError == null && _usable(recording.location)),
        ),
      );
      if (recording.isRecording && state.generating) cancelGeneration();
    });
    emit(
      state.copyWith(
        location: _recording.state.location,
        recording: _recording.state.isRecording,
      ),
    );
    await _recording.attachPreview();
    await refreshProfile();
  }

  Future<void> refreshProfile() async {
    try {
      final profile = await _walks.getProfile();
      if (!_closing) emit(state.copyWith(profile: profile));
    } on Object catch (error, stack) {
      if (_closing) return;
      addError(error, stack);
      emit(state.copyWith(error: 'Exploration progress could not be loaded.'));
    }
  }

  void selectDistance(double meters) {
    if (_closing ||
        state.starting ||
        !meters.isFinite ||
        meters < 1000 ||
        meters > 20000) {
      return;
    }
    cancelGeneration();
    emit(state.copyWith(distance: meters, clearPlan: true, clearError: true));
  }

  void showProgress(bool value) {
    if (!_closing) {
      emit(state.copyWith(showProgress: value));
      if (value) unawaited(refreshProfile());
    }
  }

  void selectMode(RoutePlanMode mode) {
    if (_closing || state.starting || state.recording || state.mode == mode) {
      return;
    }
    cancelGeneration();
    emit(
      state.copyWith(
        mode: mode,
        clearPlan: true,
        newAreas: 0,
        clearError: true,
        clearLocationError: true,
      ),
    );
  }

  void selectStart(GeoPoint? point) {
    if (_closing ||
        state.starting ||
        state.recording ||
        (point != null && !point.isValid)) {
      return;
    }
    cancelGeneration();
    emit(
      state.copyWith(
        start: point,
        clearStart: point == null,
        clearPlan: true,
        newAreas: 0,
        clearError: true,
        clearLocationError: true,
      ),
    );
  }

  void selectEnd(GeoPoint? point) {
    if (_closing ||
        state.starting ||
        state.recording ||
        (point != null && !point.isValid)) {
      return;
    }
    cancelGeneration();
    emit(
      state.copyWith(
        end: point,
        clearEnd: point == null,
        clearPlan: true,
        newAreas: 0,
        clearError: true,
      ),
    );
  }

  void swapEndpoints() {
    if (_closing ||
        state.starting ||
        state.recording ||
        state.mode != RoutePlanMode.pointToPoint ||
        state.start == null ||
        state.end == null) {
      return;
    }
    cancelGeneration();
    emit(
      state.copyWith(
        start: state.end,
        end: state.start,
        clearPlan: true,
        newAreas: 0,
        clearError: true,
      ),
    );
  }

  bool _usable(LocationDM? point) {
    if (point == null || !ExplorationRules.usable(point)) return false;
    final age = _now().difference(point.timestamp);
    return age >= const Duration(seconds: -5) &&
        age <= const Duration(seconds: 30);
  }

  Future<LocationDM?> _readyLocation() async {
    final cached = _recording.state.location;
    if (_recording.state.locationError == null && _usable(cached)) {
      return cached;
    }
    final cancellation = Completer<LocationDM?>();
    _locationRequest = cancellation;
    emit(state.copyWith(locating: true, clearLocationError: true));
    try {
      final location = await Future.any<LocationDM?>([
        _recording.refreshPreviewLocation(),
        cancellation.future,
      ]);
      if (_closing || cancellation.isCompleted) return null;
      if (!_usable(location)) {
        emit(
          state.copyWith(
            locationError: 'Could not get an accurate, recent GPS location. Move to an open area and try again.',
          ),
        );
        return null;
      }
      return location;
    } on Object catch (error, stack) {
      if (_closing || cancellation.isCompleted) return null;
      addError(error, stack);
      emit(state.copyWith(locationError: _locationMessage(error)));
      return null;
    } finally {
      if (identical(_locationRequest, cancellation)) {
        _locationRequest = null;
        if (!_closing) emit(state.copyWith(locating: false));
      }
    }
  }

  static String _locationMessage(Object error) => switch (error) {
    LocationServiceDisabledStateException() => 'Location services are off. Enable them in device settings and try again.',
    LocationServicePermanentlyDeniedException() =>
      'Allow location access for Footprint in device settings, then try again.',
    LocationServicePermissionDeniedException() =>
      'Location permission is required. Allow access and try again.',
    TimeoutException() =>
      'GPS did not respond in time. Move to an open area and try again.',
    _ => 'Location is unavailable. Please try again.',
  };

  Future<void> generate() async {
    if (_closing || state.generating || state.starting || state.recording) {
      return;
    }
    if (!_planner.available) {
      emit(state.copyWith(error: 'Route planning is not configured.'));
      return;
    }
    final loop = state.mode == RoutePlanMode.loop;
    final end = state.end;
    if (!loop && end == null) {
      emit(state.copyWith(error: 'Choose a destination on the map.'));
      return;
    }
    final request = ++_generation;
    emit(
      state.copyWith(
        generating: true,
        clearPlan: true,
        clearError: true,
        clearLocationError: true,
      ),
    );
    try {
      final manualStart = loop ? null : state.start;
      final location = manualStart == null ? await _readyLocation() : null;
      if (_closing || request != _generation) return;
      if ((manualStart == null && location == null) ||
          _recording.state.isRecording) {
        emit(state.copyWith(generating: false));
        return;
      }
      final start =
          manualStart ?? GeoPoint(location!.latitude, location.longitude);
      final latitudeRadius = (loop ? state.distance : 20000) / 111000;
      final longitudeRadius =
          (latitudeRadius /
                  math.cos(start.latitude * math.pi / 180).abs().clamp(0.01, 1))
              .clamp(0.0, 180.0);
      double wrap(double longitude) => (longitude + 180) % 360 - 180;
      final cells = await _walks.getCells(
        south: (start.latitude - latitudeRadius).clamp(-90, 90),
        north: (start.latitude + latitudeRadius).clamp(-90, 90),
        west: wrap(start.longitude - longitudeRadius),
        east: wrap(start.longitude + longitudeRadius),
      );
      if (_closing || request != _generation) return;
      final known = cells.map((c) => c.id).toSet();
      final plan = loop
          ? await _planner.generate(
              start: start,
              distance: state.distance,
              exploredCells: known,
            )
          : await _planner.generateBetween(start: start, end: end!);
      if (_closing || request != _generation) return;
      final newAreas = plan.explorationSamples
          .map(ExplorationCell.at)
          .map((c) => c.id)
          .toSet()
          .difference(known)
          .length;
      emit(state.copyWith(plan: plan, newAreas: newAreas, generating: false));
    } on PlanningCancelled {
      if (!_closing && request == _generation) {
        emit(state.copyWith(generating: false));
      }
    } on Object catch (error, stack) {
      if (_closing || request != _generation) return;
      addError(error, stack);
      emit(
        state.copyWith(
          generating: false,
          error: error is RoutePlanningException
              ? error.message
              : 'A route could not be prepared. Please try again.',
        ),
      );
    }
  }

  void cancelGeneration() {
    _generation++;
    _planner.cancel();
    _locationRequest?.complete(null);
    _locationRequest = null;
    if (!_closing) emit(state.copyWith(generating: false, locating: false));
  }

  void clearPlan() {
    if (_closing || state.starting || state.recording) return;
    cancelGeneration();
    emit(state.copyWith(clearPlan: true, newAreas: 0, clearError: true));
  }

  Future<void> start() async {
    final plan = state.plan;
    if (_closing ||
        state.starting ||
        state.generating ||
        state.recording ||
        plan == null) {
      return;
    }
    emit(
      state.copyWith(
        starting: true,
        clearError: true,
        clearLocationError: true,
      ),
    );
    final location = await _readyLocation();
    if (_closing) return;
    if (location == null || _recording.state.isRecording) {
      emit(state.copyWith(starting: false));
      return;
    }
    if (GeoPoint(
          location.latitude,
          location.longitude,
        ).distanceTo(plan.points.first) >
        100) {
      emit(
        state.copyWith(
          starting: false,
          error: plan.isLoop
              ? 'The start is no longer nearby. Generate a new route.'
              : 'Go to the route start before starting this walk.',
        ),
      );
      return;
    }
    await _recording.start(plan: plan);
    if (_closing) return;
    final recording = _recording.state;
    if (recording.failure != null || recording.routeId == null) {
      emit(
        state.copyWith(
          starting: false,
          error: 'Recording could not be started. Return to the map to retry.',
        ),
      );
    } else {
      emit(state.copyWith(starting: false, startedRouteId: recording.routeId));
    }
  }

  void loadCells({
    required double south,
    required double north,
    required double west,
    required double east,
  }) {
    if (_closing) return;
    _viewportTimer?.cancel();
    final request = ++_viewportRequest;
    _viewportTimer = Timer(const Duration(milliseconds: 250), () async {
      try {
        final cells = await _walks.getCells(
          south: south,
          north: north,
          west: west,
          east: east,
        );
        if (!_closing && request == _viewportRequest) {
          emit(state.copyWith(cells: cells));
        }
      } on Object catch (error, stack) {
        if (!_closing && request == _viewportRequest) {
          addError(error, stack);
          emit(state.copyWith(error: 'Explored areas could not be loaded.'));
        }
      }
    });
  }

  @override
  Future<void> close() async {
    if (_closing) return;
    _closing = true;
    cancelGeneration();
    _viewportTimer?.cancel();
    await _subscription?.cancel();
    if (_attached) await _recording.detachPreview();
    await super.close();
  }
}

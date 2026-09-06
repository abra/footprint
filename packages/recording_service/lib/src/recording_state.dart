import 'package:domain_models/domain_models.dart';

enum RecordingPhase { idle, starting, recording, stopping }

enum RecordingOperation { restore, start, savePoint, stop }

class RecordingFailure {
  const RecordingFailure(this.operation, this.error, this.stackTrace);
  final RecordingOperation operation;
  final Object error;
  final StackTrace stackTrace;
}

class RecordingState {
  const RecordingState({
    this.phase = RecordingPhase.idle,
    this.routeId,
    this.location,
    this.points = const [],
    this.failure,
    this.locationError,
    this.foreground = true,
  });

  final RecordingPhase phase;
  final int? routeId;
  final LocationDM? location;
  final List<LocationDM> points;
  final RecordingFailure? failure;
  final Object? locationError;
  final bool foreground;

  bool get isRecording => phase != RecordingPhase.idle;
  bool get isBusy =>
      failure == null &&
      (phase == RecordingPhase.starting || phase == RecordingPhase.stopping);

  RecordingState copyWith({
    RecordingPhase? phase,
    int? routeId,
    bool clearRoute = false,
    LocationDM? location,
    List<LocationDM>? points,
    RecordingFailure? failure,
    bool clearFailure = false,
    Object? locationError,
    bool clearLocationError = false,
    bool? foreground,
  }) => RecordingState(
    phase: phase ?? this.phase,
    routeId: clearRoute ? null : routeId ?? this.routeId,
    location: location ?? this.location,
    points: points == null ? this.points : List.unmodifiable(points),
    failure: clearFailure ? null : failure ?? this.failure,
    locationError: clearLocationError
        ? null
        : locationError ?? this.locationError,
    foreground: foreground ?? this.foreground,
  );
}

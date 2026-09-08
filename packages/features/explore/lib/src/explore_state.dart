import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

class ExploreState extends Equatable {
  const ExploreState({
    this.location,
    this.distance = 3000,
    this.mode = RoutePlanMode.loop,
    this.start,
    this.end,
    this.plan,
    this.previousPreview,
    this.hasRecentLocation = false,
    this.generating = false,
    this.locating = false,
    this.starting = false,
    this.recording = false,
    this.error,
    this.locationError,
    this.profile = const ExplorationProfile(),
    this.cells = const [],
    this.newAreas = 0,
    this.showProgress = false,
    this.startedRouteId,
  });
  final LocationDM? location;
  final double distance;
  final RoutePlanMode mode;

  /// Null starts from the current GPS fix; manual points remain fixed.
  final GeoPoint? start;
  final GeoPoint? end;
  final RoutePlan? plan;
  final ({RoutePlan plan, int newAreas})? previousPreview;
  final bool hasRecentLocation;
  static const startRadiusMeters = 100.0;

  double? get distanceToStart {
    final point = location;
    final route = plan;
    if (!hasRecentLocation ||
        locationError != null ||
        point == null ||
        route == null) {
      return null;
    }
    return GeoPoint(
      point.latitude,
      point.longitude,
    ).distanceTo(route.points.first);
  }

  bool get startTooFar => (distanceToStart ?? 0) > startRadiusMeters;
  final bool generating;
  final bool locating;
  final bool starting;
  final bool recording;
  final String? error;
  final String? locationError;
  String? get visibleError => error ?? locationError;
  final ExplorationProfile profile;
  final List<ExplorationCell> cells;
  final int newAreas;
  final bool showProgress;
  final int? startedRouteId;

  ExploreState copyWith({
    LocationDM? location,
    double? distance,
    RoutePlanMode? mode,
    GeoPoint? start,
    bool clearStart = false,
    GeoPoint? end,
    bool clearEnd = false,
    RoutePlan? plan,
    bool clearPlan = false,
    ({RoutePlan plan, int newAreas})? previousPreview,
    bool clearPreviousPreview = false,
    bool? hasRecentLocation,
    bool? generating,
    bool? locating,
    bool? starting,
    bool? recording,
    String? error,
    bool clearError = false,
    String? locationError,
    bool clearLocationError = false,
    ExplorationProfile? profile,
    List<ExplorationCell>? cells,
    int? newAreas,
    bool? showProgress,
    int? startedRouteId,
  }) => ExploreState(
    location: location ?? this.location,
    distance: distance ?? this.distance,
    mode: mode ?? this.mode,
    start: clearStart ? null : start ?? this.start,
    end: clearEnd ? null : end ?? this.end,
    plan: clearPlan ? null : plan ?? this.plan,
    previousPreview: clearPlan || clearPreviousPreview
        ? null
        : previousPreview ?? this.previousPreview,
    hasRecentLocation: hasRecentLocation ?? this.hasRecentLocation,
    generating: generating ?? this.generating,
    locating: locating ?? this.locating,
    starting: starting ?? this.starting,
    recording: recording ?? this.recording,
    error: clearError ? null : error ?? this.error,
    locationError: clearLocationError
        ? null
        : locationError ?? this.locationError,
    profile: profile ?? this.profile,
    cells: cells == null ? this.cells : List.unmodifiable(cells),
    newAreas: newAreas ?? this.newAreas,
    showProgress: showProgress ?? this.showProgress,
    startedRouteId: startedRouteId ?? this.startedRouteId,
  );

  @override
  List<Object?> get props => [
    location,
    distance,
    mode,
    start,
    end,
    plan,
    previousPreview,
    hasRecentLocation,
    generating,
    locating,
    starting,
    recording,
    error,
    locationError,
    profile,
    cells,
    newAreas,
    showProgress,
    startedRouteId,
  ];
}

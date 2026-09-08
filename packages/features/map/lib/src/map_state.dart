import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

enum RecordingAction { start, stop }

enum MapOrientation { northUp, courseUp }

class MapState extends Equatable {
  const MapState({
    this.location,
    this.locationLoading = true,
    this.address = 'Locating...',
    this.points = const [],
    this.isRecording = false,
    this.recordingAction,
    this.centered = true,
    this.orientation = MapOrientation.northUp,
    this.error,
    this.tileError = false,
    this.tileGeneration = 0,
    this.routeId,
    this.completedRouteId,
    this.lastRouteHidden = false,
    this.metrics = const RouteMetrics(),
    this.statsExpanded = false,
    this.photos = const [],
    this.photoBusy = false,
    this.photoError,
    this.walk,
    this.walkError,
  });

  final LocationDM? location;
  final bool locationLoading;
  final String address;
  final List<LocationDM> points;
  final bool isRecording;
  final RecordingAction? recordingAction;
  bool get recordingBusy => recordingAction != null;
  final bool centered;
  final MapOrientation orientation;

  String get followActionLabel => !centered
      ? 'Center on location'
      : orientation == MapOrientation.northUp
      ? 'Follow direction of travel'
      : 'Keep north up';
  final String? error;
  final bool tileError;
  final int tileGeneration;
  final int? routeId;
  final int? completedRouteId;
  final bool lastRouteHidden;
  bool get showsLastRoute =>
      !isRecording &&
      !lastRouteHidden &&
      points.any((point) => point.hasValidCoordinates);
  bool get showsRoute => isRecording || showsLastRoute;
  final RouteMetrics metrics;
  final bool statsExpanded;
  final List<RoutePhotoDM> photos;
  final bool photoBusy;
  final String? photoError;
  final WalkProgress? walk;
  final String? walkError;

  MapState copyWith({
    LocationDM? location,
    bool? locationLoading,
    String? address,
    List<LocationDM>? points,
    bool? isRecording,
    RecordingAction? recordingAction,
    bool clearRecordingAction = false,
    bool? centered,
    MapOrientation? orientation,
    String? error,
    bool clearError = false,
    bool? tileError,
    int? tileGeneration,
    int? routeId,
    bool clearRoute = false,
    int? completedRouteId,
    bool? lastRouteHidden,
    RouteMetrics? metrics,
    bool? statsExpanded,
    List<RoutePhotoDM>? photos,
    bool? photoBusy,
    String? photoError,
    bool clearPhotoError = false,
    WalkProgress? walk,
    bool clearWalk = false,
    String? walkError,
    bool clearWalkError = false,
  }) => MapState(
    location: location ?? this.location,
    locationLoading: locationLoading ?? this.locationLoading,
    address: address ?? this.address,
    points: points == null ? this.points : List.unmodifiable(points),
    isRecording: isRecording ?? this.isRecording,
    recordingAction: clearRecordingAction
        ? null
        : recordingAction ?? this.recordingAction,
    centered: centered ?? this.centered,
    orientation: orientation ?? this.orientation,
    error: clearError ? null : error ?? this.error,
    tileError: tileError ?? this.tileError,
    tileGeneration: tileGeneration ?? this.tileGeneration,
    routeId: clearRoute ? null : routeId ?? this.routeId,
    completedRouteId: completedRouteId ?? this.completedRouteId,
    lastRouteHidden: lastRouteHidden ?? this.lastRouteHidden,
    metrics: metrics ?? this.metrics,
    statsExpanded: statsExpanded ?? this.statsExpanded,
    photos: photos == null ? this.photos : List.unmodifiable(photos),
    photoBusy: photoBusy ?? this.photoBusy,
    photoError: clearPhotoError ? null : photoError ?? this.photoError,
    walk: clearWalk ? null : walk ?? this.walk,
    walkError: clearWalkError ? null : walkError ?? this.walkError,
  );

  @override
  List<Object?> get props => [
    location,
    locationLoading,
    address,
    points,
    isRecording,
    recordingAction,
    centered,
    orientation,
    error,
    tileError,
    tileGeneration,
    routeId,
    completedRouteId,
    lastRouteHidden,
    metrics,
    statsExpanded,
    photos,
    photoBusy,
    photoError,
    walk,
    walkError,
  ];
}

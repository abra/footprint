import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

enum RecordingAction { start, stop }

class MapState extends Equatable {
  const MapState({
    this.location,
    this.locationLoading = true,
    this.address = 'Locating...',
    this.points = const [],
    this.isRecording = false,
    this.recordingAction,
    this.centered = true,
    this.error,
    this.tileError = false,
    this.tileGeneration = 0,
    this.routeId,
    this.completedRouteId,
    this.metrics = const RouteMetrics(),
    this.statsExpanded = false,
    this.photos = const [],
    this.photoBusy = false,
    this.photoError,
  });

  final LocationDM? location;
  final bool locationLoading;
  final String address;
  final List<LocationDM> points;
  final bool isRecording;
  final RecordingAction? recordingAction;
  bool get recordingBusy => recordingAction != null;
  final bool centered;
  final String? error;
  final bool tileError;
  final int tileGeneration;
  final int? routeId;
  final int? completedRouteId;
  final RouteMetrics metrics;
  final bool statsExpanded;
  final List<RoutePhotoDM> photos;
  final bool photoBusy;
  final String? photoError;

  MapState copyWith({
    LocationDM? location,
    bool? locationLoading,
    String? address,
    List<LocationDM>? points,
    bool? isRecording,
    RecordingAction? recordingAction,
    bool clearRecordingAction = false,
    bool? centered,
    String? error,
    bool clearError = false,
    bool? tileError,
    int? tileGeneration,
    int? routeId,
    bool clearRoute = false,
    int? completedRouteId,
    RouteMetrics? metrics,
    bool? statsExpanded,
    List<RoutePhotoDM>? photos,
    bool? photoBusy,
    String? photoError,
    bool clearPhotoError = false,
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
    error: clearError ? null : error ?? this.error,
    tileError: tileError ?? this.tileError,
    tileGeneration: tileGeneration ?? this.tileGeneration,
    routeId: clearRoute ? null : routeId ?? this.routeId,
    completedRouteId: completedRouteId ?? this.completedRouteId,
    metrics: metrics ?? this.metrics,
    statsExpanded: statsExpanded ?? this.statsExpanded,
    photos: photos == null ? this.photos : List.unmodifiable(photos),
    photoBusy: photoBusy ?? this.photoBusy,
    photoError: clearPhotoError ? null : photoError ?? this.photoError,
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
    error,
    tileError,
    tileGeneration,
    routeId,
    completedRouteId,
    metrics,
    statsExpanded,
    photos,
    photoBusy,
    photoError,
  ];
}

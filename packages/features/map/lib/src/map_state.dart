import 'package:domain_models/domain_models.dart';
import 'package:equatable/equatable.dart';

class MapState extends Equatable {
  const MapState({
    this.location,
    this.locationLoading = true,
    this.address = 'Locating...',
    this.points = const [],
    this.isRecording = false,
    this.recordingBusy = false,
    this.centered = true,
    this.error,
    this.tileError = false,
    this.tileGeneration = 0,
  });

  final LocationDM? location;
  final bool locationLoading;
  final String address;
  final List<LocationDM> points;
  final bool isRecording;
  final bool recordingBusy;
  final bool centered;
  final String? error;
  final bool tileError;
  final int tileGeneration;

  MapState copyWith({
    LocationDM? location,
    bool? locationLoading,
    String? address,
    List<LocationDM>? points,
    bool? isRecording,
    bool? recordingBusy,
    bool? centered,
    String? error,
    bool clearError = false,
    bool? tileError,
    int? tileGeneration,
  }) => MapState(
    location: location ?? this.location,
    locationLoading: locationLoading ?? this.locationLoading,
    address: address ?? this.address,
    points: points == null ? this.points : List.unmodifiable(points),
    isRecording: isRecording ?? this.isRecording,
    recordingBusy: recordingBusy ?? this.recordingBusy,
    centered: centered ?? this.centered,
    error: clearError ? null : error ?? this.error,
    tileError: tileError ?? this.tileError,
    tileGeneration: tileGeneration ?? this.tileGeneration,
  );

  @override
  List<Object?> get props => [
    location,
    locationLoading,
    address,
    points,
    isRecording,
    recordingBusy,
    centered,
    error,
    tileError,
    tileGeneration,
  ];
}

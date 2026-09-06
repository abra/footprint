import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:recording_service/recording_service.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'map_cubit.dart';
import 'map_view.dart';

class MapScreen extends StatelessWidget {
  const MapScreen({
    super.key,
    required this.recordingService,
    required this.photosRepository,
    required this.geocodingManager,
    required this.onPageChangeRequested,
    this.config = const MapConfig(),
    this.onRouteCompleted,
  });

  final RecordingService recordingService;
  final RoutePhotosRepository photosRepository;
  final GeocodingManager geocodingManager;
  final VoidCallback onPageChangeRequested;
  final MapConfig config;
  final ValueChanged<int>? onRouteCompleted;

  @override
  Widget build(BuildContext context) => BlocProvider(
    create: (_) => MapCubit(
      recordingService: recordingService,
      photosRepository: photosRepository,
      geocodingManager: geocodingManager,
    )..initialize(),
    child: MapView(
      config: config,
      onRoutesRequested: onPageChangeRequested,
      onRouteCompleted: onRouteCompleted,
    ),
  );
}

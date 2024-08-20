import 'package:flutter/material.dart';
import 'package:foreground_task_service/foreground_task_service.dart';
import 'package:geocoding_repository/geocoding_repository.dart';
import 'package:location_repository/location_repository.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'map_app_bar.dart';
import 'map_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.routesRepository,
    required this.geocodingRepository,
    required this.onPageChangeRequested,
  });

  final LocationRepository locationRepository;
  final RoutesRepository routesRepository;
  final GeocodingRepository geocodingRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapNotifier _mapNotifier;
  late ForegroundTaskService _foregroundTaskService;
  late final AppLifecycleListener _listener;

  @override
  void initState() {
    super.initState();
    _mapNotifier = MapNotifier(
      locationRepository: widget.locationRepository,
      routesRepository: widget.routesRepository,
      geocodingRepository: widget.geocodingRepository,
      viewConfig: const Config(),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _foregroundTaskService = context.foregroundTaskService;
    });

    _listener = AppLifecycleListener(
      onDetach: _onDetach,
      onHide: _onHide,
      onInactive: _onInactive,
      onPause: _onPause,
      onRestart: _onRestart,
      onResume: _onResume,
      onShow: _onShow,
      onStateChange: _onStateChange,
    );
  }

  @override
  void dispose() {
    _listener.dispose();
    _mapNotifier.dispose();
    super.dispose();
  }

  void _onDetach() => print('onDetach');

  void _onHide() => print('onHide');

  void _onInactive() => print('onInactive');

  void _onPause() => print('onPause');

  void _onRestart() => print('onRestart');

  void _onResume() => print('onResume');

  void _onShow() => print('onShow');

  void _onStateChange(AppLifecycleState state) =>
      print('onStateChange: $state');

  @override
  Widget build(BuildContext context) => MapNotifierProvider(
        notifier: _mapNotifier,
        child: Scaffold(
          extendBodyBehindAppBar: true,
          appBar: MapAppBar(
            onPageChange: widget.onPageChangeRequested,
          ),
          body: const MapView(),
        ),
      );
}

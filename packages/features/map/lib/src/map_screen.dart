import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:geocoding_manager/geocoding_manager.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'map_app_bar.dart';
import 'map_notifier.dart';
import 'map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationService,
    required this.routesRepository,
    required this.geocodingManager,
    required this.onPageChangeRequested,
  });

  final ForegroundLocationService locationService;
  final RoutesRepository routesRepository;
  final GeocodingManager geocodingManager;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapNotifier _mapNotifier;

  late final AppLifecycleListener _listener;

  @override
  void initState() {
    log('initState', name: '$this', time: DateTime.now());
    super.initState();
    _mapNotifier = MapNotifier(
      locationService: widget.locationService,
      routesRepository: widget.routesRepository,
      geocodingManager: widget.geocodingManager,
      viewConfig: const Config(),
    );
    _mapNotifier.init();
    widget.locationService.attach(this);
    _listener = AppLifecycleListener(
      onDetach: _onDetach,
    );
    // onHide: _onHide,
    // onInactive: _onInactive,
    // onPause: _onPause,
    // onRestart: _onRestart,
    // onResume: _onResume,
    // onShow: _onShow,
    // onStateChange: _onStateChange,
    // onExitRequested: _onExitRequested,
    // );
  }

  void _onDetach() {
    widget.locationService.detach();
  }

  @override
  void dispose() {
    log('dispose', name: '$this', time: DateTime.now());
    _listener.dispose();
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('build', name: '$this', time: DateTime.now());
    return MapNotifierProvider(
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
}

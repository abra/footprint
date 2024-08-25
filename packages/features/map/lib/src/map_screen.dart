import 'package:flutter/material.dart';
import 'package:geocoding_repository/geocoding_repository.dart';
import 'package:location_service/location_service.dart';
import 'package:routes_repository/routes_repository.dart';

import 'config.dart';
import 'map_app_bar.dart';
import 'map_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationService,
    required this.routesRepository,
    required this.geocodingRepository,
    required this.onPageChangeRequested,
  });

  final LocationService locationService;
  final RoutesRepository routesRepository;
  final GeocodingRepository geocodingRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapNotifier _mapNotifier;
  // late ForegroundLocationTaskService _foregroundLocationTaskService;
  late final AppLifecycleListener _listener;

  Future<void> _checkPermissionsAndInitialize() async {
    await _mapNotifier.ensurePermissions();
    await _mapNotifier.initLocationUpdate();
    // await _foregroundLocationTaskService.requestPermissions();
    // await _foregroundLocationTaskService.initTaskService();
  }

  @override
  void initState() {
    super.initState();
    _mapNotifier = MapNotifier(
      locationService: widget.locationService,
      routesRepository: widget.routesRepository,
      geocodingRepository: widget.geocodingRepository,
      viewConfig: const Config(),
    );
    // _foregroundTaskService.initTaskService(this);
    _checkPermissionsAndInitialize();
    // _foregroundTaskService.addTaskDataCallback(_onReceiveTaskData);
    // _mapNotifier.foregroundTaskCallback = (String data) {
    //   _foregroundTaskService.sendDataToTask(data);
    // };
    // _listener = AppLifecycleListener(
    // onDetach: _onDetach,
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

  @override
  void dispose() {
    _listener.dispose();
    // _foregroundTaskService.removeTaskDataCallback(_onReceiveTaskData);
    // _foregroundTaskService.stopService();
    _mapNotifier.dispose();
    super.dispose();
  }

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

  // Future<void> _onDetach() async {
  //   print('onDetach 1');
  //   await _foregroundTaskService.stopService();
  //   print('onDetach 2');
  // }

  // void _onHide() async {
  //   print('onHide');
  //   if (_isFirstBuild) {
  //     _isFirstBuild = false;
  //     return;
  //   }
  //   // if (!await _foregroundTaskService.isRunningService()) {
  //   await _foregroundTaskService.startService();
  //   // }
  //   print('IS RUNNING: ${await _foregroundTaskService.isRunningService()}');
  // }

  void _onReceiveTaskData(dynamic data) {
    if (data is int) {
      print('### count: $data');
    }
  }

// void _onInactive() async {
//   print('onInactive');
//   if (_isFirstBuild) {
//     _isFirstBuild = false;
//     return;
//   }
//   // if (!await _foregroundTaskService.isRunningService()) {
//   await _foregroundTaskService.startService();
//   // }
// }

// void _onPause() async {
//   print('onPause');
//   // if (_isFirstBuild) {
//   //   _isFirstBuild = false;
//   //   return;
//   // }
//   // if (!await _foregroundTaskService.isRunningService()) {
//   await _foregroundTaskService.startService();
//   // }
// }

// void _onRestart() {
//   print('onRestart');
// }

// void _onResume() async {
//   print('onResume');
//   await _foregroundTaskService.stopService();
// }

// void _onShow() async {
//   print('onShow');
//   await _foregroundTaskService.stopService();
// }

// void _onStateChange(AppLifecycleState state) =>
//     print('onStateChange: $state');
}

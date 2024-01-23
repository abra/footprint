import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'extensions.dart';
import 'map_config.dart';
import 'map_location_notifier.dart';
import 'map_view_notifier.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.locationNotifier,
  });

  final MapLocationNotifier locationNotifier;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  late final MapLocationNotifier _locationNotifier;
  final MapViewNotifier _viewNotifier = MapViewNotifier(
    shouldCenterMap: MapConfig.shouldCenterMap,
    zoom: MapConfig.defaultZoom,
    maxZoom: MapConfig.maxZoom,
    minZoom: MapConfig.minZoom,
  );

  @override
  void initState() {
    super.initState();

    _locationNotifier = widget.locationNotifier;
    _locationNotifier.init();

    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );

    _viewNotifier.addListener(_handleZoomChanged);
    _locationNotifier.addListener(_handleMapLocationChanged);
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _viewNotifier.removeListener(_handleZoomChanged);
    _viewNotifier.dispose();
    _locationNotifier.removeListener(_handleMapLocationChanged);
    _locationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>> build $runtimeType');
    super.build(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _animatedMapController.mapController,
          options: const MapOptions(
            interactionOptions: InteractionOptions(
              pinchZoomWinGestures: InteractiveFlag.pinchZoom,
            ),
            initialZoom: MapConfig.defaultZoom,
            maxZoom: MapConfig.maxZoom,
            minZoom: MapConfig.minZoom,
          ),
          children: [
            TileLayer(
              retinaMode: true,
              userAgentPackageName: MapConfig.userAgentPackageName,
              urlTemplate: MapConfig.urlTemplate,
              fallbackUrl: MapConfig.fallbackUrl,
              subdomains: const ['a', 'b', 'c'],
              maxZoom: MapConfig.maxZoom,
              minZoom: MapConfig.minZoom,
            ),
            ValueListenableBuilder<MapLocationState>(
              valueListenable: _locationNotifier,
              builder: (BuildContext context, MapLocationState state, _) {
                // TODO: Replace
                if (state is MapLocationUpdateSuccess) {
                  // if (state.locationUpdateError != null) {
                  //   WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
                  //     ScaffoldMessenger.of(context).showSnackBar(
                  //       SnackBar(
                  //         content:
                  //             Text('${state.locationUpdateError ?? 'ERROR'}!'),
                  //       ),
                  //     );
                  //   });
                  // }
                  return MarkerLayer(
                    markers: [
                      Marker(
                        width: 30.0,
                        height: 30.0,
                        point: state.location.toLatLng(),
                        child: const Icon(
                          Icons.circle,
                          size: 20.0,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  );
                } else if (state is MapLocationServiceDisabled) {
                  log('${state.runtimeType}');
                  return const Center(
                    child: Text('Service disabled'),
                  );
                } else if (state is MapLocationServicePermissionDenied) {
                  log('${state.runtimeType}');
                  return const Center(
                    child: Text('Permission denied'),
                  );
                } else if (state
                    is MapLocationServicePermissionPermanentlyDenied) {
                  log('${state.runtimeType}');
                  return const Center(
                    child: Text('Permission Permanently denied'),
                  );
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ],
        ),
        Positioned(
          right: 0,
          left: 0,
          bottom: 20,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // TODO: For debugging
              IconButton(
                  icon: const Icon(
                    Icons.zoom_in,
                  ),
                  onPressed: () {
                    _viewNotifier.handleZoomedIn(MapConfig.zoomStep);
                  }),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _viewNotifier,
                builder: (BuildContext context, MapViewState state, _) {
                  if (state is MapViewUpdated) {
                    return Text(
                      '${state.zoom}',
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _viewNotifier,
                builder: (BuildContext context, MapViewState state, _) {
                  if (state is MapViewUpdated) {
                    return Switch(
                      value: state.shouldCenterMap,
                      onChanged: _handleToggleButtonSwitched,
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ElevatedButton(
                onPressed: () {
                  _locationNotifier.init();
                },
                child: const Text('Start'),
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    _viewNotifier.handleZoomedOut(MapConfig.zoomStep);
                  }),
            ],
          ),
        ),
      ],
    );
  }

  void _handleZoomChanged() {
    final mapViewState = _viewNotifier.value;
    if (mapViewState is MapViewUpdated) {
      _animatedMapController.animatedZoomTo(mapViewState.zoom);
    }
  }

  void _handleMapLocationChanged() {
    final mapViewState = _viewNotifier.value as MapViewUpdated;
    if (mapViewState.shouldCenterMap) {
      _moveToOnLocationUpdateSuccess();
    }
  }

  void _handleToggleButtonSwitched(bool value) {
    _viewNotifier.handleCenterMap(value);
    _moveToOnLocationUpdateSuccess();
  }

  void _moveToOnLocationUpdateSuccess() {
    final mapLocationState = _locationNotifier.value;
    if (mapLocationState is MapLocationUpdateSuccess) {
      _animatedMapController.animateTo(
        dest: mapLocationState.location.toLatLng(),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}

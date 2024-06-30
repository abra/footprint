import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';

import 'extensions.dart';
import 'map_location_notifier.dart';
import 'map_view_config.dart';
import 'map_view_notifier.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.config,
  });

  final MapViewConfig config;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final MapViewConfig _config;
  late final AnimatedMapController _animatedMapController;
  late final MapViewNotifier _mapViewNotifier;
  late MapLocationNotifier _mapLocationNotifier;

  final _isRouteRecordingStarted = ValueNotifier<bool>(false);
  final _routePoints = ValueNotifier<List<LatLng>>([]); // <>

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _mapViewNotifier = MapViewNotifier(config: _config);
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = context.locationNotifier;
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
    _mapViewNotifier.addListener(_handleZoomChanged);
    _isRouteRecordingStarted.addListener(() {
      if (_isRouteRecordingStarted.value) {
        _mapLocationNotifier.addListener(_handleRecordRoutePoints);
      } else {
        _routePoints.value.clear();
        _mapLocationNotifier.removeListener(_handleRecordRoutePoints);
      }
    });
  }

  @override
  void dispose() {
    _mapViewNotifier.removeListener(_handleZoomChanged);
    _mapViewNotifier.dispose();
    _mapLocationNotifier.removeListener(_handleMapLocationChanged);
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>> build $runtimeType $hashCode');
    super.build(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _animatedMapController.mapController,
          options: MapOptions(
            interactionOptions: const InteractionOptions(
              pinchZoomWinGestures: InteractiveFlag.pinchZoom,
            ),
            initialZoom: _config.defaultZoom,
            maxZoom: _config.maxZoom,
            minZoom: _config.minZoom,
          ),
          children: [
            ValueListenableBuilder<MapViewState>(
              valueListenable: _mapViewNotifier,
              builder: (BuildContext context, MapViewState state, _) =>
                  switch (state) {
                MapViewState() => TileLayer(
                    retinaMode: true,
                    userAgentPackageName: state.userAgentPackageName,
                    urlTemplate: state.urlTemplate,
                    fallbackUrl: state.fallbackUrl,
                    subdomains: const ['a', 'b', 'c'],
                    maxZoom: state.maxZoom,
                    minZoom: state.minZoom,
                  ),
              },
            ),
            // define typedef for builder with convenient type
            ValueListenableBuilder<List<LatLng>>(
              valueListenable: _routePoints,
              builder: (BuildContext context, List<LatLng> points, _) {
                return ValueListenableBuilder<MapViewState>(
                  valueListenable: _mapViewNotifier,
                  builder: (BuildContext context, MapViewState viewState, _) {
                    return PolylineLayer(
                      polylines: <Polyline>[
                        Polyline(
                          points: points,
                          color: context.appColors.lightPurple,
                          strokeWidth: viewState.polylineStrokeWidth,
                          // double _routeLineWidth = ((11 * defaultZoom - 126) / 4) / 2.5;
                          // borderStrokeWidth: 2,
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            ValueListenableBuilder<MapLocationState>(
              valueListenable: _mapLocationNotifier,
              builder: (BuildContext ctx, MapLocationState locationState, _) {
                return switch (locationState) {
                  MapLocationUpdateSuccess(location: final location) =>
                    ValueListenableBuilder<MapViewState>(
                      valueListenable: _mapViewNotifier,
                      builder: (BuildContext ctx, MapViewState viewState, _) {
                        return switch (viewState) {
                          MapViewState(markerSize: final markerSize) =>
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: markerSize,
                                  height: markerSize,
                                  point: location.toLatLng(),
                                  child: Icon(
                                    Icons.circle,
                                    size: markerSize,
                                    color: Colors.deepPurple.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                        };
                      },
                    ),
                  MapInitialLocationLoading() => const Center(
                      child: CircularProgressIndicator(),
                    ),
                  _ => const SizedBox.shrink(),
                };
              },
            ),
          ],
        ),
        Positioned(
          right: 10,
          top: 0,
          bottom: 0,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // TODO: For debugging
              IconButton(
                icon: const Icon(
                  Icons.zoom_in,
                ),
                onPressed: () {
                  _mapViewNotifier.zoomIn();
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _mapViewNotifier,
                builder: (BuildContext context, MapViewState state, _) => Text(
                  '${state.zoom}',
                ),
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _mapViewNotifier,
                builder: (BuildContext context, MapViewState state, _) =>
                    Switch(
                  value: state.isCentered,
                  onChanged: _handleToggleButtonSwitched,
                ),
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              IconButton(
                icon: const Icon(
                  Icons.zoom_out,
                ),
                onPressed: () {
                  _mapViewNotifier.zoomOut();
                },
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isRouteRecordingStarted,
            builder: (BuildContext context, bool isRecording, _) => Switch(
              value: isRecording,
              onChanged: (value) {
                _isRouteRecordingStarted.value = value;
              },
            ),
          ),
        ),
      ],
    );
  }

  void _handleZoomChanged() {
    final viewState = _mapViewNotifier.value;
    switch (viewState) {
      case MapViewState(zoom: final zoom):
        _animatedMapController.animatedZoomTo(zoom);
        _mapViewNotifier.changeMarkerSize(zoom);
        _mapViewNotifier.changePolylineStrokeWidth(zoom);
    }
  }

  // TODO: Temporary for testing
  void _handleToggleButtonSwitched(bool value) {
    _mapViewNotifier.centerMap(value);

    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess) {
      _centerMapViewToCurrentLocation(locationState.location.toLatLng());
    }
  }

  void _handleMapLocationChanged() {
    final viewState = _mapViewNotifier.value;
    final locationState = _mapLocationNotifier.value;

    final mapViewIsCentered = switch (viewState) {
      MapViewState(isCentered: final isCentered) => isCentered,
    };

    if (locationState is MapLocationUpdateSuccess && mapViewIsCentered) {
      _centerMapViewToCurrentLocation(locationState.location.toLatLng());
    }
  }

  void _centerMapViewToCurrentLocation(LatLng location) {
    _animatedMapController.animateTo(
      dest: location,
    );
  }

  void _handleRecordRoutePoints() {
    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess) {
      _routePoints.value.add(locationState.location.toLatLng());
    }
  }

  @override
  bool get wantKeepAlive => true;
}

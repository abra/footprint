import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/foundation.dart';
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
    _isRouteRecordingStarted.addListener(_handleRouteRecordingStarted);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = context.locationNotifier;
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
    _mapViewNotifier.addListener(_handleZoomChanged);
  }

  @override
  void dispose() {
    _mapViewNotifier.removeListener(_handleZoomChanged);
    _mapLocationNotifier.removeListener(_handleMapLocationChanged);
    _isRouteRecordingStarted.removeListener(_handleRouteRecordingStarted);
    _animatedMapController.dispose();
    _mapViewNotifier.dispose();
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
              builder: (BuildContext context, MapViewState state, _) {
                return switch (state) {
                  MapViewState() => TileLayer(
                      retinaMode: true,
                      userAgentPackageName: state.userAgentPackageName,
                      urlTemplate: state.urlTemplate,
                      fallbackUrl: state.fallbackUrl,
                      subdomains: const ['a', 'b', 'c'],
                      maxZoom: state.maxZoom,
                      minZoom: state.minZoom,
                    ),
                };
              },
            ),
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
                        ),
                      ],
                    );
                  },
                );
              },
            ),
            _LocationMarkerBuilder<MapLocationState, MapViewState>(
              locationNotifier: _mapLocationNotifier,
              viewNotifier: _mapViewNotifier,
              builder: (
                BuildContext context,
                MapLocationState locationState,
                MapViewState viewState,
              ) {
                return switch (locationState) {
                  MapLocationUpdateSuccess(location: final location) =>
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: viewState.markerSize,
                          height: viewState.markerSize,
                          point: location.toLatLng(),
                          child: Icon(
                            Icons.circle,
                            size: viewState.markerSize,
                            color: Colors.deepPurple.withOpacity(0.8),
                          ),
                        ),
                      ],
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
    final zoom = switch (_mapViewNotifier.value) {
      MapViewState(zoom: final zoom) => zoom,
    };

    _animatedMapController.animatedZoomTo(zoom);
    _mapViewNotifier.changeMarkerSize(zoom);
    _mapViewNotifier.changePolylineStrokeWidth(zoom);
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
    final mapViewCentered = switch (_mapViewNotifier.value) {
      MapViewState(isCentered: final isCentered) => isCentered,
    };

    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess && mapViewCentered) {
      _centerMapViewToCurrentLocation(locationState.location.toLatLng());
    }
  }

  void _centerMapViewToCurrentLocation(LatLng location) {
    _animatedMapController.animateTo(
      dest: location,
    );
  }

  void _handleRouteRecordingStarted() {
    if (_isRouteRecordingStarted.value) {
      _mapLocationNotifier.addListener(_handleRecordRoutePoints);
    } else {
      _routePoints.value = [];
      _mapLocationNotifier.removeListener(_handleRecordRoutePoints);
    }
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

class _LocationMarkerBuilder<L extends MapLocationState, V extends MapViewState>
    extends StatelessWidget {
  const _LocationMarkerBuilder({
    super.key,
    required this.locationNotifier,
    required this.viewNotifier,
    required this.builder,
  });

  final ValueListenable<L> locationNotifier;
  final ValueListenable<V> viewNotifier;
  final Widget Function(
    BuildContext context,
    L locationState,
    V viewState,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<L>(
      valueListenable: locationNotifier,
      builder: (_, L locationState, __) {
        return ValueListenableBuilder<V>(
          valueListenable: viewNotifier,
          builder: (BuildContext context, V viewState, __) {
            return builder(context, locationState, viewState);
          },
        );
      },
    );
  }
}

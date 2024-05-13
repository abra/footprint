import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';

import '../app/common/colors.dart';
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

  late final MapViewNotifier _viewNotifier;

  MapLocationNotifier get _mapLocationNotifier => context.locationNotifier;

  final _isRouteRecordingStarted = ValueNotifier<bool>(false);

  final _routePoints = ValueNotifier<List<LatLng>>([]); // <>

  @override
  void initState() {
    super.initState();
    _config = widget.config;
    _viewNotifier = MapViewNotifier(config: _config);
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
    _viewNotifier.addListener(_handleZoomChanged);
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
    _animatedMapController.dispose();
    _viewNotifier.removeListener(_handleZoomChanged);
    _viewNotifier.dispose();
    _mapLocationNotifier.removeListener(_handleMapLocationChanged);
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
              valueListenable: _viewNotifier,
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
                return PolylineLayer(
                  polylines: <Polyline>[
                    Polyline(
                      points: points,
                      color: AppColors.lightPurple,
                      strokeWidth: 4,
                      // double _routeLineWidth = ((11 * defaultZoom - 126) / 4) / 2.5;
                      // borderStrokeWidth: 2,
                    ),
                  ],
                );
              },
            ),
            ValueListenableBuilder<MapLocationState>(
              valueListenable: _mapLocationNotifier,
              builder: (BuildContext context, MapLocationState state, _) {
                return switch (state) {
                  MapLocationUpdateSuccess(location: final location) =>
                    MarkerLayer(
                      markers: [
                        Marker(
                          width: 30.0,
                          height: 30.0,
                          point: location.toLatLng(),
                          child: const Icon(
                            Icons.circle,
                            size: 20.0,
                            color: Colors.deepPurple,
                          ),
                        ),
                      ],
                    ),
                  MapInitialLocationUpdate() => const Center(
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
                  _viewNotifier.zoomIn();
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _viewNotifier,
                builder: (BuildContext context, MapViewState state, _) {
                  return Text(
                    '${state.zoom}',
                  );
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<MapViewState>(
                valueListenable: _viewNotifier,
                builder: (BuildContext context, MapViewState state, _) {
                  return Switch(
                    value: state.isCentered,
                    onChanged: _handleToggleButtonSwitched,
                  );
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              IconButton(
                icon: const Icon(
                  Icons.zoom_out,
                ),
                onPressed: () {
                  _viewNotifier.zoomOut();
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
            builder: (BuildContext context, bool isRecording, _) {
              return Switch(
                value: isRecording,
                onChanged: (value) {
                  _isRouteRecordingStarted.value = value;
                },
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleZoomChanged() {
    switch (_viewNotifier.value) {
      case MapViewState(zoom: final zoom):
        _animatedMapController.animatedZoomTo(zoom);
    }
  }

  // TODO: Temporary for testing
  void _handleToggleButtonSwitched(bool value) {
    _viewNotifier.centerMap(value);
    final isCentered = _viewNotifier.value.isCentered;
    final mapLocation = _mapLocationNotifier.value;
    if (isCentered && mapLocation is MapLocationUpdateSuccess) {
      _centerMapViewToCurrentLocation(mapLocation.location.toLatLng());
    }
  }

  void _handleMapLocationChanged() {
    final mapViewIsCentered = switch (_viewNotifier.value) {
      MapViewState(isCentered: final isCentered) => isCentered,
    };

    switch (_mapLocationNotifier.value) {
      case MapLocationUpdateSuccess(location: final location):
        if (mapViewIsCentered) {
          _centerMapViewToCurrentLocation(location.toLatLng());
        }
        break;

      default:
        break;
    }
  }

  void _centerMapViewToCurrentLocation(LatLng location) {
    _animatedMapController.animateTo(
      dest: location,
    );
  }

  void _handleRecordRoutePoints() {
    switch (_mapLocationNotifier.value) {
      case MapLocationUpdateSuccess(location: final location):
        _routePoints.value.add(location.toLatLng());
      default:
        break;
    }
  }

  @override
  bool get wantKeepAlive => true;
}

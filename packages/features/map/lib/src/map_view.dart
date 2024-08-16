import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:latlong2/latlong.dart';

import 'extensions.dart';
import 'map_notifier.dart';

class MapView extends StatelessWidget {
  const MapView({super.key});

  @override
  Widget build(BuildContext context) {
    log('>>> _MapView build $runtimeType $hashCode');
    final mapNotifier = context.notifier;
    return Stack(
      children: [
        const _FlutterMapWidget(),
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
                  mapNotifier.zoomIn();
                },
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<double>(
                valueListenable: mapNotifier.currentZoomLevel,
                builder: (BuildContext context, double zoom, _) => Text(
                  '[$zoom]',
                ),
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              ValueListenableBuilder<bool>(
                valueListenable: mapNotifier.isMapCentered,
                builder: (BuildContext context, bool isCentered, _) => Switch(
                  value: isCentered,
                  onChanged: (value) {
                    mapNotifier.toggleMapCenter(value);
                  },
                ),
              ),
              const SizedBox(width: 20),
              // TODO: Temporary for testing
              IconButton(
                icon: const Icon(
                  Icons.zoom_out,
                ),
                onPressed: () {
                  mapNotifier.zoomOut();
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
            valueListenable: mapNotifier.isRouteRecordingActive,
            builder: (BuildContext context, bool isRecording, _) => Switch(
              value: isRecording,
              onChanged: (value) {
                if (value) {
                  mapNotifier.startRouteRecording();
                } else {
                  mapNotifier.stopRouteRecording();
                }
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _FlutterMapWidget extends StatefulWidget {
  const _FlutterMapWidget();

  @override
  State<_FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<_FlutterMapWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late MapNotifier _mapNotifier;
  late AnimatedMapController _animatedMapController;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapNotifier = context.notifier;
    _mapNotifier.onZoomChanged = ((zoom) {
      _animatedMapController.animatedZoomTo(zoom);
    });
    _mapNotifier.onMapCentered = ((location) {
      _animatedMapController.animateTo(
        dest: location.toLatLng(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FlutterMap(
      mapController: _animatedMapController.mapController,
      options: MapOptions(
        interactionOptions: const InteractionOptions(
          pinchZoomWinGestures: InteractiveFlag.pinchZoom,
        ),
        initialZoom: _mapNotifier.viewConfig.defaultZoom,
        maxZoom: _mapNotifier.viewConfig.maxZoom,
        minZoom: _mapNotifier.viewConfig.minZoom,
      ),
      children: const [
        _TileLayerWidget(),
        _PolylineLayerWidget(),
        _MarkerLayerWidget(),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _TileLayerWidget extends StatelessWidget {
  const _TileLayerWidget();

  @override
  Widget build(BuildContext context) {
    log('>>> _TileLayerWidget build $runtimeType $hashCode');
    final mapNotifier = context.notifier;
    // TODO: Implement handler for errors via errorTileCallback
    return TileLayer(
      retinaMode: true,
      userAgentPackageName: mapNotifier.viewConfig.userAgentPackageName,
      urlTemplate: mapNotifier.viewConfig.urlTemplate,
      fallbackUrl: mapNotifier.viewConfig.fallbackUrl,
      subdomains: const ['a', 'b', 'c'],
      maxZoom: mapNotifier.viewConfig.maxZoom,
      minZoom: mapNotifier.viewConfig.minZoom,
    );
  }
}

class _PolylineLayerWidget extends StatelessWidget {
  const _PolylineLayerWidget();

  @override
  Widget build(BuildContext context) {
    log('>>> _PolylineLayerWidget build $runtimeType $hashCode');
    final mapNotifier = context.notifier;
    return ValueListenableBuilder<List<LatLng>>(
      valueListenable: mapNotifier.routePoints,
      builder: (BuildContext context, List<LatLng> routePoints, _) {
        return ValueListenableBuilder<double>(
          valueListenable: mapNotifier.currentPolylineWidth,
          builder: (BuildContext context, double width, _) {
            return PolylineLayer(
              polylines: <Polyline>[
                Polyline(
                  points: routePoints,
                  color: context.appColors.lightPurple,
                  strokeWidth: width,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _MarkerLayerWidget extends StatelessWidget {
  const _MarkerLayerWidget();

  @override
  Widget build(BuildContext context) {
    log('>>> _MarkerLayerWidget build $runtimeType $hashCode');
    final mapNotifier = context.notifier;
    return ValueListenableBuilder<LocationState>(
      valueListenable: mapNotifier.locationState,
      builder: (_, LocationState locationState, __) {
        return ValueListenableBuilder<double>(
          valueListenable: mapNotifier.currentMarkerSize,
          builder: (BuildContext context, double size, _) {
            return switch (locationState) {
              LocationUpdateSuccess(location: final location) => MarkerLayer(
                  markers: <Marker>[
                    Marker(
                      width: size,
                      height: size,
                      point: location.toLatLng(),
                      child: Icon(
                        Icons.circle,
                        size: size,
                        color: Colors.deepPurple.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              LocationLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              _ => const SizedBox.shrink(),
            };
          },
        );
      },
    );
  }
}

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'extensions.dart';
import 'map_location_notifier.dart';
import 'map_view_notifier.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.mapLocationNotifier,
  });

  final MapLocationNotifier mapLocationNotifier;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late final AnimatedMapController _animatedMapController;
  late final MapLocationNotifier _mapLocationNotifier;
  final MapViewNotifier _mapViewNotifier = MapViewNotifier(
    shouldCenterMap: MapConfig.shouldCenterMap,
    zoom: MapConfig.defaultZoom,
    maxZoom: MapConfig.maxZoom,
    minZoom: MapConfig.minZoom,
  );

  @override
  void initState() {
    super.initState();

    _mapLocationNotifier = widget.mapLocationNotifier;
    _mapLocationNotifier.init();

    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );

    _mapViewNotifier.addListener(_handleZoomChanged);
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _mapViewNotifier.removeListener(_handleZoomChanged);
    _mapViewNotifier.dispose();
    _mapLocationNotifier.removeListener(_handleMapLocationChanged);
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('build map view');
    super.build(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _animatedMapController.mapController,
          options: const MapOptions(
            interactionOptions: MapConfig.interactionOptions,
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
              valueListenable: _mapLocationNotifier,
              builder: (BuildContext context, MapLocationState value, _) {
                if (value is MapLocationUpdateSuccess) {
                  return MarkerLayer(
                    markers: [
                      Marker(
                        width: 30.0,
                        height: 30.0,
                        point: value.location.toLatLng(),
                        child: const Icon(
                          Icons.circle,
                          size: 20.0,
                          color: Colors.deepPurple,
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
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
              IconButton(
                  icon: const Icon(
                    Icons.zoom_in,
                  ),
                  onPressed: () {
                    _mapViewNotifier.handleZoomedIn(MapConfig.zoomStep);
                  }),
              const SizedBox(width: 20),
              // TODO: For debugging
              ValueListenableBuilder<MapViewState>(
                valueListenable: _mapViewNotifier,
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
              ValueListenableBuilder<MapViewState>(
                valueListenable: _mapViewNotifier,
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
              IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    _mapViewNotifier.handleZoomedOut(MapConfig.zoomStep);
                  }),
            ],
          ),
        ),
      ],
    );
  }

  void _handleZoomChanged() {
    final mapViewState = _mapViewNotifier.value;
    if (mapViewState is MapViewUpdated) {
      _animatedMapController.animatedZoomTo(mapViewState.zoom);
    }
  }

  void _handleMapLocationChanged() {
    final mapViewState = _mapViewNotifier.value as MapViewUpdated;

    if (mapViewState.shouldCenterMap) {
      _moveToOnLocationUpdateSuccess();
    }
  }

  void _handleToggleButtonSwitched(bool value) {
    _mapViewNotifier.handleCenterMap(value);
    _moveToOnLocationUpdateSuccess();
  }

  void _moveToOnLocationUpdateSuccess() {
    final mapLocationState = _mapLocationNotifier.value;
    if (mapLocationState is MapLocationUpdateSuccess) {
      _animatedMapController.animateTo(
        dest: mapLocationState.location.toLatLng(),
      );
    }
  }

  @override
  bool get wantKeepAlive => true;
}

abstract class MapConfig {
  static const bool shouldCenterMap = true;
  static const double zoomStep = 0.5;
  static const double defaultZoom = 16;
  static const double maxZoom = 18;
  static const double minZoom = 14;
  static const String fallbackUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static const String urlTemplate =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static const String userAgentPackageName = 'com.github.abra.footprint';
  static const InteractionOptions interactionOptions = InteractionOptions(
    pinchZoomWinGestures: InteractiveFlag.pinchZoom,
  );
}


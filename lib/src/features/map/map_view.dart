import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';

import 'extensions.dart';
import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';
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
  late final MapLocationNotifier _mapLocationNotifier;
  late final MapViewNotifier _viewNotifier;

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
    _mapLocationNotifier = context.locationNotifier;
    _viewNotifier.addListener(_handleZoomChanged);
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
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
            _TileLayer(
              viewNotifier: _viewNotifier,
            ),
            _MapMarker(),
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
                  _viewNotifier.handleZoomedIn();
                },
              ),
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
              IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    _viewNotifier.handleZoomedOut();
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

  // TODO: Temporary for testing
  void _handleToggleButtonSwitched(bool value) {
    _viewNotifier.handleCenterMap(value);
    _moveToOnLocation();
  }

  void _handleMapLocationChanged() {
    final mapViewState = _viewNotifier.value;
    if (mapViewState is MapViewUpdated) {
      if (mapViewState.shouldCenterMap) {
        _moveToOnLocation();
      }
    }
  }

  void _moveToOnLocation() {
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

class _TileLayer extends StatelessWidget {
  const _TileLayer({
    required MapViewNotifier viewNotifier,
  }) : _viewNotifier = viewNotifier;

  final MapViewNotifier _viewNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapViewState>(
      valueListenable: _viewNotifier,
      builder: (BuildContext context, MapViewState state, _) {
        if (state is MapViewUpdated) {
          return TileLayer(
            retinaMode: true,
            userAgentPackageName: state.userAgentPackageName,
            urlTemplate: state.urlTemplate,
            fallbackUrl: state.fallbackUrl,
            subdomains: const ['a', 'b', 'c'],
            maxZoom: state.maxZoom,
            minZoom: state.minZoom,
          );
        }
        return TileLayer();
      },
    );
  }
}

class _MapMarker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapLocationState>(
      valueListenable: MapLocationNotifierProvider.of(context).notifier,
      builder: (BuildContext context, MapLocationState state, _) {
        // TODO: Replace
        if (state is MapLocationUpdateSuccess) {
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
        } else if (state is MapInitialLocationUpdate) {
          return const Center(child: CircularProgressIndicator());
        }
        return const SizedBox.shrink();
      },
    );
  }
}

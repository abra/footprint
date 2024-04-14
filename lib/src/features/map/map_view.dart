import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:footprint/src/app/common/colors.dart';
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
  late final MapLocationNotifier _mapLocationNotifier;
  late final MapViewNotifier _viewNotifier;
  final _recordingNotifier = ValueNotifier<bool>(false);
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
    _mapLocationNotifier = context.locationNotifier;
    _viewNotifier.addListener(_handleZoomChanged);
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
    _mapLocationNotifier.addListener(() {
      if (_recordingNotifier.value) {
        final value = _mapLocationNotifier.value;
        if (value is MapLocationUpdateSuccess) {
          _routePoints.value.add(value.location.toLatLng());
        }
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
            _TileLayer(viewNotifier: _viewNotifier),
            _PolylineLayer(routePoints: _routePoints),
            _MapMarker(locationNotifier: _mapLocationNotifier),
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
        Positioned(
          left: 0,
          right: 0,
          bottom: 20,
          child: ValueListenableBuilder<bool>(
              valueListenable: _recordingNotifier,
              builder: (BuildContext context, bool isRecording, _) {
                print('isRecording: $isRecording');
                return Switch(
                  value: isRecording,
                  onChanged: (value) {
                    print('value: $value');
                    _recordingNotifier.value = value;
                    if (!value) {
                      _routePoints.value.clear();
                    }
                  },
                );
              }),
        ),
      ],
    );
  }

  void _handleZoomChanged() {
    final mapView = _viewNotifier.value;
    final zoom = (mapView as MapViewUpdated).zoom;
    _animatedMapController.animatedZoomTo(zoom);
  }

  // TODO: Temporary for testing
  void _handleToggleButtonSwitched(bool value) {
    _viewNotifier.handleCenterMap(value);
    final mapView = _viewNotifier.value;
    final mapLocation = _mapLocationNotifier.value;
    if (mapView is MapViewUpdated && mapLocation is MapLocationUpdateSuccess) {
      _moveToLocation(mapLocation.location.toLatLng());
    }
  }

  void _handleMapLocationChanged() {
    final mapView = _viewNotifier.value;
    final mapLocation = _mapLocationNotifier.value;
    final shouldCenterMap = (mapView as MapViewUpdated).shouldCenterMap;
    if (shouldCenterMap && mapLocation is MapLocationUpdateSuccess) {
      _moveToLocation(mapLocation.location.toLatLng());
    }
  }

  void _moveToLocation(LatLng location) {
    _animatedMapController.animateTo(
      dest: location,
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _PolylineLayer extends StatelessWidget {
  const _PolylineLayer({
    required ValueNotifier<List<LatLng>> routePoints,
  }) : _routePoints = routePoints;

  final ValueNotifier<List<LatLng>> _routePoints;

  @override
  Widget build(BuildContext context) {
    log('>>>>>>>>> build $runtimeType $hashCode');
    return ValueListenableBuilder(
      valueListenable: _routePoints,
      builder: (BuildContext context, List<LatLng> value, _) {
        return PolylineLayer(
          polylines: <Polyline>[
            Polyline(
              points: value,
              color: AppColors.lightPurple,
              strokeWidth: 4,
              // double _routeLineWidth = ((11 * defaultZoom - 126) / 4) / 2.5;
              // borderStrokeWidth: 2,
            ),
          ],
        );
      },
    );
  }
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
  const _MapMarker({
    required MapLocationNotifier locationNotifier,
  }) : _mapLocationNotifier = locationNotifier;

  final MapLocationNotifier _mapLocationNotifier;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MapLocationState>(
      valueListenable: _mapLocationNotifier,
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

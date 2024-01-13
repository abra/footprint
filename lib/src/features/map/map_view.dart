import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:footprint/src/features/map/map_view_notifier.dart';
import 'package:latlong2/latlong.dart';

import 'map_location_notifier.dart';

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
  late MapLocationNotifier _mapLocationNotifier;
  late MapViewNotifier _mapViewNotifier;

  @override
  void initState() {
    super.initState();

    _mapLocationNotifier = widget.mapLocationNotifier;

    _mapViewNotifier = MapViewNotifier(
      shouldCenter: _Config.shouldCenter,
      zoom: _Config.defaultZoom,
      maxZoom: _Config.maxZoom,
      minZoom: _Config.minZoom,
    );

    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );

    _mapViewNotifier.addListener(_onZoomChanged);
    _mapLocationNotifier.addListener(_onMapLocationChanged);
    _mapLocationNotifier.runLocationUpdate();
  }

  void _onZoomChanged() {
    final mapViewState = _mapViewNotifier.value as MapViewUpdated;
    _animatedMapController.animatedZoomTo(mapViewState.zoom);
  }

  void _onMapLocationChanged() {
    final mapLocationState = _mapLocationNotifier.value;

    // TODO: Temporary code during development
    if (mapLocationState is MapLocationUpdateSuccess) {
      _animatedMapController.animateTo(
        dest: mapLocationState.location.toLatLng(),
        customId: 'location',
      );
    }
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _mapViewNotifier.removeListener(_onZoomChanged);
    _mapLocationNotifier.removeListener(_onMapLocationChanged);
    _mapViewNotifier.dispose();
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    return Stack(
      children: [
        FlutterMap(
          mapController: _animatedMapController.mapController,
          options: MapOptions(
            interactionOptions: _Config.interactionOptions,
            initialZoom: _Config.defaultZoom,
            maxZoom: _Config.maxZoom,
            minZoom: _Config.minZoom,
          ),
          children: [
            TileLayer(
              retinaMode: true,
              userAgentPackageName: _Config.userAgentPackageName,
              urlTemplate: _Config.urlTemplate,
              fallbackUrl: _Config.fallbackUrl,
              subdomains: const ['a', 'b', 'c'],
              maxZoom: _Config.maxZoom,
              minZoom: _Config.minZoom,
            ),
            ValueListenableBuilder(
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
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                }),
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
                    _mapViewNotifier.onZoomIn(0.25);
                  }),
              const SizedBox(width: 20),
              IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    _mapViewNotifier.onZoomOut(0.25);
                  }),
            ],
          ),
        ),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

abstract class _Config {
  static bool shouldCenter = true;
  static double defaultZoom = 17;
  static double maxZoom = 17.5;
  static double minZoom = 14;
  static String urlTemplate = 'https://tile.openstreetmap.org/{z}/{x}/{y}.png';
  static String fallbackUrl =
      'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png';
  static String userAgentPackageName = 'com.github.abra.footprint';
  static InteractionOptions interactionOptions = const InteractionOptions(
    pinchZoomWinGestures: InteractiveFlag.pinchZoom,
  );
}

extension LocationToLatLng on Location {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

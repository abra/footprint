import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:footprint/src/domain_models/location.dart';
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
  bool _centerMapToCurrentLocation = true;

  @override
  void initState() {
    super.initState();
    _mapLocationNotifier = widget.mapLocationNotifier;
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
    _mapLocationNotifier.addListener(_moveMapOnLocationUpdate);
    _mapLocationNotifier.updateLocation();
  }

  void _moveMapOnLocationUpdate() {
    final mapState = _mapLocationNotifier.value;

    // TODO: Temporary code during development
    if (mapState is MapLocationUpdateSuccess) {
      _animatedMapController.animateTo(
        dest: mapState.location.toLatLng(),
        zoom: 14,
        customId: 'location',
      );
    }
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    _mapLocationNotifier.removeListener(_moveMapOnLocationUpdate);
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
            initialCenter: const LatLng(64.4316, 76.5235),
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
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

abstract class _Config {
  static double defaultZoom = 17;
  static double maxZoom = 18;
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

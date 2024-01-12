import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'map_notifier.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.mapNotifier,
  });

  final MapNotifier mapNotifier;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  late final MapController _mapController;
  late MapNotifier _mapNotifier;

  @override
  void initState() {
    super.initState();
    _mapNotifier = widget.mapNotifier;
    _mapController = MapController();
  }

  @override
  void dispose() {
    _mapNotifier.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
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
            const MarkerLayer(
              markers: [
                Marker(
                  width: 80.0,
                  height: 80.0,
                  point: LatLng(
                    64.4316,
                    76.5235,
                  ),
                  child: Icon(
                    Icons.circle,
                    size: 10.0,
                    color: Colors.purpleAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
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

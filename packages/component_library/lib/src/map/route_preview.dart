import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import '../photos/route_photo_markers.dart';
import 'map_attribution.dart';
import 'map_tile_config.dart';
import 'map_tiles.dart';

class RoutePreview extends StatefulWidget {
  const RoutePreview({
    super.key,
    required this.route,
    this.config = const MapTileConfig(),
    this.interactive = false,
    this.onTap,
    this.photos = const [],
  });
  final RouteDM route;
  final MapTileConfig config;
  final bool interactive;
  final VoidCallback? onTap;
  final List<RoutePhotoDM> photos;

  @override
  State<RoutePreview> createState() => _RoutePreviewState();
}

class _RoutePreviewState extends State<RoutePreview> {
  bool _failed = false;
  int _generation = 0;
  late List<LatLng> _points;

  @override
  void initState() {
    super.initState();
    _readPoints();
  }

  void _readPoints() => _points = [
    for (final point in widget.route.routePoints)
      if (point.latitude.isFinite &&
          point.longitude.isFinite &&
          point.latitude.abs() <= 90 &&
          point.longitude.abs() <= 180)
        LatLng(point.latitude, point.longitude),
  ];

  @override
  void didUpdateWidget(RoutePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.route, widget.route)) {
      _readPoints();
      _generation++;
      _failed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_points.isEmpty) {
      return const ColoredBox(
        color: AppTheme.surface,
        child: Center(child: Text('No route points')),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FlutterMap(
            key: ValueKey((widget.route.id, _generation)),
            options: MapOptions(
              initialCenter: _points.first,
              initialZoom: 16,
              onTap: widget.onTap == null ? null : (_, _) => widget.onTap!(),
              initialCameraFit: _points.length < 2
                  ? null
                  : CameraFit.bounds(
                      bounds: LatLngBounds.fromPoints(_points),
                      padding: const EdgeInsets.all(36),
                      maxZoom: 17,
                    ),
              interactionOptions: InteractionOptions(
                flags: widget.interactive
                    ? InteractiveFlag.all
                    : InteractiveFlag.none,
              ),
            ),
            children: [
              MapTiles(
                config: widget.config,
                onError: () => setState(() => _failed = true),
              ),
              if (_points.length >= 2)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _points,
                      strokeWidth: 4,
                      color: AppTheme.route,
                    ),
                  ],
                ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: _points.first,
                    width: 28,
                    height: 28,
                    child: const Icon(
                      Icons.location_on_outlined,
                      color: AppTheme.ink,
                    ),
                  ),
                  if (_points.length > 1)
                    Marker(
                      point: _points.last,
                      width: 28,
                      height: 28,
                      child: const Icon(
                        Icons.flag_outlined,
                        color: AppTheme.coral,
                      ),
                    ),
                ],
              ),
              if (widget.photos.isNotEmpty)
                RoutePhotoMarkers(photos: widget.photos),
              MapAttribution(config: widget.config),
            ],
          ),
          if (_failed)
            Align(
              alignment: Alignment.topRight,
              child: Material(
                color: Colors.white,
                child: IconButton(
                  tooltip: 'Retry map tiles',
                  icon: const Icon(Icons.cloud_off_outlined),
                  onPressed: () => setState(() {
                    _failed = false;
                    _generation++;
                  }),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

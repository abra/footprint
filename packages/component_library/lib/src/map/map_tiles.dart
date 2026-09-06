import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

import 'map_tile_config.dart';

class MapTiles extends StatefulWidget {
  const MapTiles({super.key, required this.config, required this.onError});
  final MapTileConfig config;
  final VoidCallback onError;

  @override
  State<MapTiles> createState() => _MapTilesState();
}

class _MapTilesState extends State<MapTiles> {
  late final _provider =
      widget.config.tileProviderFactory?.call() ?? NetworkTileProvider();
  bool _reported = false;

  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: widget.config.urlTemplate,
    userAgentPackageName: widget.config.userAgentPackageName,
    tileProvider: _provider,
    maxNativeZoom: 19,
    panBuffer: 0,
    keepBuffer: 1,
    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
    errorTileCallback: (tile, error, stack) {
      if (_reported) return;
      _reported = true;
      scheduleMicrotask(() {
        if (mounted) widget.onError();
      });
    },
  );
}

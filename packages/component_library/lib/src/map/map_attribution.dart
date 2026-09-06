import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_tile_config.dart';

class MapAttribution extends StatelessWidget {
  const MapAttribution({super.key, required this.config});
  final MapTileConfig config;

  @override
  Widget build(BuildContext context) => RichAttributionWidget(
    showFlutterMapAttribution: false,
    attributions: [
      TextSourceAttribution(
        config.attribution,
        onTap: () => unawaited(launchUrl(Uri.parse(config.attributionUrl))),
      ),
    ],
  );
}

class MapAttributionButton extends StatelessWidget {
  const MapAttributionButton({super.key, required this.config});
  final MapTileConfig config;

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'Attributions',
    icon: const Icon(Icons.info_outline),
    onPressed: () => unawaited(
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Map data'),
          content: TextButton.icon(
            icon: const Icon(Icons.open_in_new),
            label: Text(config.attribution),
            onPressed: () =>
                unawaited(launchUrl(Uri.parse(config.attributionUrl))),
          ),
          actions: [
            IconButton(
              tooltip: 'Close attribution',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    ),
  );
}

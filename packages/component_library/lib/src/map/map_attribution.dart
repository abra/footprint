import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:url_launcher/url_launcher.dart';

import 'map_tile_config.dart';
import '../action_sheet.dart';

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
    onPressed: () async {
      final open = await showAppActionSheet<bool>(
        context,
        title: 'Map data',
        cancelLabel: 'Close attribution',
        actions: [
          SheetAction(
            value: true,
            label: config.attribution,
            icon: Icons.open_in_new,
          ),
        ],
      );
      if (open == true) await launchUrl(Uri.parse(config.attributionUrl));
    },
  );
}

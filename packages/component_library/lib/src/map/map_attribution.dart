import 'dart:async';

import '../app_button.dart';

import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
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
  Widget build(BuildContext context) => AppIconButton(
    tooltip: 'Attributions',
    icon: const Icon(FLucideIcons.info),
    onPressed: () async {
      final open = await showAppActionSheet<bool>(
        context,
        title: 'Map data',
        cancelLabel: 'Close attribution',
        actions: [
          SheetAction(
            value: true,
            label: config.attribution,
            icon: FLucideIcons.externalLink,
          ),
        ],
      );
      if (open == true) await launchUrl(Uri.parse(config.attributionUrl));
    },
  );
}

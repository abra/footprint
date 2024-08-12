import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'map_notifier.dart';
import 'map_notifier_provider.dart';

extension LocationToLatLng on LocationModel {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

extension MapNotifierProviderExt on BuildContext {
  MapNotifier get notifier => MapNotifierProvider.of(this).notifier;
}

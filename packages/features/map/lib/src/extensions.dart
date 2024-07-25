import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/map_view_notifier.dart';

import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

extension LocationToLatLng on Location {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

extension MapNotifierProviderExt on BuildContext {
  MapLocationNotifier get locationNotifier =>
      MapNotifierProvider.of(this).locationNotifier;

  MapViewNotifier get viewNotifier =>
      MapNotifierProvider.of(this).viewNotifier;
}

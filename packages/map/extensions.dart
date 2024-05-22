import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../domain_models/location.dart';
import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

extension LocationToLatLng on Location {
  LatLng toLatLng() => LatLng(latitude, longitude);
}

extension MapLocationNotifierProviderExt on BuildContext {
  MapLocationNotifier get locationNotifier =>
      MapLocationNotifierProvider.of(this).notifier;
}

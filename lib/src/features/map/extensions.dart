import 'package:flutter/material.dart';
import 'package:footprint/src/domain_models/location.dart';
import 'package:latlong2/latlong.dart';

import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

extension LocationToLatLng on Location {
  LatLng toLatLng() {
    return LatLng(latitude, longitude);
  }
}

extension MapLocationNotifierProviderExt on BuildContext {
  MapLocationNotifier get locationNotifier =>
      MapLocationNotifierProvider.of(this).notifier;
}
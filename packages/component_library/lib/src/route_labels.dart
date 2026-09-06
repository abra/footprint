import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';

abstract final class RouteLabels {
  static ({String value, String unit}) distanceParts(double meters) =>
      meters < 1000
      ? (value: '${meters.round()}', unit: 'm')
      : (value: (meters / 1000).toStringAsFixed(1), unit: 'km');

  static ({String value, String unit}) speedParts(double metersPerSecond) =>
      (value: (metersPerSecond * 3.6).toStringAsFixed(1), unit: 'km/h');

  static String distance(double meters) => _withUnit(distanceParts(meters));
  static String speed(double metersPerSecond) =>
      _withUnit(speedParts(metersPerSecond));

  static String _withUnit(({String value, String unit}) parts) =>
      '${parts.value} ${parts.unit}';
  static String duration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  static String title(BuildContext context, RouteDM route) =>
      route.name ?? 'Route ${date(context, route.startTime)}';

  static String date(BuildContext context, DateTime value) {
    final local = value.toLocal();
    final labels = MaterialLocalizations.of(context);
    return '${labels.formatMediumDate(local)} ${labels.formatTimeOfDay(TimeOfDay.fromDateTime(local))}';
  }
}

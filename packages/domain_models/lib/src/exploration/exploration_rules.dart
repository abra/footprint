import 'package:dart_geohash/dart_geohash.dart';
import 'package:equatable/equatable.dart';

import '../location_dm.dart';
import 'geo_point.dart';

/// Precision is part of the persisted cell identity, not a UI zoom setting.
class ExplorationCell extends Equatable {
  const ExplorationCell._(this.id, this.center);
  static final _hasher = GeoHasher();
  static const precision = 7;
  static const halfSize = 180 / 262144;

  factory ExplorationCell.at(GeoPoint point) {
    if (!point.isValid) throw ArgumentError.value(point, 'point');
    return ExplorationCell.fromId(
      _hasher.encode(point.longitude, point.latitude, precision: precision),
    );
  }

  factory ExplorationCell.fromId(String id) {
    if (id.length != precision ||
        !RegExp(r'^[0-9bcdefghjkmnpqrstuvwxyz]+$').hasMatch(id)) {
      throw const FormatException('Invalid exploration cell.');
    }
    final coordinates = _hasher.decode(id);
    return ExplorationCell._(id, GeoPoint(coordinates[1], coordinates[0]));
  }

  final String id;
  final GeoPoint center;
  List<GeoPoint> get corners => [
    GeoPoint(center.latitude - halfSize, center.longitude - halfSize),
    GeoPoint(center.latitude - halfSize, center.longitude + halfSize),
    GeoPoint(center.latitude + halfSize, center.longitude + halfSize),
    GeoPoint(center.latitude + halfSize, center.longitude - halfSize),
  ];

  @override
  List<Object> get props => [id];
}

/// These rules consume measured fixes, never presentation/animation frames.
abstract final class ExplorationRules {
  static const checkpointRadius = 30.0;

  static bool usable(LocationDM point) =>
      point.hasValidCoordinates &&
      point.accuracy != null &&
      point.accuracy!.isFinite &&
      point.accuracy! > 0 &&
      point.accuracy! <= 25 &&
      (point.reliableSpeed == null || point.reliableSpeed! <= 4.5);

  static bool consecutive(LocationDM previous, LocationDM current) {
    final seconds =
        current.timestamp.difference(previous.timestamp).inMilliseconds / 1000;
    return usable(previous) &&
        usable(current) &&
        seconds >= 1 &&
        seconds <= 30 &&
        _position(previous).distanceTo(_position(current)) <= seconds * 4.5;
  }

  static bool reaches(
    LocationDM previous,
    LocationDM current,
    GeoPoint checkpoint, {
    DateTime? lastReached,
  }) {
    if (!consecutive(previous, current) ||
        (lastReached != null && !previous.timestamp.isAfter(lastReached))) {
      return false;
    }
    return [previous, current].every(
      (p) =>
          _position(p).distanceTo(checkpoint) + p.accuracy! <=
              checkpointRadius &&
          GeoPoint(
                p.rawLatitude ?? p.latitude,
                p.rawLongitude ?? p.longitude,
              ).distanceTo(checkpoint) <=
              checkpointRadius,
    );
  }

  static ExplorationCell? discovered(LocationDM previous, LocationDM current) {
    if (!consecutive(previous, current)) return null;
    final cell = ExplorationCell.at(_position(current));
    if (cell != ExplorationCell.at(_position(previous))) return null;
    // Keep the uncertainty circle inside a cell to avoid border jitter farming.
    for (final point in [previous, current]) {
      final position = _position(point);
      final horizontal = position.distanceTo(
        GeoPoint(
          point.latitude,
          cell.center.longitude +
              (point.longitude >= cell.center.longitude ? 1 : -1) *
                  ExplorationCell.halfSize,
        ),
      );
      final vertical = position.distanceTo(
        GeoPoint(
          cell.center.latitude +
              (point.latitude >= cell.center.latitude ? 1 : -1) *
                  ExplorationCell.halfSize,
          point.longitude,
        ),
      );
      if (horizontal < point.accuracy! || vertical < point.accuracy!) {
        return null;
      }
    }
    return cell;
  }

  static GeoPoint _position(LocationDM point) =>
      GeoPoint(point.latitude, point.longitude);
}

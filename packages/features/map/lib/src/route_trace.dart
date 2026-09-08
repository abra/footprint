import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'extensions.dart';

/// Renders a recording up to the marker's playback time, not the newest GPS fix.
class RouteTrace extends StatefulWidget {
  const RouteTrace({
    super.key,
    required this.points,
    required this.isRecording,
    required this.motion,
    this.muted = false,
  });

  final List<LocationDM> points;
  final bool isRecording;
  final LocationMotion motion;
  final bool muted;

  @override
  State<RouteTrace> createState() => _RouteTraceState();
}

class _RouteTraceState extends State<RouteTrace> {
  final _coordinates = <LatLng>[];
  final _timestamps = <int>[];
  int _historyCount = -1;
  List<LatLng> _history = const [];

  @override
  void initState() {
    super.initState();
    _readPoints();
  }

  @override
  void didUpdateWidget(RouteTrace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.points, widget.points)) _readPoints();
  }

  void _readPoints() {
    _coordinates.clear();
    _timestamps.clear();
    _historyCount = -1;
    for (final point in widget.points) {
      if (!point.hasValidCoordinates) continue;
      _coordinates.add(point.toLatLng());
      final time = point.timestamp.microsecondsSinceEpoch;
      // Late samples must not appear before the preceding recorded point.
      _timestamps.add(
        _timestamps.isEmpty || time > _timestamps.last
            ? time
            : _timestamps.last,
      );
    }
  }

  int _visibleCount(DateTime time) {
    final timestamp = time.microsecondsSinceEpoch;
    var low = 0;
    var high = _timestamps.length;
    while (low < high) {
      final middle = (low + high) ~/ 2;
      if (_timestamps[middle] <= timestamp) {
        low = middle + 1;
      } else {
        high = middle;
      }
    }
    return low;
  }

  List<LatLng> _historyFor(int count) {
    if (count != _historyCount) {
      _historyCount = count;
      _history = count < 2 ? const [] : _coordinates.sublist(0, count);
    }
    return _history;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isRecording) {
      return RecordedRouteLayer(
        points: _historyFor(_coordinates.length),
        muted: widget.muted,
        strokeWidth: widget.muted ? 4 : 7,
      );
    }
    return ValueListenableBuilder<LatLng?>(
      valueListenable: widget.motion,
      builder: (context, point, child) {
        final time = widget.motion.displayedAt;
        if (point == null || time == null) {
          return RecordedRouteLayer(points: _historyFor(_coordinates.length));
        }
        final count = _visibleCount(time);
        return RecordedRouteLayer(
          points: _historyFor(count),
          tail: count > 0 && _coordinates[count - 1] != point
              ? [_coordinates[count - 1], point]
              : const [],
        );
      },
    );
  }
}

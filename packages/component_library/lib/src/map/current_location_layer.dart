import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../theme/app_theme.dart';
import 'heading_motion.dart';

class CurrentLocationLayer extends StatelessWidget {
  const CurrentLocationLayer({super.key, required this.position, this.heading})
    : headingMotion = null;

  /// Uses the same visual course as a following camera, without a second tween.
  const CurrentLocationLayer.withHeadingMotion({
    super.key,
    required this.position,
    required HeadingMotion this.headingMotion,
  }) : heading = null;

  final ValueListenable<LatLng?> position;

  /// Geographic course clockwise from north; null keeps the static fallback dot.
  final ValueListenable<double?>? heading;
  final HeadingMotion? headingMotion;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<LatLng?>(
    valueListenable: position,
    child: _LocationMarker(heading: heading, motion: headingMotion),
    builder: (context, point, child) => MarkerLayer(
      key: const ValueKey('current-location-layer'),
      markers: [
        if (point != null)
          Marker(
            point: point,
            width: 40,
            height: 40,
            // Heading is geographic: rotate with the map, not against it.
            rotate: false,
            child: child!,
          ),
      ],
    ),
  );
}

class _LocationMarker extends StatefulWidget {
  const _LocationMarker({required this.heading, required this.motion});

  final ValueListenable<double?>? heading;
  final HeadingMotion? motion;

  @override
  State<_LocationMarker> createState() => _LocationMarkerState();
}

class _LocationMarkerState extends State<_LocationMarker>
    with TickerProviderStateMixin {
  static const _minArrowSize = 24.0;
  static const _maxArrowSize = 36.0;
  static const _minSizingZoom = 10.0;
  static const _maxSizingZoom = 16.0;

  final _unknown = ValueNotifier<double?>(null);
  late HeadingMotion _motion;
  bool _hasHeading = false;
  MapController? _map;
  StreamSubscription<MapEvent>? _mapEvents;
  double _arrowSize = _maxArrowSize;

  @override
  void initState() {
    super.initState();
    _attach();
  }

  void _attach() {
    _motion =
        widget.motion ??
        HeadingMotion(vsync: this, heading: widget.heading ?? _unknown);
    _hasHeading = _motion.value != null;
    _motion.addListener(_headingChanged);
  }

  @override
  void didUpdateWidget(covariant _LocationMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.heading != widget.heading ||
        oldWidget.motion != widget.motion) {
      _motion.removeListener(_headingChanged);
      if (oldWidget.motion == null) _motion.dispose();
      _attach();
      _syncMotion();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final map = MapController.of(context);
    if (_map != map) {
      unawaited(_mapEvents?.cancel());
      _map = map;
      _arrowSize = _sizeAtZoom(map.camera.zoom);
      _mapEvents = map.mapEventStream.listen((_) {
        if (!mounted || _map != map) return;
        final size = _sizeAtZoom(map.camera.zoom);
        // Panning, course-up rotation and zooming outside the sizing range
        // must not rebuild the glyph or create another animation ticker.
        if (size != _arrowSize) setState(() => _arrowSize = size);
      });
    }
    _syncMotion();
  }

  static double _sizeAtZoom(double zoom) {
    final progress =
        ((zoom - _minSizingZoom) / (_maxSizingZoom - _minSizingZoom)).clamp(
          0.0,
          1.0,
        );
    return _minArrowSize + (_maxArrowSize - _minArrowSize) * progress;
  }

  void _syncMotion() {
    if (widget.motion == null) {
      _motion.enabled =
          !MediaQuery.disableAnimationsOf(context) &&
          TickerMode.valuesOf(context).enabled;
    }
  }

  void _headingChanged() {
    final hasHeading = _motion.value != null;
    if (hasHeading != _hasHeading) {
      setState(() => _hasHeading = hasHeading);
    }
  }

  @override
  void dispose() {
    unawaited(_mapEvents?.cancel());
    _motion.removeListener(_headingChanged);
    if (widget.motion == null) _motion.dispose();
    _unknown.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: 'Current location',
    child: RepaintBoundary(
      child: !_hasHeading
          ? const _LocationDot()
          : Center(
              child: RotationTransition(
                turns: _motion.turns,
                child: Icon(
                  Icons.navigation_rounded,
                  size: _arrowSize,
                  color: AppTheme.route,
                  applyTextScaling: false,
                  shadows: const [
                    Shadow(
                      color: Color(0x2E1F1837),
                      blurRadius: 4,
                      offset: Offset.zero,
                    ),
                  ],
                ),
              ),
            ),
    ),
  );
}

class _LocationDot extends StatelessWidget {
  const _LocationDot();

  @override
  Widget build(BuildContext context) => const Stack(
    alignment: Alignment.center,
    children: [
      Positioned.fill(
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0x0F8057D8),
          ),
        ),
      ),
      SizedBox.square(
        dimension: 28,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppTheme.route,
            boxShadow: [
              BoxShadow(
                color: Color(0x121F1837),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ),
      SizedBox.square(
        dimension: 6,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
        ),
      ),
    ],
  );
}

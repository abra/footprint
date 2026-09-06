import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'extensions.dart';
import 'location_motion.dart';
import 'map_app_bar.dart';
import 'map_cubit.dart';
import 'map_state.dart';
import 'map_photo_controls.dart';
import 'route_trace.dart';
import 'recording_stats_panel.dart';
import 'recording_indicator.dart';

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.config,
    required this.onRoutesRequested,
    this.onRouteCompleted,
  });
  final MapConfig config;
  final VoidCallback onRoutesRequested;
  final ValueChanged<int>? onRouteCompleted;

  @override
  Widget build(BuildContext context) => BlocListener<MapCubit, MapState>(
    listenWhen: (before, after) =>
        before.completedRouteId != after.completedRouteId &&
        after.completedRouteId != null,
    listener: (context, state) =>
        onRouteCompleted?.call(state.completedRouteId!),
    child: Scaffold(
      body: _MapCanvas(config: config, onRoutesRequested: onRoutesRequested),
    ),
  );
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({required this.config, required this.onRoutesRequested});
  final MapConfig config;
  final VoidCallback onRoutesRequested;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas>
    with SingleTickerProviderStateMixin {
  final _controller = MapController();
  late final LocationMotion _locationMotion;
  bool _ready = false;
  bool _hasLocation = false;
  bool _animateLocation = true;

  @override
  void initState() {
    super.initState();
    _locationMotion = LocationMotion(vsync: this)..addListener(_center);
    if (context.read<MapCubit>().state.location case final location?) {
      _locationMotion.moveTo(
        location.toLatLng(),
        timestamp: location.timestamp,
        animate: false,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animateLocation =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (context.read<MapCubit>().state.location case final location?
        when !_animateLocation) {
      _locationMotion.moveTo(
        location.toLatLng(),
        timestamp: location.timestamp,
        animate: false,
      );
    }
  }

  void _center() {
    final point = _locationMotion.value;
    if (!_ready || !context.read<MapCubit>().state.centered || point == null) {
      return;
    }
    _controller.move(
      point,
      _hasLocation ? _controller.camera.zoom : widget.config.defaultZoom,
    );
    _hasLocation = true;
  }

  @override
  void dispose() {
    _locationMotion.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<MapCubit>();
    return BlocListener<MapCubit, MapState>(
      listenWhen: (before, after) =>
          before.location != after.location ||
          before.centered != after.centered,
      listener: (context, state) {
        if (state.location case final location?) {
          _locationMotion.moveTo(
            location.toLatLng(),
            timestamp: location.timestamp,
            animate: _animateLocation,
          );
        }
        _center();
      },
      child: Stack(
        children: [
          Positioned.fill(
            child: FlutterMap(
              mapController: _controller,
              options: MapOptions(
                initialCenter:
                    cubit.state.location?.toLatLng() ?? const LatLng(0, 0),
                initialZoom: cubit.state.location == null
                    ? 2
                    : widget.config.defaultZoom,
                minZoom: widget.config.minZoom,
                maxZoom: widget.config.maxZoom,
                onMapReady: () {
                  _ready = true;
                  _center();
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture && cubit.state.centered) {
                    cubit.setCentered(false);
                  }
                },
              ),
              children: [
                BlocSelector<MapCubit, MapState, int>(
                  selector: (state) => state.tileGeneration,
                  builder: (context, generation) => MapTiles(
                    key: ValueKey(generation),
                    config: widget.config,
                    onError: cubit.tilesFailed,
                  ),
                ),
                BlocBuilder<MapCubit, MapState>(
                  buildWhen: (before, after) =>
                      before.points != after.points ||
                      before.isRecording != after.isRecording,
                  builder: (context, state) => RouteTrace(
                    points: state.points,
                    isRecording: state.isRecording,
                    motion: _locationMotion,
                  ),
                ),
                ValueListenableBuilder<LatLng?>(
                  valueListenable: _locationMotion,
                  builder: (context, point, child) => MarkerLayer(
                    key: const ValueKey('current-location-layer'),
                    markers: [
                      if (point != null)
                        Marker(
                          point: point,
                          width: 28,
                          height: 28,
                          child: Semantics(
                            label: 'Current location',
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF8057D8),
                                border: Border.all(
                                  color: AppTheme.route,
                                  width: 4,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0x26000000),
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                BlocSelector<MapCubit, MapState, List<RoutePhotoDM>>(
                  selector: (state) => state.photos,
                  builder: (context, photos) =>
                      RoutePhotoMarkers(photos: photos),
                ),
                BlocBuilder<MapCubit, MapState>(
                  buildWhen: (before, after) => before.points != after.points,
                  builder: (context, state) => state.points.length < 2
                      ? const SizedBox.shrink()
                      : MarkerLayer(
                          key: const ValueKey('route-start-layer'),
                          markers: [
                            Marker(
                              point: state.points.first.toLatLng(),
                              width: 32,
                              height: 32,
                              // The pole ends at (6, 21) in the 24px glyph.
                              // Scale to 30px and include 1px of padding.
                              alignment: Marker.computePixelAlignment(
                                width: 32,
                                height: 32,
                                left: 8.5,
                                top: 27.25,
                              ),
                              rotate: true,
                              child: const Tooltip(
                                message: 'Route start',
                                child: Icon(
                                  Icons.flag,
                                  color: AppTheme.coral,
                                  size: 30,
                                  applyTextScaling: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Column(
                  children: [
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * 0.36,
                      ),
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            MapAppBar(onPageChange: widget.onRoutesRequested),
                            const _MapError(),
                            const MapPhotoError(),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, available) => Stack(
                          children: [
                            Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: MapSurface(
                                  child: MapAttributionButton(
                                    config: widget.config,
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: IconTheme.merge(
                                data: const IconThemeData(
                                  applyTextScaling: false,
                                ),
                                child: _MapControls(
                                  horizontal: available.maxHeight < 270,
                                  onZoom: _zoom,
                                  onCenter: () {
                                    cubit.setCentered(true);
                                    _center();
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    BlocBuilder<MapCubit, MapState>(
                      buildWhen: (before, after) =>
                          before.isRecording != after.isRecording ||
                          before.metrics != after.metrics ||
                          before.statsExpanded != after.statsExpanded,
                      builder: (context, state) => !state.isRecording
                          ? const SizedBox.shrink()
                          : Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight:
                                      constraints.maxHeight *
                                      (state.statsExpanded ? 0.35 : 0.25),
                                ),
                                child: RecordingStatsPanel(
                                  metrics: state.metrics,
                                  expanded: state.statsExpanded,
                                  onToggle: cubit.toggleStats,
                                ),
                              ),
                            ),
                    ),
                    const _RecordButton(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _zoom(double delta) {
    if (!_ready) return;
    final camera = _controller.camera;
    _controller.move(
      camera.center,
      (camera.zoom + delta).clamp(widget.config.minZoom, widget.config.maxZoom),
    );
  }
}

class _MapControls extends StatelessWidget {
  const _MapControls({
    required this.horizontal,
    required this.onZoom,
    required this.onCenter,
  });
  final bool horizontal;
  final ValueChanged<double> onZoom;
  final VoidCallback onCenter;

  @override
  Widget build(BuildContext context) {
    final center = MapSurface(
      child: BlocSelector<MapCubit, MapState, bool>(
        selector: (state) => state.centered,
        builder: (context, centered) => IconButton(
          tooltip: 'Center on location',
          isSelected: centered,
          icon: Icon(
            centered ? Icons.navigation : Icons.near_me_outlined,
            color: centered ? AppTheme.route : AppTheme.ink,
            size: 28,
          ),
          onPressed: onCenter,
        ),
      ),
    );
    final zoom = MapSurface(
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Zoom in',
            icon: const Icon(Icons.add, size: 30),
            onPressed: () => onZoom(1),
          ),
          if (!horizontal) const SizedBox(width: 32, child: Divider(height: 1)),
          IconButton(
            tooltip: 'Zoom out',
            icon: const Icon(Icons.remove, size: 30),
            onPressed: () => onZoom(-1),
          ),
        ],
      ),
    );
    return BlocSelector<MapCubit, MapState, bool>(
      selector: (state) => state.isRecording,
      builder: (context, recording) => Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          center,
          SizedBox(width: horizontal ? 12 : 0, height: horizontal ? 0 : 24),
          zoom,
          if (recording) ...[
            SizedBox(width: horizontal ? 12 : 0, height: horizontal ? 0 : 24),
            const MapPhotoButton(),
          ],
        ],
      ),
    );
  }
}

class _RecordButton extends StatelessWidget {
  const _RecordButton();

  @override
  Widget build(BuildContext context) => BlocBuilder<MapCubit, MapState>(
    buildWhen: (before, after) =>
        (before.location == null) != (after.location == null) ||
        before.isRecording != after.isRecording ||
        before.recordingAction != after.recordingAction ||
        before.photoBusy != after.photoBusy,
    builder: (context, state) {
      final background = state.isRecording ? Colors.white : AppTheme.coral;
      final foreground = state.isRecording
          ? const Color(0xFFBD3942)
          : Colors.white;
      final label = state.recordingAction == RecordingAction.stop
          ? 'Saving route...'
          : state.isRecording
          ? 'Stop recording'
          : 'Record route';
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: background,
            foregroundColor: foreground,
            disabledBackgroundColor: background,
            disabledForegroundColor: state.recordingBusy
                ? foreground
                : foreground.withValues(alpha: 0.65),
            elevation: 3,
            shadowColor: const Color(0x26000000),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
          onPressed:
              state.location == null || state.recordingBusy || state.photoBusy
              ? null
              : () {
                  final cubit = context.read<MapCubit>();
                  unawaited(
                    state.isRecording
                        ? cubit.stopRecording()
                        : cubit.startRecording(),
                  );
                },
          icon: state.isRecording
              ? RecordingIndicator(pulsing: !state.recordingBusy)
              : const Icon(Icons.play_arrow),
          label: Text(label, textAlign: TextAlign.center),
        ),
      );
    },
  );
}

class _MapError extends StatelessWidget {
  const _MapError();

  @override
  Widget build(BuildContext context) => BlocBuilder<MapCubit, MapState>(
    buildWhen: (before, after) =>
        before.error != after.error || before.tileError != after.tileError,
    builder: (context, state) {
      final message =
          state.error ??
          (state.tileError ? 'Map tiles could not be loaded.' : null);
      if (message == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.only(top: 12),
        child: MapSurface(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: AppTheme.coral),
                const SizedBox(width: 12),
                Expanded(
                  child: Tooltip(
                    message: message,
                    child: Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Retry',
                  icon: const Icon(Icons.refresh),
                  onPressed: () {
                    final cubit = context.read<MapCubit>();
                    if (state.error != null) {
                      unawaited(cubit.retry());
                    } else {
                      cubit.retryTiles();
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

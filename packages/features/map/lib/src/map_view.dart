import 'dart:async';
import 'dart:math' as math;

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:forui/forui.dart';
import 'package:latlong2/latlong.dart';

import 'config.dart';
import 'center_location_icon.dart';
import 'extensions.dart';
import 'map_app_bar.dart';
import 'map_cubit.dart';
import 'map_follow_motion.dart';
import 'map_state.dart';
import 'map_photo_controls.dart';
import 'last_route_notice.dart';
import 'route_trace.dart';
import 'recording_stats_panel.dart';
import 'recording_indicator.dart';

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.config,
    required this.onRoutesRequested,
    this.onRouteCompleted,
    this.onExploreRequested,
  });
  final MapConfig config;
  final VoidCallback onRoutesRequested;
  final ValueChanged<int>? onRouteCompleted;
  final VoidCallback? onExploreRequested;

  @override
  Widget build(BuildContext context) => BlocListener<MapCubit, MapState>(
    listenWhen: (before, after) =>
        before.completedRouteId != after.completedRouteId &&
        after.completedRouteId != null,
    listener: (context, state) =>
        onRouteCompleted?.call(state.completedRouteId!),
    child: Scaffold(
      body: _MapCanvas(
        config: config,
        onRoutesRequested: onRoutesRequested,
        onExploreRequested: onExploreRequested,
      ),
    ),
  );
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({
    required this.config,
    required this.onRoutesRequested,
    this.onExploreRequested,
  });
  final MapConfig config;
  final VoidCallback onRoutesRequested;
  final VoidCallback? onExploreRequested;

  @override
  State<_MapCanvas> createState() => _MapCanvasState();
}

class _MapCanvasState extends State<_MapCanvas> with TickerProviderStateMixin {
  final _controller = MapController();
  late final LocationMotion _locationMotion;
  late final HeadingMotion _headingMotion;
  late final MapFollowMotion _followMotion;
  bool _ready = false;
  bool _animateLocation = true;

  @override
  void initState() {
    super.initState();
    _locationMotion = LocationMotion(vsync: this);
    _headingMotion = HeadingMotion(
      vsync: this,
      heading: _locationMotion.heading,
    );
    _followMotion = MapFollowMotion(
      vsync: this,
      controller: _controller,
      position: _locationMotion,
      heading: _headingMotion,
      defaultZoom: widget.config.defaultZoom,
    );
    if (context.read<MapCubit>().state.location case final location?) {
      _locationMotion.moveTo(
        location.toLatLng(),
        timestamp: location.timestamp,
        isStationary: location.isStationary,
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
    _headingMotion.enabled = _animateLocation;
    _followMotion.enabled = _animateLocation;
    if (context.read<MapCubit>().state.location case final location?
        when !_animateLocation) {
      _locationMotion.moveTo(
        location.toLatLng(),
        timestamp: location.timestamp,
        isStationary: location.isStationary,
        animate: false,
      );
    }
  }

  @override
  void dispose() {
    _followMotion.dispose();
    _headingMotion.dispose();
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
          before.centered != after.centered ||
          before.orientation != after.orientation,
      listener: (context, state) {
        if (state.location case final location?) {
          _locationMotion.moveTo(
            location.toLatLng(),
            timestamp: location.timestamp,
            isStationary: location.isStationary,
            animate: _animateLocation,
          );
        }
        _followMotion.update(
          following: state.centered,
          courseUp: state.orientation == MapOrientation.courseUp,
        );
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
                  _followMotion.attach(
                    following: cubit.state.centered,
                    courseUp:
                        cubit.state.orientation == MapOrientation.courseUp,
                  );
                },
                onPositionChanged: (camera, hasGesture) {
                  if (hasGesture) _releaseFollow();
                },
                onMapEvent: (event) {
                  if (event is MapEventMoveStart ||
                      event is MapEventRotateStart ||
                      (event is MapEventRotate &&
                          (event.source == MapEventSource.onMultiFinger ||
                              event.source ==
                                  MapEventSource.cursorKeyboardRotation))) {
                    _releaseFollow();
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
                      before.walk != after.walk ||
                      before.isRecording != after.isRecording,
                  builder: (context, state) =>
                      state.walk == null || !state.isRecording
                      ? const SizedBox.shrink()
                      : PlannedRouteLayer(
                          plan: state.walk!.plan,
                          reached: state.walk!.reached,
                        ),
                ),
                BlocBuilder<MapCubit, MapState>(
                  buildWhen: (before, after) =>
                      before.points != after.points ||
                      before.isRecording != after.isRecording ||
                      before.lastRouteHidden != after.lastRouteHidden,
                  builder: (context, state) => !state.showsRoute
                      ? const SizedBox.shrink()
                      : RouteTrace(
                          points: state.points,
                          isRecording: state.isRecording,
                          motion: _locationMotion,
                          muted: state.showsLastRoute,
                        ),
                ),
                CurrentLocationLayer.withHeadingMotion(
                  position: _locationMotion,
                  headingMotion: _headingMotion,
                ),
                BlocSelector<MapCubit, MapState, List<RoutePhotoDM>>(
                  selector: (state) =>
                      state.showsRoute ? state.photos : const [],
                  builder: (context, photos) =>
                      RoutePhotoMarkers(photos: photos),
                ),
                BlocBuilder<MapCubit, MapState>(
                  buildWhen: (before, after) =>
                      before.points != after.points ||
                      before.isRecording != after.isRecording ||
                      before.lastRouteHidden != after.lastRouteHidden,
                  builder: (context, state) {
                    final points = state.points.where(
                      (point) => point.hasValidCoordinates,
                    );
                    return !state.showsRoute || points.length < 2
                        ? const SizedBox.shrink()
                        : MarkerLayer(
                            key: const ValueKey('route-start-layer'),
                            markers: [
                              RecordedRouteMarker.start(
                                point: points.first.toLatLng(),
                                opacity: state.showsLastRoute ? 0.55 : 1,
                              ),
                              if (state.showsLastRoute)
                                RecordedRouteMarker.end(
                                  point: points.last.toLatLng(),
                                  opacity: 0.55,
                                ),
                            ],
                          );
                  },
                ),
              ],
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(0, 16, 0, 32),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Panels may grow or scroll, but must not move the map controls.
                final horizontal = constraints.maxHeight < 640;
                final controlsSize = horizontal
                    ? _MapControls.horizontalSize
                    : _MapControls.verticalSize;
                final controlsTop =
                    (constraints.maxHeight * (horizontal ? 0.43 : 0.5) -
                            controlsSize.height / 2)
                        .roundToDouble();
                final footerTop = controlsTop + controlsSize.height + 12;
                return Stack(
                  children: [
                    Positioned.fill(
                      child: Column(
                        children: [
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxHeight: math.min(
                                constraints.maxHeight * 0.36,
                                controlsTop - 12,
                              ),
                            ),
                            child: SingleChildScrollView(
                              // Keep the surface's shadow inside the clipped viewport.
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: [
                                  MapAppBar(
                                    onPageChange: widget.onRoutesRequested,
                                    onExploreRequested:
                                        widget.onExploreRequested,
                                  ),
                                  const _MapError(),
                                  const MapPhotoError(),
                                  BlocBuilder<MapCubit, MapState>(
                                    buildWhen: (before, after) =>
                                        before.walk != after.walk ||
                                        before.isRecording !=
                                            after.isRecording ||
                                        before.location != after.location,
                                    builder: (_, state) =>
                                        state.walk == null || !state.isRecording
                                        ? const SizedBox.shrink()
                                        : Padding(
                                            padding: const EdgeInsets.only(
                                              top: 12,
                                            ),
                                            child: MapSurface(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  12,
                                                ),
                                                child: WalkSummary(
                                                  progress: state.walk!,
                                                  location: state.location,
                                                ),
                                              ),
                                            ),
                                          ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomLeft,
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(16, 0, 0, 8),
                                child: MapSurface(
                                  child: MapAttributionButton(
                                    config: widget.config,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                maxHeight: constraints.maxHeight - footerTop,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Flexible(
                                    child: BlocBuilder<MapCubit, MapState>(
                                      buildWhen: (before, after) =>
                                          before.isRecording !=
                                              after.isRecording ||
                                          before.metrics != after.metrics ||
                                          before.showsLastRoute !=
                                              after.showsLastRoute ||
                                          before.statsExpanded !=
                                              after.statsExpanded,
                                      builder: (context, state) =>
                                          !state.isRecording
                                          ? AppFadeSwitcher(
                                              value: state.showsLastRoute,
                                              child: state.showsLastRoute
                                                  ? Padding(
                                                      padding:
                                                          const EdgeInsets.only(
                                                            bottom: 12,
                                                          ),
                                                      child: LastRouteNotice(
                                                        onHide:
                                                            cubit.hideLastRoute,
                                                      ),
                                                    )
                                                  : const SizedBox.shrink(),
                                            )
                                          : Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 12,
                                              ),
                                              child: ConstrainedBox(
                                                constraints: BoxConstraints(
                                                  maxHeight:
                                                      constraints.maxHeight *
                                                      (state.statsExpanded
                                                          ? 0.35
                                                          : 0.25),
                                                ),
                                                child: RecordingStatsPanel(
                                                  metrics: state.metrics,
                                                  expanded: state.statsExpanded,
                                                  onToggle: cubit.toggleStats,
                                                ),
                                              ),
                                            ),
                                    ),
                                  ),
                                  const _RecordButton(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      right: 16,
                      top: controlsTop,
                      width: controlsSize.width,
                      height: controlsSize.height,
                      child: _MapControls(
                        horizontal: horizontal,
                        onZoom: _zoom,
                        onCenter: cubit.cycleFollowMode,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _releaseFollow() {
    final cubit = context.read<MapCubit>();
    if (!cubit.state.centered) return;
    _followMotion.update(
      following: false,
      courseUp: cubit.state.orientation == MapOrientation.courseUp,
    );
    cubit.setCentered(false);
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

  static const horizontalSize = Size(48 + 12 + 97 + 12 + 48, 48);
  static const verticalSize = Size(48, 48 + 24 + 97 + 24 + 48);

  @override
  Widget build(BuildContext context) {
    final center = MapSurface(
      child: BlocBuilder<MapCubit, MapState>(
        buildWhen: (before, after) =>
            before.centered != after.centered ||
            before.orientation != after.orientation,
        builder: (context, state) => Semantics(
          value: !state.centered
              ? 'Free map'
              : state.orientation == MapOrientation.courseUp
              ? 'Course up'
              : 'North up',
          child: AppIconButton(
            key: const ValueKey('map-follow-button'),
            tooltip: state.followActionLabel,
            selected: state.centered,
            icon: CenterLocationIcon(
              centered: state.centered,
              courseUp: state.orientation == MapOrientation.courseUp,
            ),
            onPressed: onCenter,
          ),
        ),
      ),
    );
    // The shared surface clips the outer corners; the divider edges stay square.
    final zoom = MapSurface(
      child: Flex(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIconButton(
            tooltip: 'Zoom in',
            square: true,
            icon: const Icon(FLucideIcons.plus),
            onPressed: () => onZoom(1),
          ),
          if (horizontal)
            const SizedBox(height: 32, child: VerticalDivider(width: 1))
          else
            const SizedBox(width: 32, child: Divider(height: 1)),
          AppIconButton(
            tooltip: 'Zoom out',
            square: true,
            icon: const Icon(FLucideIcons.minus),
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
          SizedBox(width: horizontal ? 12 : 0, height: horizontal ? 0 : 24),
          // The photo action must not re-center or resize the existing controls.
          SizedBox.square(
            dimension: 48,
            child: recording ? const MapPhotoButton() : null,
          ),
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
      final foreground = state.isRecording ? AppTheme.coral : Colors.white;
      final label = state.recordingAction == RecordingAction.stop
          ? 'Saving route...'
          : state.isRecording
          ? 'Stop recording'
          : 'Record route';
      return SizedBox(
        width: double.infinity,
        child: MapSurface(
          child: AppButton(
            variant: state.isRecording
                ? FButtonVariant.ghost
                : FButtonVariant.primary,
            foreground: state.location == null && !state.recordingBusy
                ? foreground.withValues(alpha: 0.65)
                : foreground,
            preserveDisabledAppearance: state.recordingBusy,
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
            prefix: state.isRecording
                ? RecordingIndicator(pulsing: !state.recordingBusy)
                : const Icon(FLucideIcons.circle, size: 18),
            label: label,
          ),
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
        before.error != after.error ||
        before.tileError != after.tileError ||
        before.walkError != after.walkError,
    builder: (context, state) {
      final message =
          state.error ??
          state.walkError ??
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
                AppIconButton(
                  tooltip: 'Retry',
                  icon: const Icon(FLucideIcons.refreshCw),
                  onPressed: () {
                    final cubit = context.read<MapCubit>();
                    if (state.error != null) {
                      unawaited(cubit.retry());
                    } else if (state.walkError != null) {
                      unawaited(cubit.retryWalk());
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

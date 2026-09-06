import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config.dart';
import 'extensions.dart';
import 'location_motion.dart';
import 'map_app_bar.dart';
import 'map_cubit.dart';
import 'map_state.dart';

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.config,
    required this.onRoutesRequested,
  });

  final MapConfig config;
  final VoidCallback onRoutesRequested;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: MapAppBar(onPageChange: onRoutesRequested),
    body: Column(
      children: [
        BlocBuilder<MapCubit, MapState>(
          buildWhen: (before, after) =>
              before.error != after.error ||
              before.tileError != after.tileError,
          builder: (context, state) {
            final message =
                state.error ??
                (state.tileError ? 'Map tiles could not be loaded.' : null);
            if (message == null) return const SizedBox.shrink();
            return MaterialBanner(
              content: Text(message),
              actions: [
                TextButton(
                  onPressed: () {
                    final cubit = context.read<MapCubit>();
                    if (state.error != null) {
                      unawaited(cubit.retry());
                    } else {
                      cubit.retryTiles();
                    }
                  },
                  child: const Text('Retry'),
                ),
              ],
            );
          },
        ),
        Expanded(child: _MapCanvas(config: config)),
      ],
    ),
  );
}

class _MapCanvas extends StatefulWidget {
  const _MapCanvas({required this.config});
  final MapConfig config;

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
      _locationMotion.moveTo(location.toLatLng(), animate: false);
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
      _locationMotion.moveTo(location.toLatLng(), animate: false);
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
            animate: _animateLocation,
          );
        }
        _center();
      },
      child: Stack(
        children: [
          FlutterMap(
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
                builder: (context, generation) =>
                    _MapTiles(key: ValueKey(generation), config: widget.config),
              ),
              BlocBuilder<MapCubit, MapState>(
                buildWhen: (before, after) => before.points != after.points,
                builder: (context, state) => state.points.length < 2
                    ? const SizedBox.shrink()
                    : PolylineLayer(
                        polylines: [
                          Polyline(
                            points: state.points
                                .map((p) => p.toLatLng())
                                .toList(),
                            color: Theme.of(context).colorScheme.primary,
                            strokeWidth: 4,
                          ),
                        ],
                      ),
              ),
              ValueListenableBuilder<LatLng?>(
                valueListenable: _locationMotion,
                builder: (context, point, child) => MarkerLayer(
                  markers: [
                    if (point != null)
                      Marker(
                        point: point,
                        width: 24,
                        height: 24,
                        child: Icon(
                          Icons.my_location,
                          size: 24,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                  ],
                ),
              ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    widget.config.attribution,
                    onTap: () => unawaited(
                      launchUrl(Uri.parse(widget.config.attributionUrl)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            right: 12,
            top: 12,
            child: Material(
              elevation: 2,
              borderRadius: BorderRadius.circular(8),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Zoom in',
                    icon: const Icon(Icons.add),
                    onPressed: () => _zoom(1),
                  ),
                  IconButton(
                    tooltip: 'Zoom out',
                    icon: const Icon(Icons.remove),
                    onPressed: () => _zoom(-1),
                  ),
                  BlocSelector<MapCubit, MapState, bool>(
                    selector: (state) => state.centered,
                    builder: (context, centered) => IconButton(
                      tooltip: 'Center on location',
                      isSelected: centered,
                      icon: const Icon(Icons.my_location),
                      onPressed: () {
                        cubit.setCentered(true);
                        _center();
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 32,
            left: 16,
            right: 16,
            child: SafeArea(
              top: false,
              child: Center(
                child: BlocBuilder<MapCubit, MapState>(
                  builder: (context, state) => FilledButton.icon(
                    onPressed: state.location == null || state.recordingBusy
                        ? null
                        : () => unawaited(
                            state.isRecording
                                ? cubit.stopRecording()
                                : cubit.startRecording(),
                          ),
                    icon: state.recordingBusy
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            state.isRecording
                                ? Icons.stop
                                : Icons.fiber_manual_record,
                          ),
                    label: Text(
                      state.isRecording ? 'Stop recording' : 'Record route',
                    ),
                  ),
                ),
              ),
            ),
          ),
          BlocSelector<MapCubit, MapState, bool>(
            selector: (state) => state.locationLoading,
            builder: (context, loading) => loading
                ? const Align(
                    alignment: Alignment.topLeft,
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: SizedBox.square(
                        dimension: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
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

class _MapTiles extends StatefulWidget {
  const _MapTiles({super.key, required this.config});
  final MapConfig config;

  @override
  State<_MapTiles> createState() => _MapTilesState();
}

class _MapTilesState extends State<_MapTiles> {
  late final _provider = NetworkTileProvider();

  @override
  Widget build(BuildContext context) => TileLayer(
    urlTemplate: widget.config.urlTemplate,
    userAgentPackageName: widget.config.userAgentPackageName,
    tileProvider: _provider,
    maxNativeZoom: 19,
    panBuffer: 0,
    keepBuffer: 1,
    evictErrorTileStrategy: EvictErrorTileStrategy.dispose,
    errorTileCallback: (tile, error, stack) {
      scheduleMicrotask(() {
        if (mounted) context.read<MapCubit>().tilesFailed();
      });
    },
  );
}

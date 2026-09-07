import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'explore_cubit.dart';
import 'explore_state.dart';
import 'planning_settings.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.config, required this.onBack});
  final MapTileConfig config;
  final VoidCallback onBack;
  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView> {
  static const _panelHeightFactor = 0.52;
  final _map = MapController();
  bool _ready = false;
  bool _located = false;
  bool _tilesFailed = false;
  int _tilesGeneration = 0;
  RouteEndpoint? _picking;

  void _pick(RouteEndpoint endpoint) {
    final cubit = context.read<ExploreCubit>();
    if (!_ready || cubit.state.starting || cubit.state.recording) return;
    cubit.cancelGeneration();
    setState(() => _picking = _picking == endpoint ? null : endpoint);
  }

  void _cancelPick() {
    if (_picking != null) setState(() => _picking = null);
  }

  void _placePoint(LatLng point) {
    final cubit = context.read<ExploreCubit>();
    if (_picking == null ||
        cubit.state.mode != RoutePlanMode.pointToPoint ||
        cubit.state.showProgress ||
        cubit.state.starting ||
        cubit.state.recording) {
      return;
    }
    final selected = GeoPoint(point.latitude, point.longitude);
    if (_picking == RouteEndpoint.start) {
      cubit.selectStart(selected);
    } else {
      cubit.selectEnd(selected);
    }
    _cancelPick();
  }

  @override
  void dispose() {
    _map.dispose();
    super.dispose();
  }

  void _loadCells() {
    if (!_ready) return;
    final bounds = _map.camera.visibleBounds;
    context.read<ExploreCubit>().loadCells(
      south: bounds.south,
      north: bounds.north,
      west: bounds.west,
      east: bounds.east,
    );
  }

  void _center(ExploreState state) {
    if (!_ready) return;
    if (state.plan case final plan? when !state.showProgress) {
      _map.fitCamera(
        CameraFit.bounds(
          bounds: LatLngBounds.fromPoints(
            plan.points.map((p) => p.latLng).toList(),
          ),
          padding: EdgeInsets.fromLTRB(
            32,
            plan.isLoop ? 32 : 64,
            32,
            _map.camera.nonRotatedSize.height * _panelHeightFactor + 32,
          ),
          maxZoom: 17,
        ),
      );
    } else if (state.location case final point?) {
      // Center in the area above the panel, including its outer margin.
      _map.move(
        LatLng(point.latitude, point.longitude),
        15,
        offset: Offset(
          0,
          -_map.camera.nonRotatedSize.height * _panelHeightFactor / 2 - 8,
        ),
      );
    }
    _loadCells();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocConsumer<ExploreCubit, ExploreState>(
    listenWhen: (before, after) =>
        before.startedRouteId != after.startedRouteId ||
        before.mode != after.mode ||
        before.showProgress != after.showProgress ||
        before.starting != after.starting ||
        before.recording != after.recording ||
        (before.location == null && after.location != null),
    listener: (context, state) {
      if (state.startedRouteId != null) {
        widget.onBack();
        return;
      }
      if (state.mode != RoutePlanMode.pointToPoint ||
          state.showProgress ||
          state.starting ||
          state.recording) {
        _cancelPick();
      }
      if (!_located && state.location != null && _picking == null) {
        _located = true;
        _center(state);
      }
    },
    builder: (context, state) {
      final cubit = context.read<ExploreCubit>();
      final location = state.location;
      final start =
          state.start ??
          (location == null
              ? null
              : GeoPoint(location.latitude, location.longitude));
      final end = state.end;
      return PopScope(
        canPop: _picking == null,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _picking != null) _cancelPick();
        },
        child: Scaffold(
          appBar: AppBar(
            title: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _picking != null
                    ? _picking == RouteEndpoint.start
                          ? 'CHOOSE START'
                          : 'CHOOSE FINISH'
                    : state.showProgress
                    ? 'EXPLORATION'
                    : 'PLAN A WALK',
              ),
            ),
            leading: IconButton(
              tooltip: _picking == null ? 'Back' : 'Cancel point selection',
              onPressed: state.starting
                  ? null
                  : _picking != null
                  ? _cancelPick
                  : widget.onBack,
              icon: Icon(_picking == null ? Icons.arrow_back : Icons.close),
            ),
            actions: [
              IconButton(
                tooltip: 'Center map',
                onPressed: () => _center(state),
                icon: const Icon(Icons.my_location),
              ),
            ],
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: state.showProgress ? 1 : 0,
            onDestinationSelected: (index) => cubit.showProgress(index == 1),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.route_outlined),
                label: 'Plan a walk',
              ),
              NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                label: 'Exploration',
              ),
            ],
          ),
          body: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned.fill(
                  child: FlutterMap(
                    mapController: _map,
                    options: MapOptions(
                      initialCenter: state.location == null
                          ? const LatLng(0, 0)
                          : LatLng(
                              state.location!.latitude,
                              state.location!.longitude,
                            ),
                      initialZoom: state.location == null ? 2 : 15,
                      onMapReady: () {
                        _ready = true;
                        _center(cubit.state);
                      },
                      onPositionChanged: (_, _) => _loadCells(),
                      onTap: (_, point) => _placePoint(point),
                    ),
                    children: [
                      MapTiles(
                        key: ValueKey(_tilesGeneration),
                        config: widget.config,
                        onError: () {
                          if (mounted && !_tilesFailed) {
                            setState(() => _tilesFailed = true);
                          }
                        },
                      ),
                      ExploredAreasLayer(cells: state.cells),
                      if (!state.showProgress && state.plan != null)
                        PlannedRouteLayer(plan: state.plan!),
                      if (!state.showProgress &&
                          state.mode == RoutePlanMode.pointToPoint &&
                          state.plan == null)
                        MarkerLayer(
                          markers: [
                            if (start != null)
                              RouteEndpointMarker(point: start, letter: 'A'),
                            if (end != null)
                              RouteEndpointMarker(point: end, letter: 'B'),
                          ],
                        ),
                      if (state.location case final location?)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: LatLng(
                                location.latitude,
                                location.longitude,
                              ),
                              width: 28,
                              height: 28,
                              child: const Icon(
                                Icons.my_location,
                                color: AppTheme.coral,
                                applyTextScaling: false,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: MapSurface(
                      child: MapAttributionButton(config: widget.config),
                    ),
                  ),
                ),
                if (_tilesFailed)
                  Align(
                    alignment: Alignment.topRight,
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: MapSurface(
                        child: IconButton(
                          tooltip: 'Retry map tiles',
                          icon: const Icon(Icons.cloud_off_outlined),
                          onPressed: () => setState(() {
                            _tilesGeneration++;
                            _tilesFailed = false;
                          }),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    minimum: const EdgeInsets.all(16),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: constraints.maxHeight * _panelHeightFactor,
                        maxWidth: 600,
                      ),
                      child: MapSurface(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_picking == null &&
                                  state.visibleError != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      state.visibleError!,
                                      style: TextStyle(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .error,
                                      ),
                                    ),
                                  ),
                                ),
                              if (state.showProgress)
                                _ProgressContent(
                                  profile: state.profile,
                                  onRefresh: cubit.refreshProfile,
                                )
                              else
                                _PlanContent(
                                  state: state,
                                  onFit: () => _center(cubit.state),
                                  onPick: _pick,
                                  picking: _picking,
                                  onCancelPick: _cancelPick,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _PlanContent extends StatelessWidget {
  const _PlanContent({
    required this.state,
    required this.onFit,
    required this.onPick,
    required this.picking,
    required this.onCancelPick,
  });
  final ExploreState state;
  final VoidCallback onFit;
  final ValueChanged<RouteEndpoint> onPick;
  final RouteEndpoint? picking;
  final VoidCallback onCancelPick;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExploreCubit>();
    final plan = state.plan;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        PlanningSettings(
          state: state,
          picking: picking,
          onPick: onPick,
          onCancelPick: onCancelPick,
        ),
        if (state.recording)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('A recording is already in progress.'),
          ),
        if (state.generating) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: LinearProgressIndicator(
              semanticsLabel: state.locating
                  ? 'Getting current location'
                  : 'Generating walking route',
            ),
          ),
          if (state.locating)
            Semantics(
              liveRegion: true,
              child: const Text('Getting current location...'),
            ),
          TextButton.icon(
            onPressed: cubit.cancelGeneration,
            icon: const Icon(Icons.close),
            label: const Text('Cancel'),
          ),
        ] else if (plan == null) ...[
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed:
                picking != null ||
                    state.recording ||
                    state.starting ||
                    (state.mode == RoutePlanMode.pointToPoint &&
                        state.end == null)
                ? null
                : () async {
                    await cubit.generate();
                    if (context.mounted && cubit.state.plan != null) onFit();
                  },
            icon: const Icon(Icons.route),
            label: const Text('Generate route'),
          ),
        ] else ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text('${(plan.distance / 1000).toStringAsFixed(2)} km'),
              Text('About ${plan.estimatedDuration.inMinutes} min'),
              Text(
                '${plan.checkpoints.length} ${plan.checkpoints.length == 1 ? 'checkpoint' : 'checkpoints'}',
              ),
              Text('Up to ${state.newAreas} new areas'),
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: picking != null || state.starting || state.recording
                ? null
                : cubit.start,
            icon: const Icon(Icons.play_arrow),
            label: Text(
              state.locating
                  ? 'Getting current location...'
                  : state.starting
                  ? 'Starting walk'
                  : 'Start walk',
            ),
          ),
          if (plan.isLoop)
            TextButton.icon(
              onPressed: state.starting || state.recording
                  ? null
                  : () async {
                      await cubit.generate();
                      if (context.mounted && cubit.state.plan != null) onFit();
                    },
              icon: const Icon(Icons.refresh),
              label: const Text('Generate another'),
            ),
        ],
      ],
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({required this.profile, required this.onRefresh});
  final ExplorationProfile profile;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Expanded(
            child: Text(
              'Your discoveries',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          IconButton(
            tooltip: 'Refresh progress',
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
        ],
      ),
      Wrap(
        spacing: 24,
        runSpacing: 8,
        children: [
          Text(
            '${profile.cells} ${profile.cells == 1 ? 'area' : 'areas'} explored',
          ),
          Text(
            '${profile.completedWalks} ${profile.completedWalks == 1 ? 'walk' : 'walks'} completed',
          ),
        ],
      ),
      const Divider(height: 24),
      for (final achievement in ExplorationAchievement.values)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(
            profile.achievements.contains(achievement)
                ? Icons.check_circle_outline
                : Icons.lock_outline,
            color: profile.achievements.contains(achievement)
                ? explorationColor
                : AppTheme.muted,
          ),
          title: Text(achievement.title),
          subtitle: Text(achievement.description),
        ),
    ],
  );
}

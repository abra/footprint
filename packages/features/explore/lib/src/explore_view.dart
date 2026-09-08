import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:forui/forui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'explore_cubit.dart';
import 'explore_state.dart';
import 'plan_preview.dart';
import 'planning_settings.dart';

class ExploreView extends StatefulWidget {
  const ExploreView({super.key, required this.config, required this.onBack});
  final MapTileConfig config;
  final VoidCallback onBack;
  @override
  State<ExploreView> createState() => _ExploreViewState();
}

class _ExploreViewState extends State<ExploreView>
    with SingleTickerProviderStateMixin {
  static const _maxPanelHeightFactor = 0.52;
  static const _largeTextPanelHeightFactor = 0.65;
  final _panelKey = GlobalKey();
  final _map = MapController();
  late final LocationMotion _locationMotion;
  bool _animateLocation = true;
  bool _ready = false;
  bool _located = false;
  bool _tilesFailed = false;
  int _tilesGeneration = 0;
  RouteEndpoint? _picking;
  bool _editingPlan = true;

  @override
  void initState() {
    super.initState();
    _locationMotion = LocationMotion(vsync: this);
    final location = context.read<ExploreCubit>().state.location;
    _located = location != null;
    _moveLocation(location, animate: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _animateLocation =
        !MediaQuery.disableAnimationsOf(context) &&
        TickerMode.valuesOf(context).enabled;
    if (!_animateLocation) {
      _moveLocation(
        context.read<ExploreCubit>().state.location,
        animate: false,
      );
    }
  }

  void _moveLocation(LocationDM? location, {required bool animate}) {
    if (location == null) return;
    _locationMotion.moveTo(
      LatLng(location.latitude, location.longitude),
      timestamp: location.timestamp,
      isStationary: location.isStationary,
      animate: animate,
    );
  }

  void _showPlan() {
    setState(() => _editingPlan = false);
    final state = context.read<ExploreCubit>().state;
    if (!state.showProgress) _center(state);
  }

  void _editPlan() {
    context.read<ExploreCubit>().cancelGeneration();
    setState(() => _editingPlan = true);
  }

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
    _locationMotion.dispose();
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
    // Fit against the panel after the current state has been laid out.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final panel = _panelKey.currentContext?.findRenderObject();
      final panelHeight = panel is RenderBox && panel.hasSize
          ? panel.size.height
          : 0.0;
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
              panelHeight + 32,
            ),
            maxZoom: 17,
          ),
        );
      } else if (state.location case final point?) {
        // Center in the area above the panel, including its outer margin.
        _map.move(
          _locationMotion.value ?? LatLng(point.latitude, point.longitude),
          15,
          offset: Offset(0, -panelHeight / 2 - 8),
        );
      }
      _loadCells();
    });
    WidgetsBinding.instance.ensureVisualUpdate();
  }

  @override
  Widget build(
    BuildContext context,
  ) => BlocListener<ExploreCubit, ExploreState>(
    listenWhen: (before, after) => before.location != after.location,
    listener: (context, state) =>
        _moveLocation(state.location, animate: _animateLocation),
    child: BlocConsumer<ExploreCubit, ExploreState>(
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
                            ? 'Choose start'
                            : 'Choose destination'
                      : state.showProgress
                      ? 'Exploration'
                      : state.plan != null && !_editingPlan
                      ? 'Your walk'
                      : 'Plan route',
                ),
              ),
              leading: AppIconButton(
                tooltip: _picking == null ? 'Back' : 'Cancel point selection',
                onPressed: state.starting
                    ? null
                    : _picking != null
                    ? _cancelPick
                    : widget.onBack,
                icon: Icon(
                  _picking == null ? FLucideIcons.arrowLeft : FLucideIcons.x,
                ),
              ),
              actions: [
                AppIconButton(
                  tooltip: 'Center map',
                  onPressed: () => _center(state),
                  icon: const Icon(FLucideIcons.locateFixed),
                ),
              ],
            ),
            bottomNavigationBar: FBottomNavigationBar(
              index: state.showProgress ? 1 : 0,
              onChange: (index) => cubit.showProgress(index == 1),
              children: const [
                FBottomNavigationBarItem(
                  icon: Icon(FLucideIcons.route),
                  label: Text('Plan a walk'),
                ),
                FBottomNavigationBarItem(
                  icon: Icon(FLucideIcons.compass),
                  label: Text('Exploration'),
                ),
              ],
            ),
            body: LayoutBuilder(
              builder: (context, constraints) {
                final largeTextPortrait =
                    constraints.maxHeight > constraints.maxWidth &&
                    MediaQuery.textScalerOf(context).scale(1) > 1.4;
                final showingPreview =
                    state.plan != null && !_editingPlan && !state.showProgress;
                final panelHeightFactor =
                    constraints.maxWidth > constraints.maxHeight
                    ? 0.6
                    : largeTextPortrait
                    ? showingPreview
                          ? 0.7
                          : _largeTextPanelHeightFactor
                    : _maxPanelHeightFactor;
                return Stack(
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
                          if (state.showProgress)
                            ExploredAreasLayer(cells: state.cells),
                          if (!state.showProgress && state.plan != null)
                            PlannedRouteLayer(plan: state.plan!),
                          if (!state.showProgress &&
                              state.mode == RoutePlanMode.pointToPoint &&
                              state.plan == null)
                            ValueListenableBuilder<LatLng?>(
                              valueListenable: _locationMotion,
                              builder: (context, point, child) => MarkerLayer(
                                markers: [
                                  if (start != null)
                                    RouteEndpointMarker(
                                      point:
                                          state.start == null && point != null
                                          ? GeoPoint(
                                              point.latitude,
                                              point.longitude,
                                            )
                                          : start,
                                      letter: 'A',
                                    ),
                                  if (end != null)
                                    RouteEndpointMarker(
                                      point: end,
                                      letter: 'B',
                                    ),
                                ],
                              ),
                            ),
                          CurrentLocationLayer(
                            position: _locationMotion,
                            heading: _locationMotion.heading,
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
                            child: AppIconButton(
                              tooltip: 'Retry map tiles',
                              icon: const Icon(FLucideIcons.cloudOff),
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
                          key: _panelKey,
                          constraints: BoxConstraints(
                            maxHeight:
                                constraints.maxHeight * panelHeightFactor,
                            maxWidth:
                                constraints.maxWidth > constraints.maxHeight
                                ? 700
                                : 600,
                          ),
                          child: MapSurface(
                            key: const ValueKey('explore-panel'),
                            child: AppFadeSwitcher(
                              value: state.showProgress,
                              child: state.showProgress
                                  ? SingleChildScrollView(
                                      padding: const EdgeInsets.all(16),
                                      child: _ProgressContent(
                                        profile: state.profile,
                                        error: state.visibleError,
                                        onRefresh: cubit.refreshProfile,
                                      ),
                                    )
                                  : _PlanContent(
                                      state: state,
                                      editing:
                                          state.plan == null || _editingPlan,
                                      onShowPlan: _showPlan,
                                      onEdit: _editPlan,
                                      onPick: _pick,
                                      picking: _picking,
                                      onCancelPick: _cancelPick,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    ),
  );
}

class _PlanContent extends StatefulWidget {
  const _PlanContent({
    required this.state,
    required this.editing,
    required this.onShowPlan,
    required this.onEdit,
    required this.onPick,
    required this.picking,
    required this.onCancelPick,
  });
  final ExploreState state;
  final bool editing;
  final VoidCallback onShowPlan;
  final VoidCallback onEdit;
  final ValueChanged<RouteEndpoint> onPick;
  final RouteEndpoint? picking;
  final VoidCallback onCancelPick;

  @override
  State<_PlanContent> createState() => _PlanContentState();
}

class _PlanContentState extends State<_PlanContent> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(covariant _PlanContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.editing != widget.editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _scrollController.hasClients) {
          _scrollController.jumpTo(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Scrollbar(
          controller: _scrollController,
          thumbVisibility: true,
          child: SingleChildScrollView(
            key: const ValueKey('plan-details-scroll'),
            controller: _scrollController,
            child: AppFadeSwitcher(
              value: widget.editing,
              child: _PlanDetails(
                state: widget.state,
                editing: widget.editing,
                onPick: widget.onPick,
                picking: widget.picking,
                onCancelPick: widget.onCancelPick,
              ),
            ),
          ),
        );
        final cubit = context.read<ExploreCubit>();
        final actions = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PlanActions(
              state: widget.state,
              editing: widget.editing,
              onShowPlan: widget.onShowPlan,
              picking: widget.picking,
            ),
            if (!widget.editing) ...[
              const SizedBox(height: 8),
              PlanPreviewTools(
                state: widget.state,
                onEdit: widget.onEdit,
                onClear: cubit.clearPlan,
                onUndo: () {
                  cubit.restorePreviousPreview();
                  widget.onShowPlan();
                },
                onRefreshLocation: cubit.refreshStartLocation,
              ),
            ],
          ],
        );
        // A short, wide panel has room beside the form, not below it.
        if (constraints.maxHeight < 200 && constraints.maxWidth >= 520) {
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 16),
              SizedBox(width: widget.editing ? 260 : 300, child: actions),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(child: details),
            const SizedBox(height: 12),
            actions,
          ],
        );
      },
    ),
  );
}

class _PlanDetails extends StatelessWidget {
  const _PlanDetails({
    required this.state,
    required this.editing,
    required this.onPick,
    required this.picking,
    required this.onCancelPick,
  });
  final ExploreState state;
  final bool editing;
  final ValueChanged<RouteEndpoint> onPick;
  final RouteEndpoint? picking;
  final VoidCallback onCancelPick;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (editing)
        PlanningSettings(
          state: state,
          picking: picking,
          onPick: onPick,
          onCancelPick: onCancelPick,
        )
      else
        PlanPreview(state: state),
      if (picking == null && state.visibleError != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              state.visibleError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      if (state.recording)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text('A recording is already in progress.'),
        ),
      if (state.generating)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: LinearProgressIndicator(
            semanticsLabel: state.locating
                ? 'Getting current location'
                : 'Generating walking route',
          ),
        ),
      if (state.locating && editing)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Semantics(
            liveRegion: true,
            child: const Text('Getting current location...'),
          ),
        ),
    ],
  );
}

class _PlanActions extends StatelessWidget {
  const _PlanActions({
    required this.state,
    required this.editing,
    required this.onShowPlan,
    required this.picking,
  });
  final ExploreState state;
  final bool editing;
  final VoidCallback onShowPlan;
  final RouteEndpoint? picking;

  Future<void> _start(BuildContext context) async {
    final message = await context.read<ExploreCubit>().start();
    if (!context.mounted || message == null) return;
    await showAppActionSheet<void>(
      context,
      title: 'Walk not started',
      message: message,
      actions: const [],
      cancelLabel: 'Close',
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ExploreCubit>();
    final plan = state.plan;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.generating)
          AppButton(
            variant: FButtonVariant.ghost,
            onPressed: cubit.cancelGeneration,
            prefix: const Icon(FLucideIcons.x),
            label: 'Cancel',
          )
        else if (plan == null)
          AppButton(
            onPressed:
                picking != null ||
                    state.recording ||
                    state.starting ||
                    (state.mode == RoutePlanMode.pointToPoint &&
                        state.end == null)
                ? null
                : () async {
                    final generated = await cubit.generate();
                    if (context.mounted && generated) onShowPlan();
                  },
            prefix: const Icon(FLucideIcons.route),
            label: 'Generate route',
          )
        else if (editing)
          AppButton(
            onPressed: picking != null || state.starting || state.recording
                ? null
                : onShowPlan,
            prefix: const Icon(FLucideIcons.map),
            label: 'Show route',
          )
        else
          Row(
            children: [
              Expanded(
                child: AppButton(
                  onPressed:
                      state.startTooFar ||
                          state.locating ||
                          state.starting ||
                          state.recording
                      ? null
                      : () => _start(context),
                  prefix: const Icon(FLucideIcons.play),
                  label: state.starting ? 'Starting walk' : 'Start walk',
                ),
              ),
              if (plan.isLoop) ...[
                const SizedBox(width: 8),
                AppIconButton(
                  onPressed: state.starting || state.recording
                      ? null
                      : () async {
                          final generated = await cubit.generate();
                          if (context.mounted && generated) {
                            onShowPlan();
                          }
                        },
                  icon: const Icon(FLucideIcons.refreshCw),
                  tooltip: 'Generate another',
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _ProgressContent extends StatelessWidget {
  const _ProgressContent({
    required this.profile,
    required this.onRefresh,
    this.error,
  });
  final ExplorationProfile profile;
  final VoidCallback onRefresh;
  final String? error;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (error != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Your discoveries',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
          ),
          AppIconButton(
            tooltip: 'Refresh progress',
            icon: const Icon(FLucideIcons.refreshCw),
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
      AppTileList(
        children: [
          for (final achievement in ExplorationAchievement.values)
            FTile(
              style: const .delta(shape: null),
              prefix: Icon(
                profile.achievements.contains(achievement)
                    ? FLucideIcons.circleCheck
                    : FLucideIcons.lock,
                color: profile.achievements.contains(achievement)
                    ? explorationColor
                    : AppTheme.muted,
              ),
              title: Text(achievement.title, overflow: TextOverflow.visible),
              subtitle: Text(
                achievement.description,
                overflow: TextOverflow.visible,
              ),
            ),
        ],
      ),
    ],
  );
}

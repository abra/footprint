import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';

import 'exception_dialog.dart';
import 'extensions.dart';
import 'map_location_notifier.dart';
import 'map_view_notifier.dart';

class MapView extends StatefulWidget {
  const MapView({
    super.key,
    required this.onPageChange,
  });

  final VoidCallback onPageChange;

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin {
  late AnimatedMapController _animatedMapController;
  late MapViewNotifier _mapViewNotifier;
  late MapLocationNotifier _mapLocationNotifier;

  final _isRouteRecordingStarted = ValueNotifier<bool>(false);
  final _routePoints = ValueNotifier<List<LatLng>>([]); // <>

  @override
  void initState() {
    super.initState();
    _isRouteRecordingStarted.addListener(_handleRouteRecordingStarted);
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = context.locationNotifier;
    _mapViewNotifier = context.viewNotifier;
    _mapLocationNotifier.addListener(_handleMapLocationChanged);
    _mapViewNotifier.addListener(_handleZoomChanged);
  }

  @override
  void dispose() {
    _mapViewNotifier.removeListener(_handleZoomChanged);
    _mapLocationNotifier.removeListener(_handleMapLocationChanged);
    _isRouteRecordingStarted.removeListener(_handleRouteRecordingStarted);
    _animatedMapController.dispose();
    _mapViewNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>> build $runtimeType $hashCode');
    super.build(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _MapAppBar(
        onPageChange: widget.onPageChange,
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _animatedMapController.mapController,
            options: MapOptions(
              interactionOptions: const InteractionOptions(
                pinchZoomWinGestures: InteractiveFlag.pinchZoom,
              ),
              initialZoom: _mapViewNotifier.config.defaultZoom,
              maxZoom: _mapViewNotifier.config.maxZoom,
              minZoom: _mapViewNotifier.config.minZoom,
            ),
            children: [
              ValueListenableBuilder<MapViewState>(
                valueListenable: _mapViewNotifier,
                builder: (BuildContext context, MapViewState viewState, _) {
                  return switch (viewState) {
                    MapViewState() => TileLayer(
                        retinaMode: true,
                        userAgentPackageName: viewState.userAgentPackageName,
                        urlTemplate: viewState.urlTemplate,
                        fallbackUrl: viewState.fallbackUrl,
                        subdomains: const ['a', 'b', 'c'],
                        maxZoom: viewState.maxZoom,
                        minZoom: viewState.minZoom,
                      ),
                  };
                },
              ),
              ValueListenableBuilder<List<LatLng>>(
                valueListenable: _routePoints,
                builder: (BuildContext context, List<LatLng> points, _) {
                  return ValueListenableBuilder<MapViewState>(
                    valueListenable: _mapViewNotifier,
                    builder: (BuildContext context, MapViewState viewState, _) {
                      return PolylineLayer(
                        polylines: <Polyline>[
                          Polyline(
                            points: points,
                            color: context.appColors.lightPurple,
                            strokeWidth: viewState.polylineStrokeWidth,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
              _MarkerBuilder<MapLocationState, MapViewState>(
                locationNotifier: _mapLocationNotifier,
                viewNotifier: _mapViewNotifier,
                builder: (
                  BuildContext context,
                  MapLocationState locationState,
                  MapViewState viewState,
                ) {
                  return switch (locationState) {
                    MapLocationUpdateSuccess(location: final location) =>
                      MarkerLayer(
                        markers: [
                          Marker(
                            width: viewState.markerSize,
                            height: viewState.markerSize,
                            point: location.toLatLng(),
                            child: Icon(
                              Icons.circle,
                              size: viewState.markerSize,
                              color: Colors.deepPurple.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    MapInitialLocationLoading() => const Center(
                        child: CircularProgressIndicator(),
                      ),
                    _ => const SizedBox.shrink(),
                  };
                },
              ),
            ],
          ),
          Positioned(
            right: 10,
            top: 0,
            bottom: 0,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                // TODO: For debugging
                IconButton(
                  icon: const Icon(
                    Icons.zoom_in,
                  ),
                  onPressed: () {
                    _mapViewNotifier.zoomIn();
                  },
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                ValueListenableBuilder<MapViewState>(
                  valueListenable: _mapViewNotifier,
                  builder: (BuildContext context, MapViewState state, _) =>
                      Text(
                    '${state.zoom}',
                  ),
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                ValueListenableBuilder<MapViewState>(
                  valueListenable: _mapViewNotifier,
                  builder: (BuildContext context, MapViewState state, _) =>
                      Switch(
                    value: state.isCentered,
                    onChanged: _handleToggleButtonSwitched,
                  ),
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    _mapViewNotifier.zoomOut();
                  },
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 20,
            child: ValueListenableBuilder<bool>(
              valueListenable: _isRouteRecordingStarted,
              builder: (BuildContext context, bool isRecording, _) => Switch(
                value: isRecording,
                onChanged: (value) {
                  _isRouteRecordingStarted.value = value;
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleZoomChanged() {
    final zoom = switch (_mapViewNotifier.value) {
      MapViewState(zoom: final zoom) => zoom,
    };

    _animatedMapController.animatedZoomTo(zoom);
    _mapViewNotifier.changeMarkerSize(zoom);
    _mapViewNotifier.changePolylineStrokeWidth(zoom);
  }

  // TODO: Temporary for testing
  void _handleToggleButtonSwitched(bool value) {
    _mapViewNotifier.centerMap(value);

    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess) {
      _centerMapViewToCurrentLocation(locationState.location.toLatLng());
    }
  }

  void _handleMapLocationChanged() {
    final mapViewCentered = switch (_mapViewNotifier.value) {
      MapViewState(isCentered: final isCentered) => isCentered,
    };

    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess && mapViewCentered) {
      _centerMapViewToCurrentLocation(locationState.location.toLatLng());
    }
  }

  void _centerMapViewToCurrentLocation(LatLng location) {
    _animatedMapController.animateTo(
      dest: location,
    );
  }

  void _handleRouteRecordingStarted() {
    if (_isRouteRecordingStarted.value) {
      _mapLocationNotifier.addListener(_handleRecordRoutePoints);
      final locationState = _mapLocationNotifier.value;
      if (locationState is MapLocationUpdateSuccess) {
        _routePoints.value.add(locationState.location.toLatLng());
      }
    } else {
      _routePoints.value = [];
      _mapLocationNotifier.removeListener(_handleRecordRoutePoints);
    }
  }

  void _handleRecordRoutePoints() {
    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateSuccess) {
      _routePoints.value.add(locationState.location.toLatLng());
    }
  }

  @override
  bool get wantKeepAlive => true;
}

class _MarkerBuilder<L extends MapLocationState, V extends MapViewState>
    extends StatelessWidget {
  const _MarkerBuilder({
    super.key,
    required this.locationNotifier,
    required this.viewNotifier,
    required this.builder,
  });

  final ValueListenable<L> locationNotifier;
  final ValueListenable<V> viewNotifier;
  final Widget Function(
    BuildContext context,
    L locationState,
    V viewState,
  ) builder;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<L>(
      valueListenable: locationNotifier,
      builder: (_, L locationState, __) {
        return ValueListenableBuilder<V>(
          valueListenable: viewNotifier,
          builder: (BuildContext context, V viewState, __) {
            return builder(context, locationState, viewState);
          },
        );
      },
    );
  }
}

class _MapAppBar extends StatefulWidget implements PreferredSizeWidget {
  const _MapAppBar({
    required this.onPageChange,
  });

  final VoidCallback onPageChange;

  @override
  State<_MapAppBar> createState() => _MapAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MapAppBarState extends State<_MapAppBar> {
  late MapLocationNotifier _mapLocationNotifier;

  bool _hasError = false;

  bool _isShowExceptionDialog = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = context.locationNotifier;
    _mapLocationNotifier.addListener(_handleLocationUpdateException);
  }

  @override
  void dispose() {
    _mapLocationNotifier.removeListener(_handleLocationUpdateException);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      surfaceTintColor: Colors.transparent,
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.grayBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.appColors.grayBlue.withOpacity(0.3),
              spreadRadius: 0,
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.only(
            left: 8,
            top: 4,
            right: 8,
            bottom: 4,
          ),
          child: RichText(
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              // TODO(abra): Add address based on current location
              text: 'Address of current location',
              style: GoogleFonts.robotoCondensed(
                fontSize: 16,
                color: context.appColors.appWhite,
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: <double>[1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
                .map((double opacity) =>
                    context.appColors.simpleWhite.withOpacity(opacity))
                .toList(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: context.appColors.simpleWhite.withOpacity(0.0),
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: _hasError && !_isShowExceptionDialog
            ? FittedBox(
                child: IconButton(
                  onPressed: () async {
                    setState(() {
                      _isShowExceptionDialog = true;
                    });
                    await _showExceptionDialog(context);
                  },
                  icon: const ExceptionIcon(),
                  alignment: Alignment.center,
                ),
              )
            : const SizedBox.shrink(),
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: FittedBox(
            alignment: Alignment.center,
            fit: BoxFit.fitWidth,
            child: IconButton(
              color: context.appColors.grayBlue,
              alignment: Alignment.center,
              icon: const Icon(
                CupertinoIcons.square_stack_3d_down_right_fill,
                size: 34,
              ),
              onPressed: widget.onPageChange,
            ),
          ),
        ),
      ],
    );
  }

  // TODO: Ugly code, refactor
  Future<void> _handleLocationUpdateException() async {
    if (_mapLocationNotifier.value is MapLocationUpdateFailure) {
      setState(() {
        _hasError = true;
      });
      if (_isShowExceptionDialog) {
        await _showExceptionDialog(context);
      }
    } else {
      setState(() {
        _hasError = false;
        _isShowExceptionDialog = false;
      });
    }
  }

  Future<void> _onTryAgain() async {
    await _mapLocationNotifier.reInit();
    setState(() {
      _isShowExceptionDialog = true;
    });
  }

  void _onDismiss() {
    setState(() {
      _isShowExceptionDialog = false;
    });
  }

  Future<void> _showExceptionDialog(BuildContext context) async =>
      showDialog<void>(
        barrierDismissible: false,
        context: context,
        builder: (BuildContext context) => Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 96,
              maxHeight: 250,
              minHeight: 150,
            ),
            child: ValueListenableBuilder<MapLocationState>(
              valueListenable: _mapLocationNotifier,
              builder: (BuildContext context, MapLocationState state, _) {
                return switch (state) {
                  MapLocationUpdateFailure(error: final error) =>
                    error is ServicePermissionDeniedException
                        ? ExceptionDialog(
                            onTryAgain: _onTryAgain,
                            onDismiss: _onDismiss,
                            message: error.toString(),
                          )
                        : ExceptionDialog(
                            onDismiss: _onDismiss,
                            message: error.toString(),
                          ),
                  _ => const SizedBox.shrink(),
                };
              },
            ),
          ),
        ),
      );
}

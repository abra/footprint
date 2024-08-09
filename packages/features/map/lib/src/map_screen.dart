import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import 'package:location_repository/location_repository.dart';
import 'package:routes_repository/routes_repository.dart';

import 'exception_dialog.dart';
import 'extensions.dart';
import 'map_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.routesRepository,
    required this.onPageChangeRequested,
  });

  final LocationRepository locationRepository;
  final RoutesRepository routesRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with TickerProviderStateMixin {
  late MapNotifier _mapNotifier;

  @override
  void initState() {
    super.initState();
    _mapNotifier = MapNotifier(
      locationRepository: widget.locationRepository,
      routesRepository: widget.routesRepository,
      viewConfig: const MapViewConfig(),
    );
  }

  @override
  void dispose() {
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MapNotifierProvider(
        notifier: _mapNotifier,
        child: _MapView(
          onPageChange: widget.onPageChangeRequested,
        ),
      );
}

class _MapView extends StatelessWidget {
  const _MapView({
    required this.onPageChange,
  });

  final VoidCallback onPageChange;

  @override
  Widget build(BuildContext context) {
    final mapNotifier = context.notifier;
    log('>>> build $runtimeType $hashCode');

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: _MapAppBar(
        onPageChange: onPageChange,
      ),
      body: Stack(
        children: [
          const _FlutterMapWidget(),
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
                    mapNotifier.zoomIn();
                  },
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                ValueListenableBuilder<double>(
                  valueListenable: mapNotifier.currentZoomLevel,
                  builder: (BuildContext context, double zoom, _) => Text(
                    '[$zoom]',
                  ),
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                ValueListenableBuilder<bool>(
                  valueListenable: mapNotifier.isMapCentered,
                  builder: (BuildContext context, bool isCentered, _) => Switch(
                    value: isCentered,
                    onChanged: (value) {
                      mapNotifier.toggleMapCenter(value);
                    },
                  ),
                ),
                const SizedBox(width: 20),
                // TODO: Temporary for testing
                IconButton(
                  icon: const Icon(
                    Icons.zoom_out,
                  ),
                  onPressed: () {
                    mapNotifier.zoomOut();
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
              valueListenable: mapNotifier.isRouteRecordingActive,
              builder: (BuildContext context, bool isRecording, _) => Switch(
                value: isRecording,
                onChanged: (value) {
                  if (value) {
                    mapNotifier.startRouteRecording();
                  } else {
                    mapNotifier.stopRouteRecording();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlutterMapWidget extends StatefulWidget {
  const _FlutterMapWidget();

  @override
  State<_FlutterMapWidget> createState() => _FlutterMapWidgetState();
}

class _FlutterMapWidgetState extends State<_FlutterMapWidget>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late MapNotifier _mapNotifier;
  late AnimatedMapController _animatedMapController;

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
      curve: Curves.fastOutSlowIn,
    );
  }

  @override
  void dispose() {
    _animatedMapController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapNotifier = context.notifier;
    _mapNotifier.onZoomChanged = ((zoom) {
      _animatedMapController.animatedZoomTo(zoom);
    });
    _mapNotifier.onMapCentered = ((location) {
      _animatedMapController.animateTo(
        dest: location.toLatLng(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return FlutterMap(
      mapController: _animatedMapController.mapController,
      options: MapOptions(
        interactionOptions: const InteractionOptions(
          pinchZoomWinGestures: InteractiveFlag.pinchZoom,
        ),
        initialZoom: _mapNotifier.viewConfig.defaultZoom,
        maxZoom: _mapNotifier.viewConfig.maxZoom,
        minZoom: _mapNotifier.viewConfig.minZoom,
      ),
      children: const [
        _TileLayerWidget(),
        _PolylineLayerWidget(),
        _MarkerLayerWidget(),
      ],
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _TileLayerWidget extends StatelessWidget {
  const _TileLayerWidget();

  @override
  Widget build(BuildContext context) {
    final mapNotifier = context.notifier;
    return TileLayer(
      retinaMode: true,
      userAgentPackageName: mapNotifier.viewConfig.userAgentPackageName,
      urlTemplate: mapNotifier.viewConfig.urlTemplate,
      fallbackUrl: mapNotifier.viewConfig.fallbackUrl,
      subdomains: const ['a', 'b', 'c'],
      maxZoom: mapNotifier.viewConfig.maxZoom,
      minZoom: mapNotifier.viewConfig.minZoom,
    );
  }
}

class _PolylineLayerWidget extends StatelessWidget {
  const _PolylineLayerWidget();

  @override
  Widget build(BuildContext context) {
    final mapNotifier = context.notifier;
    return ValueListenableBuilder<List<LatLng>>(
      valueListenable: mapNotifier.routePoints,
      builder: (BuildContext context, List<LatLng> routePoints, _) {
        return ValueListenableBuilder<double>(
          valueListenable: mapNotifier.currentPolylineWidth,
          builder: (BuildContext context, double width, _) {
            return PolylineLayer(
              polylines: <Polyline>[
                Polyline(
                  points: routePoints,
                  color: context.appColors.lightPurple,
                  strokeWidth: width,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

typedef CombinedNotifier = (LocationState, double);

class _MarkerLayerWidget extends StatelessWidget {
  const _MarkerLayerWidget();

  @override
  Widget build(BuildContext context) {
    final mapNotifier = context.notifier;
    final combinedNotifier = ValueNotifier<CombinedNotifier>((
      mapNotifier.locationState.value,
      mapNotifier.currentMarkerSize.value,
    ));

    return ValueListenableBuilder<CombinedNotifier>(
      valueListenable: combinedNotifier,
      builder: (BuildContext context, CombinedNotifier combinedNotifier, _) {
        final (locationState, markerSize) = combinedNotifier;
        final location = (locationState as LocationUpdateSuccess).location;

        return switch (locationState) {
          LocationUpdateSuccess(location: final location) => MarkerLayer(
              markers: [
                Marker(
                  width: markerSize,
                  height: markerSize,
                  point: location.toLatLng(),
                  child: Icon(
                    Icons.circle,
                    size: markerSize,
                    color: Colors.deepPurple.withOpacity(0.8),
                  ),
                ),
              ],
            ),
        };
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
  late MapNotifier _mapNotifier;

  bool _isErrorPresent = false;

  bool _shouldShowExceptionDialog = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapNotifier = context.notifier;
    _mapNotifier.locationState.addListener(
      _processLocationUpdateException,
    );
  }

  @override
  void dispose() {
    _mapNotifier.locationState.removeListener(
      _processLocationUpdateException,
    );
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
        child: _isErrorPresent && !_shouldShowExceptionDialog
            ? FittedBox(
                child: IconButton(
                  onPressed: () async {
                    setState(() {
                      _shouldShowExceptionDialog = true;
                    });
                    await _displayExceptionDialog(context);
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
  Future<void> _processLocationUpdateException() async {
    if (_mapNotifier.locationState.value is LocationUpdateFailure) {
      setState(() {
        _isErrorPresent = true;
      });
      if (_shouldShowExceptionDialog) {
        await _displayExceptionDialog(context);
      }
    } else {
      setState(() {
        _isErrorPresent = false;
        _shouldShowExceptionDialog = false;
      });
    }
  }

  Future<void> _onTryAgain() async {
    await _mapNotifier.reInit();
    setState(() {
      _shouldShowExceptionDialog = true;
    });
  }

  void _onDismiss() {
    setState(() {
      _shouldShowExceptionDialog = false;
    });
  }

  Future<void> _displayExceptionDialog(BuildContext context) async =>
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
            child: ValueListenableBuilder<LocationState>(
              valueListenable: _mapNotifier.locationState,
              builder: (BuildContext context, LocationState state, _) {
                return switch (state) {
                  LocationUpdateFailure(error: final error) =>
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

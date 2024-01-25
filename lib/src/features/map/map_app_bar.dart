import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_shadow/simple_shadow.dart';

import 'map_notifier.dart';
import 'map_notifier_provider.dart';

class MapAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MapAppBar({
    super.key,
    required this.onGoToRouteList,
  });

  final VoidCallback onGoToRouteList;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  State<MapAppBar> createState() => _MapAppBarState();
}

class _MapAppBarState extends State<MapAppBar> {
  final _overlayPortalController = OverlayPortalController();
  late final MapNotifier _mapNotifier;

  void _handleLocationError() {
    final locationState = _mapNotifier.value;
    if (locationState is MapLocationUpdateSuccess) {
      _overlayPortalController.show();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapNotifier = MapNotifierProvider.of(context).notifier;
  }

  @override
  void dispose() {
    // _locationNotifier.removeListener(_handleLocationError);
    _mapNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>> build $runtimeType');

    return AppBar(
      title: SimpleShadow(
        opacity: 0.2,
        sigma: 1,
        offset: const Offset(0, 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: grayBlue.withOpacity(0.7),
            borderRadius: BorderRadius.circular(25),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: 8,
              top: 4,
              right: 8,
              bottom: 4,
            ),
            child: ValueListenableBuilder<MapState>(
              valueListenable: _mapNotifier,
              builder: (BuildContext context, MapState state, _) {
                var currentLocation = 'Unknown place';
                if (state is MapLocationUpdateSuccess) {
                  currentLocation =
                      '${state.location.latitude}, ${state.location.longitude}';
                }
                return RichText(
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    // TODO: Add address based on current location
                    text: currentLocation,
                    style: GoogleFonts.robotoCondensed(
                      fontSize: 16,
                      color: white,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              white.withOpacity(1.0),
              white.withOpacity(0.8),
              white.withOpacity(0.6),
              white.withOpacity(0.2),
              white.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: white.withOpacity(0.0),
      centerTitle: true,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: FittedBox(
          alignment: Alignment.center,
          fit: BoxFit.fitWidth,
          child: OverlayPortal(
            controller: _overlayPortalController,
            overlayChildBuilder: (BuildContext ctx) {
              return Positioned(
                top: kToolbarHeight + 24,
                left: 0,
                right: 0,
                child: ColoredBox(
                  color: white.withOpacity(0.7),
                  child: const Text(
                    'Location updated',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 40,
                    ),
                  ),
                ),
              );
            },
            child: IconButton(
              onPressed: () {
                if (_overlayPortalController.isShowing) {
                  _overlayPortalController.hide();
                  return;
                }
                _overlayPortalController.show();
              },
              icon: const Icon(
                Icons.location_off,
                color: Colors.deepOrange,
                size: 34,
              ),
              alignment: Alignment.center,
            ),
          ),
        ),
      ),
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: FittedBox(
            alignment: Alignment.center,
            fit: BoxFit.fitWidth,
            child: IconButton(
              color: grayBlue,
              alignment: Alignment.center,
              icon: const Icon(
                CupertinoIcons.square_stack_3d_down_right_fill,
                size: 34,
              ),
              onPressed: () => widget.onGoToRouteList(),
            ),
          ),
        ),
      ],
    );
  }
}

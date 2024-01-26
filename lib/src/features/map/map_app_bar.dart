import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_shadow/simple_shadow.dart';

import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

class MapAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MapAppBar({
    super.key,
    required this.onGoToRouteList,
  });

  final VoidCallback onGoToRouteList;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

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
            child: ValueListenableBuilder<MapLocationState>(
              // TODO: Rewrite it
              valueListenable: MapLocationNotifierProvider.of(context).notifier,
              builder: (BuildContext context, MapLocationState state, _) {
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
                      color: appWhite,
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
              appWhite.withOpacity(1.0),
              appWhite.withOpacity(0.8),
              appWhite.withOpacity(0.6),
              appWhite.withOpacity(0.2),
              appWhite.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: appWhite.withOpacity(0.0),
      centerTitle: true,
      leading: const Padding(
        padding: EdgeInsets.only(left: 8.0),
        child: _ExceptionNotification(),
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
              onPressed: () => onGoToRouteList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExceptionNotification extends StatefulWidget {
  const _ExceptionNotification();

  @override
  State<_ExceptionNotification> createState() => _ExceptionNotificationState();
}

class _ExceptionNotificationState extends State<_ExceptionNotification> {
  final _overlayPortalController = OverlayPortalController();
  late final MapLocationNotifier _mapLocationNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = MapLocationNotifierProvider.of(context).notifier;
  }

  @override
  void dispose() {
    // _locationNotifier.removeListener(_handleLocationError);
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.center,
      fit: BoxFit.fitWidth,
      child: OverlayPortal(
        controller: _overlayPortalController,
        overlayChildBuilder: (BuildContext context) {
          return Positioned(
            top: kToolbarHeight + 44,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: MediaQuery.of(context).size.width - 24,
                height: kToolbarHeight + 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    boxShadow: [
                      BoxShadow(
                        color: grayBlue.withOpacity(0.2),
                        spreadRadius: 0,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    shape: BoxShape.rectangle,
                    color: trueWhite,
                  ),
                  child: const Text(
                    '',
                    style: TextStyle(
                      color: Colors.blue,
                      fontSize: 10,
                    ),
                  ),
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
    );
  }
}

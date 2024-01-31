import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:google_fonts/google_fonts.dart';

import 'map_app_bar_notifier.dart';
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

    final mapLocationNotifier =
        MapLocationNotifierProvider.of(context).notifier;

    return AppBar(
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: grayBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: grayBlue.withOpacity(0.3),
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
          child: ValueListenableBuilder<MapLocationState>(
            // TODO: Rewrite it
            valueListenable: mapLocationNotifier,
            builder: (BuildContext context, MapLocationState state, _) {
              var currentLocation = 'Footprint';
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
        child: _ExceptionIndicator(),
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

class _ExceptionIndicator extends StatefulWidget {
  const _ExceptionIndicator();

  @override
  State<_ExceptionIndicator> createState() => _ExceptionIndicatorState();
}

class _ExceptionIndicatorState extends State<_ExceptionIndicator> {
  late final MapLocationNotifier _mapLocationNotifier;
  late MapAppBarNotifier _mapAppBarNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = MapLocationNotifierProvider.of(context).notifier;
    _mapAppBarNotifier = MapAppBarNotifier();
    _mapLocationNotifier.addListener(_handleLocationUpdateException);
    _mapAppBarNotifier.addListener(_handleExceptionDisplay);
  }

  @override
  void dispose() {
    _mapLocationNotifier.removeListener(_handleLocationUpdateException);
    _mapAppBarNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      alignment: Alignment.center,
      fit: BoxFit.fitWidth,
      child: ValueListenableBuilder<MapAppBarState>(
        valueListenable: _mapAppBarNotifier,
        builder: (BuildContext context, MapAppBarState state, _) {
          return state is MapAppBarHasException && state.showExceptionIconButton
              ? IconButton(
                  onPressed: () {
                    _mapAppBarNotifier.showExceptionInDialog();
                  },
                  icon: const Icon(
                    Icons.error_outlined,
                    color: Colors.deepOrange,
                    size: 34,
                  ),
                  alignment: Alignment.center,
                )
              : const SizedBox.shrink();
        },
      ),
    );
  }

  void _handleExceptionDisplay() async {
    final appBarState = _mapAppBarNotifier.value;
    final locationState = _mapLocationNotifier.value;
    if (appBarState is MapAppBarHasException &&
        locationState is MapLocationUpdateFailure) {
      if (appBarState.showExceptionDialog) {
        await _showExceptionDialog(
          context,
          locationState,
        );
        _mapAppBarNotifier.showExceptionInIcon();
      }
    }
  }

  void _handleLocationUpdateException() async {
    final locationState = _mapLocationNotifier.value;
    if (locationState is MapLocationUpdateFailure) {
      _mapAppBarNotifier.showException();
    } else {
      _mapAppBarNotifier.hideException();
    }
  }

  Future<MapAppBarState?> _showExceptionDialog(
    BuildContext context,
    MapLocationState locationState,
  ) async {
    return await showDialog<MapAppBarState>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: SizedBox(
            width: MediaQuery.of(context).size.width - 96,
            height: 180,
            child: Dismissible(
              key: const Key('exception-dialog'),
              direction: DismissDirection.horizontal,
              onDismissed: (action) {
                Navigator.of(context).pop(
                  const MapAppBarHasException(
                    showExceptionIconButton: true,
                    showExceptionDialog: false,
                  ),
                );
              },
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10.0),
                  shape: BoxShape.rectangle,
                  color: trueWhite,
                ),
                child: Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _mapLocationNotifier.reInit();
                    },
                    child: const Text('Request location permission'),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

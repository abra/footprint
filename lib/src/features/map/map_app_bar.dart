import 'dart:developer';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/shared_components/exception_dialog.dart';
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
    final mapAppBarNotifier = MapAppBarNotifier();

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
      leading: Padding(
        padding: const EdgeInsets.only(left: 8.0),
        child: _ExceptionIndicator(
          mapLocationNotifier: mapLocationNotifier,
          mapAppBarNotifier: mapAppBarNotifier,
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
              onPressed: () => onGoToRouteList(),
            ),
          ),
        ),
      ],
    );
  }
}

class _ExceptionIndicator extends StatefulWidget {
  const _ExceptionIndicator({
    required this.mapLocationNotifier,
    required this.mapAppBarNotifier,
  });

  final MapLocationNotifier mapLocationNotifier;
  final MapAppBarNotifier mapAppBarNotifier;

  @override
  State<_ExceptionIndicator> createState() => _ExceptionIndicatorState();
}

class _ExceptionIndicatorState extends State<_ExceptionIndicator> {
  late MapLocationNotifier _mapLocationNotifier;
  late MapAppBarNotifier _mapAppBarNotifier;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = widget.mapLocationNotifier;
    _mapAppBarNotifier = widget.mapAppBarNotifier;
    _mapLocationNotifier.addListener(_handleLocationUpdateException);
    _mapAppBarNotifier.addListener(_handleExceptionDisplay);
  }

  @override
  void dispose() {
    _mapAppBarNotifier.dispose();
    _mapLocationNotifier.removeListener(_handleLocationUpdateException);
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
          return state is MapAppBarUpdated && state.showExceptionIconButton
              ? IconButton(
                  onPressed: () {
                    _mapAppBarNotifier.showExceptionDialog();
                  },
                  icon: const Icon(
                    Icons.warning_rounded,
                    color: Colors.deepOrangeAccent,
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
    if (appBarState is MapAppBarUpdated) {
      if (appBarState.showExceptionDialog) {
        final appBarState = await _showExceptionDialog(context);
        if (appBarState is MapAppBarUpdated) {
          _mapAppBarNotifier.showExceptionIcon();
        }
      }
    }
  }

  void _handleLocationUpdateException() async {
    if (_mapLocationNotifier.value is MapLocationUpdateFailure) {
      _mapAppBarNotifier.showException();
    } else {
      _mapAppBarNotifier.hideException();
    }
  }

  void _onTryAgain() {
    _mapLocationNotifier.reInit();
  }

  void _onDismiss() {
    _mapAppBarNotifier.showExceptionIcon();
  }

  Future<MapAppBarState?> _showExceptionDialog(
    BuildContext context,
  ) async {
    return await showDialog<MapAppBarState>(
      barrierDismissible: false,
      context: context,
      builder: (BuildContext context) {
        return Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width - 96,
              maxHeight: 250,
              minHeight: 150,
            ),
            child: Builder(
              builder: (BuildContext context) {
                final locationState = _mapLocationNotifier.value;
                if (locationState is MapLocationUpdateFailure) {
                  if (locationState.error is PermissionDeniedException) {
                    return ExceptionDialog(
                      onTryAgain: _onTryAgain,
                      onDismiss: _onDismiss,
                      message: locationState.errorMessage,
                    );
                  } else {
                    return ExceptionDialog(
                      onDismiss: _onDismiss,
                      message: locationState.errorMessage,
                    );
                  }
                } else {
                  return const SizedBox.shrink();
                }
              },
            ),
          ),
        );
      },
    );
  }
}


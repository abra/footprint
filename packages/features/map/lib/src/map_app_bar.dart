import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'exception_dialog.dart';
import 'extensions.dart';
import 'map_notifier.dart';

class MapAppBar extends StatefulWidget implements PreferredSizeWidget {
  const MapAppBar({
    super.key,
    required this.onPageChange,
  });

  final VoidCallback onPageChange;

  @override
  State<MapAppBar> createState() => _MapAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _MapAppBarState extends State<MapAppBar> {
  late MapNotifier _mapNotifier;

  bool _isErrorPresent = false;

  bool _shouldShowExceptionDialog = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapNotifier = context.notifier;
    _mapNotifier.locationState.addListener(
      _handleLocationUpdateException,
    );
  }

  @override
  void dispose() {
    _mapNotifier.locationState.removeListener(
      _handleLocationUpdateException,
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    log('>>> _MapAppBar build $runtimeType $hashCode');
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
          child: ValueListenableBuilder<LocationAddressModel?>(
            valueListenable: _mapNotifier.locationAddress,
            builder: (BuildContext context, LocationAddressModel? value, _) {
              return RichText(
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                text: TextSpan(
                  // TODO(abra): Add address based on current location
                  text: value?.address ?? 'Current location',
                  style: GoogleFonts.robotoCondensed(
                    fontSize: 16,
                    color: context.appColors.appWhite,
                  ),
                ),
              );
            }
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
  Future<void> _handleLocationUpdateException() async {
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

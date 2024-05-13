import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app/common/colors.dart';
import '../component_library/exception_icon.dart';
import '../domain_models/exceptions.dart';
import 'exception_dialog.dart';
import 'extensions.dart';
import 'map_location_notifier.dart';

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
  MapLocationNotifier get _mapLocationNotifier => context.locationNotifier;

  bool _hasError = false;

  bool _isShowExceptionDialog = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
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
          color: AppColors.grayBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppColors.grayBlue.withOpacity(0.3),
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
                color: AppColors.appWhite,
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
                    AppColors.simpleWhite.withOpacity(opacity))
                .toList(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: AppColors.simpleWhite.withOpacity(0.0),
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
              color: AppColors.grayBlue,
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

  Future<void> _showExceptionDialog(BuildContext context) async {
    return showDialog<void>(
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
                final MapLocationState locationState =
                    _mapLocationNotifier.value;
                if (locationState is MapLocationUpdateFailure) {
                  if (locationState.error is ServicePermissionDeniedException) {
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

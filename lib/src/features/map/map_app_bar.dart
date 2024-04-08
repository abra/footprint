import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:google_fonts/google_fonts.dart';

import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

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
  late MapLocationNotifier _mapLocationNotifier;
  bool _hasError = false;
  bool _isShowExceptionDialog = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier = MapLocationNotifierProvider.of(context).notifier;
    _mapLocationNotifier.addListener(_handleLocationUpdateException);
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.grayBlue.withOpacity(0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
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
              // TODO: Add address based on current location
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
            colors: [1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
                .map((opacity) => AppColors.appWhite.withOpacity(opacity))
                .toList(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: AppColors.appWhite.withOpacity(0.0),
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
                  icon: const Icon(
                    Icons.location_off_rounded,
                    color: Colors.red,
                    size: 36,
                  ),
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

  void _handleLocationUpdateException() async {
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

  void _onTryAgain() {
    _mapLocationNotifier.reInit();
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
    return await showDialog<void>(
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
                    return _ExceptionDialog(
                      onTryAgain: _onTryAgain,
                      onDismiss: _onDismiss,
                      message: locationState.errorMessage,
                    );
                  } else {
                    return _ExceptionDialog(
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

class _ExceptionDialog extends StatelessWidget {
  const _ExceptionDialog({
    VoidCallback? onTryAgain,
    required this.onDismiss,
    required this.message,
  }) : _onTryAgain = onTryAgain;

  final VoidCallback? _onTryAgain;
  final VoidCallback onDismiss;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: const Key('exception-dialog'),
      direction: DismissDirection.horizontal,
      onDismissed: (action) {
        Navigator.of(context).pop();
        onDismiss();
      },
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30.0),
          shape: BoxShape.rectangle,
          color: AppColors.trueWhite,
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Add red circle
                    SizedBox(
                      width: 70,
                      height: 70,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.1),
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 60,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.red.withOpacity(0.2),
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.location_off_outlined,
                      color: Colors.red,
                      size: 36,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Center(
                    child: Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 16,
                        color: AppColors.grayBlue,
                      ),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Builder(
                  builder: (BuildContext context) {
                    if (_onTryAgain == null) {
                      return TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          onDismiss();
                        },
                        child: const Text(
                          'Hide',
                          style: TextStyle(
                            color: AppColors.grayBlue,
                            fontSize: 18,
                          ),
                        ),
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        SizedBox(
                          width: 120,
                          child: TextButton(
                            onPressed: () {
                              onDismiss();
                              Navigator.of(context).pop();
                            },
                            child: const Text(
                              'Hide',
                              style: TextStyle(
                                color: AppColors.grayBlue,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 120,
                          child: TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                              _onTryAgain();
                            },
                            child: const Text(
                              'Try again',
                              style: TextStyle(
                                color: AppColors.darkPurple,
                                fontSize: 18,
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:footprint/src/domain_models/exceptions.dart';
import 'package:footprint/src/location_repository/location_repository.dart';
import 'package:footprint/src/shared_components/exception_icon.dart';
import 'package:google_fonts/google_fonts.dart';

import 'exception_dialog.dart';
import 'extensions.dart';
import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';
import 'map_view.dart';
import 'map_view_config.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
    required this.locationRepository,
    required this.onPageChangeRequested,
  });

  final LocationRepository locationRepository;
  final VoidCallback onPageChangeRequested;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late MapLocationNotifier _mapLocationNotifier;
  final MapViewConfig _config = const MapViewConfig();

  @override
  void initState() {
    super.initState();
    _mapLocationNotifier = MapLocationNotifier(
      locationRepository: widget.locationRepository,
    );
  }

  @override
  void dispose() {
    _mapLocationNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MapLocationNotifierProvider(
      notifier: _mapLocationNotifier,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: _MapAppBar(
          onPageChange: widget.onPageChangeRequested,
        ),
        body: MapView(
          config: _config,
        ),
      ),
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

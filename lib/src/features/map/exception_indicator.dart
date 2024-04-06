import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:footprint/src/domain_models/exceptions.dart';

import 'map_app_bar_notifier.dart';
import 'map_location_notifier.dart';
import 'map_notifier_provider.dart';

class ExceptionIndicator extends StatefulWidget {
  const ExceptionIndicator({super.key});

  @override
  State<ExceptionIndicator> createState() => _ExceptionIndicatorState();
}

class _ExceptionIndicatorState extends State<ExceptionIndicator> {
  late MapLocationNotifier _mapLocationNotifier;
  late MapAppBarNotifier _mapAppBarNotifier;

  @override
  void initState() {
    super.initState();
    _mapAppBarNotifier = MapAppBarNotifier();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _mapLocationNotifier =
        MapLocationNotifierProvider.of(context).locationNotifier;
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
                    Icons.location_off_rounded,
                    color: Colors.red,
                    size: 36,
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
    super.key,
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
          color: trueWhite,
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
                        color: grayBlue,
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
                            color: grayBlue,
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
                              Navigator.of(context).pop();
                              onDismiss();
                            },
                            child: const Text(
                              'Hide',
                              style: TextStyle(
                                color: grayBlue,
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
                                color: darkPurple,
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

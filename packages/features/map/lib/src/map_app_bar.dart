import 'dart:developer';

import 'package:component_library/component_library.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:map/src/extensions.dart';

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
  MapNotifier get _mapNotifier => context.notifier;

  @override
  Widget build(BuildContext context) {
    log('build', name: '$this', time: DateTime.now());
    return AppBar(
      surfaceTintColor: Colors.transparent,
      title: DecoratedBox(
        decoration: BoxDecoration(
          color: context.appColors.grayBlue.withValues(alpha: 0.8),
          borderRadius: BorderRadius.circular(25),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: context.appColors.grayBlue.withValues(alpha: 0.3),
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
          child: SizedBox(
            width: double.infinity,
            child: ValueListenableBuilder<PlaceAddressState>(
              valueListenable: _mapNotifier.placeAddress,
              builder: (BuildContext context, PlaceAddressState state, _) {
                return RichText(
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    // TODO(abra): Add address based on current location
                    text: switch (state) {
                      PlaceAddressLoading() => 'Loading...',
                      PlaceAddressSuccess(address: final address) => address,
                      PlaceAddressFailure() => 'Error',
                    },
                    style: TextStyle(
                      fontSize: 16,
                      color: context.appColors.appWhite,
                      fontWeight: FontWeight.w500,
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
            colors: <double>[1.0, 0.8, 0.6, 0.4, 0.2, 0.0]
                .map((double opacity) =>
                    context.appColors.simpleWhite.withValues(alpha: opacity))
                .toList(),
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: context.appColors.simpleWhite.withValues(alpha: 0.0),
      centerTitle: true,
      leading: const SizedBox.shrink(),
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
}

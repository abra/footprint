import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:footprint/src/app/common/colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:simple_shadow/simple_shadow.dart';

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
    return AppBar(
      title: SimpleShadow(
        opacity: 0.2,
        sigma: 1,
        offset: const Offset(0, 2),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: grayColor.withOpacity(0.7),
            borderRadius: BorderRadius.circular(25),
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
                text: 'Location Address',
                style: GoogleFonts.robotoCondensed(
                  fontSize: 16,
                  color: whiteColor,
                ),
              ),
            ),
          ),
        ),
      ),
      flexibleSpace: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              whiteColor.withOpacity(0.8),
              whiteColor.withOpacity(0.5),
              whiteColor.withOpacity(0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: const SizedBox.expand(),
      ),
      elevation: 0,
      backgroundColor: whiteColor.withOpacity(0.0),
      centerTitle: true,
      actions: <Widget>[
        Padding(
          padding: const EdgeInsets.only(right: 8.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: <Color>[
                  whiteColor.withOpacity(0.6),
                  whiteColor.withOpacity(0.4),
                  whiteColor.withOpacity(0.0),
                ],
              ),
            ),
            child: SizedBox(
              width: kToolbarHeight,
              height: kToolbarHeight,
              child: IconButton(
                key: const Key('map-screen-button'),
                color: grayColor,
                alignment: Alignment.center,
                icon: const Icon(
                  CupertinoIcons.square_stack_3d_down_right_fill,
                  size: 34,
                ),
                onPressed: () => onGoToRouteList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

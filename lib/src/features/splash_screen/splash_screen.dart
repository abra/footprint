import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:footprint/src/components/colors.dart';
import 'package:footprint/src/components/constants.dart';

/// A stateless widget representing the splash screen of the application.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ColoredBox(
        color: greenColor,
        child: Center(
          child: FractionallySizedBox(
            widthFactor: 0.6,
            child: SvgPicture.asset(
              svgFile,
              colorFilter: const ColorFilter.mode(
                whiteColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

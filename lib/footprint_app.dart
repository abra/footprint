import 'package:flutter/material.dart';
import 'package:footprint/src/features/splash_screen/splash_screen.dart';

class FootprintApp extends StatefulWidget {
  const FootprintApp({super.key});

  @override
  State<FootprintApp> createState() => _FootprintAppState();
}

class _FootprintAppState extends State<FootprintApp> {
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: SplashScreen(),
    );
  }
}

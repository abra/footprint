import 'package:flutter/material.dart';

import 'splash_screen.dart';

class FootprintApp extends StatelessWidget {
  const FootprintApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: FutureBuilder(
        future: Future<void>.delayed(
          const Duration(seconds: 2),
        ),
        builder: (BuildContext ctx, AsyncSnapshot<void> snapshot) {
          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 500),
            child: snapshot.connectionState == ConnectionState.done
                // TODO: Replace with HomeScreen widget
                ? const Scaffold(
                    body: Center(
                      child: Placeholder(
                        child: Center(
                          child: Text('HomeScreen'),
                        ),
                      ),
                    ),
                  )
                : const SplashScreen(),
          );
        },
      ),
    );
  }
}

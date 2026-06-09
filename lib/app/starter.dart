import 'dart:async';
import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:footprint/app/composition.dart';
import 'package:footprint/app/initialization_failed_screen.dart';
import 'package:footprint/app/root_context.dart';
import 'package:foreground_location_service/foreground_location_service.dart';

Future<void> starter() async {
  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      ForegroundLocationService.initCommunicationPort();

      FlutterError.onError = (details) {
        FlutterError.presentError(details);
        log(
          'Flutter error',
          error: details.exception,
          stackTrace: details.stack,
        );
      };

      PlatformDispatcher.instance.onError = (error, stackTrace) {
        log('Platform dispatcher error', error: error, stackTrace: stackTrace);
        return true;
      };

      Future<void> composeAndRun() async {
        try {
          final compositionResult = await composeDependencies();
          runApp(RootContext(compositionResult: compositionResult));
        } catch (error, stackTrace) {
          log('Initialization failed', error: error, stackTrace: stackTrace);
          runApp(
            InitializationFailedScreen(
              error: error,
              stackTrace: stackTrace,
              onRetryInitialization: composeAndRun,
            ),
          );
        }
      }

      await composeAndRun();
    },
    (error, stackTrace) {
      log('Uncaught zone error', error: error, stackTrace: stackTrace);
    },
  );
}

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:footprint/src/app/footprint_app.dart';

void main() {
  runZonedGuarded<Future<void>>(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      runApp(const FootprintApp());
    },
    (error, stack) {
      log('ZONED ERROR: $error\n$stack');
    },
  );
}

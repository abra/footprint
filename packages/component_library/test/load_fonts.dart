import 'package:flutter/services.dart';

Future<void> loadAppFonts() async {
  for (final (family, asset) in [
    ('packages/forui/Inter', 'packages/forui/assets/fonts/inter/Inter.ttf'),
    (
      'packages/forui_lucide/ForuiLucideIcons',
      'packages/forui_lucide/assets/lucide.ttf',
    ),
    (
      'packages/component_library/RobotoCondensed',
      'packages/component_library/fonts/RobotoCondensed.ttf',
    ),
    ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
  ]) {
    await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
  }
}

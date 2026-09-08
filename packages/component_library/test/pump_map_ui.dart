import 'package:flutter_test/flutter_test.dart';

// Finish map/page transitions without waiting for the recording indicator.
Future<void> pumpMapUi(
  WidgetTester tester, {
  Duration duration = const Duration(seconds: 2),
}) async {
  const step = Duration(milliseconds: 100);
  await tester.pump();
  for (var elapsed = Duration.zero; elapsed < duration; elapsed += step) {
    await tester.pump(step);
  }
}

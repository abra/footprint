import 'package:flutter_test/flutter_test.dart';

// Finish finite map/page transitions without waiting for the repeating dot.
Future<void> pumpRecordingUi(WidgetTester tester) async {
  await tester.pump();
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

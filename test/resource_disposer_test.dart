import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/resource_disposer.dart';

void main() {
  test(
    'resources close in reverse order exactly once, including after failures',
    () async {
      final calls = <String>[];
      final gate = Completer<void>();
      final resources = ResourceDisposer()
        ..add('database', () {
          calls.add('database');
        })
        ..add('failing', () {
          calls.add('failing');
          throw StateError('close failed');
        })
        ..add('service', () async {
          calls.add('service');
          await gate.future;
        });
      final first = resources.dispose();
      final second = resources.dispose();
      expect(identical(first, second), isTrue);
      expect(() => resources.add('late', () {}), throwsStateError);
      gate.complete();
      await first;
      expect(calls, ['service', 'failing', 'database']);
    },
  );
}

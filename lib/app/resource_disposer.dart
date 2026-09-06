import 'dart:async';
import 'dart:developer';

/// Owns app resources and releases them once in reverse creation order.
class ResourceDisposer {
  final _resources = <({String name, FutureOr<void> Function() close})>[];
  Future<void>? _disposal;

  void add(String name, FutureOr<void> Function() close) {
    if (_disposal != null) {
      throw StateError('Resource disposal already started.');
    }
    _resources.add((name: name, close: close));
  }

  Future<void> dispose() => _disposal ??= _dispose();

  Future<void> _dispose() async {
    for (final resource in _resources.reversed) {
      try {
        await resource.close();
      } on Object catch (error, stack) {
        log(
          'Failed to close ${resource.name}',
          name: 'Resources',
          error: error,
          stackTrace: stack,
        );
      }
    }
  }
}

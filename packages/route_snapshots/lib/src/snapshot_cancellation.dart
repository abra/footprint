import 'dart:async';

class SnapshotCancelled implements Exception {
  const SnapshotCancelled();
}

class SnapshotCancellation {
  final _completion = Completer<void>();
  bool get isCancelled => _completion.isCompleted;
  Future<void> get whenCancelled => _completion.future;

  void cancel() {
    if (!isCancelled) _completion.complete();
  }

  void check() {
    if (isCancelled) throw const SnapshotCancelled();
  }
}

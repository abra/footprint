import 'package:sqflite/sqflite.dart';

/// Retry a statement or a whole rolled-back transaction, never external effects.
Future<T> retryOnDatabaseBusy<T>(
  Future<T> Function() operation, {
  Future<void> Function(Duration) delay = Future<void>.delayed,
}) async {
  for (var attempt = 0; ; attempt++) {
    try {
      return await operation();
    } on DatabaseException catch (error) {
      final code = error.getResultCode();
      // Extended SQLite result codes retain their primary code in the low byte.
      if (code == null || (code & 0xff) != 5 || attempt >= 7) rethrow;
      await delay(Duration(milliseconds: 10 << attempt));
    }
  }
}

extension RetryingDatabaseTransaction on Database {
  Future<T> retryTransaction<T>(Future<T> Function(Transaction) action) =>
      retryOnDatabaseBusy(() => transaction(action));
}

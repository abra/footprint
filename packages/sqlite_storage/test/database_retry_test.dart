import 'package:sqflite/sqflite.dart';
import 'package:sqlite_storage/src/database_retry.dart';
import 'package:test/test.dart';

class TestDatabaseException extends DatabaseException {
  TestDatabaseException(this.code) : super('Test failure');
  final int? code;
  @override
  int? getResultCode() => code;
  @override
  Object? get result => null;
}

void main() {
  for (final code in [5, 261, 517]) {
    test(
      'retries SQLite busy code $code outside the database worker',
      () async {
        var calls = 0;
        final delays = <Duration>[];
        final result = await retryOnDatabaseBusy(() async {
          if (++calls < 3) throw TestDatabaseException(code);
          return 42;
        }, delay: (duration) async => delays.add(duration));
        expect(result, 42);
        expect(calls, 3);
        expect(delays, [
          const Duration(milliseconds: 10),
          const Duration(milliseconds: 20),
        ]);
      },
    );
  }

  test('persistent contention is bounded and preserves the error', () async {
    var calls = 0;
    final failure = TestDatabaseException(5);
    final delays = <Duration>[];
    await expectLater(
      retryOnDatabaseBusy<void>(() async {
        calls++;
        throw failure;
      }, delay: (duration) async => delays.add(duration)),
      throwsA(same(failure)),
    );
    expect(calls, 8);
    expect(delays.length, 7);
    expect(
      delays.fold(Duration.zero, (sum, delay) => sum + delay),
      const Duration(milliseconds: 1270),
    );
  });

  for (final code in [null, 1, 6, 13, 19]) {
    test('does not retry non-contention database error $code', () async {
      final failure = TestDatabaseException(code);
      await expectLater(
        retryOnDatabaseBusy<void>(
          () async => throw failure,
          delay: (_) async => fail('Unexpected retry'),
        ),
        throwsA(same(failure)),
      );
    });
  }

  test('does not retry application errors', () async {
    final failure = StateError('No active route');
    await expectLater(
      retryOnDatabaseBusy<void>(
        () async => throw failure,
        delay: (_) async => fail('Unexpected retry'),
      ),
      throwsA(same(failure)),
    );
  });
}

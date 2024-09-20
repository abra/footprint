class SqliteStorageDatabaseException implements Exception {
  const SqliteStorageDatabaseException({
    this.message = 'Unknown database exception',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

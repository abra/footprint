class UnableCreateDatabaseException implements Exception {
  UnableCreateDatabaseException({
    this.message = 'Unable to create database.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

class UnableCreateTableException implements Exception {
  UnableCreateTableException({
    this.message = 'Unable to create table.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

class UnableInsertDatabaseException implements Exception {
  UnableInsertDatabaseException({
    this.message = 'Unable to insert data.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

class UnableUpdateDatabaseException implements Exception {
  UnableUpdateDatabaseException({
    this.message = 'Unable to update data.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

class UnableDeleteDatabaseException implements Exception {
  UnableDeleteDatabaseException({
    this.message = 'Unable to delete data.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

class UnableExecuteQueryDatabaseException implements Exception {
  UnableExecuteQueryDatabaseException({
    this.message = 'Unable to execute query.',
  });

  final String message;

  @override
  String toString() {
    return message;
  }
}

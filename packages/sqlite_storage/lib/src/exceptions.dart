class UnableCreateDatabaseException implements Exception {
  @override
  String toString() {
    return 'Unable to create database.';
  }
}

class UnableCreateTableException implements Exception {
  @override
  String toString() {
    return 'Unable to create table.';
  }
}

class UnableInsertDatabaseException implements Exception {
  @override
  String toString() {
    return 'Unable to insert data.';
  }
}

class UnableUpdateDatabaseException implements Exception {
  @override
  String toString() {
    return 'Unable to update data.';
  }
}

class UnableDeleteDatabaseException implements Exception {
  @override
  String toString() {
    return 'Unable to delete data.';
  }
}

class UnableExecuteQueryDatabaseException implements Exception {
  @override
  String toString() {
    return 'Unable to execute query.';
  }
}

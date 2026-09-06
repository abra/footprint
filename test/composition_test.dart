import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/composition.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../packages/features/map/test/fakes.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'composition awaits storage and does not request location permissions',
    () async {
      final service = FakeLocationService();
      final result = await composeDependencies(
        openStorage: () => SqliteStorage.open(
          factory: databaseFactoryFfi,
          path: inMemoryDatabasePath,
        ),
        createLocation: () => service,
      );
      expect(await result.dependencies.routesRepository.getRoutes(), isEmpty);
      expect(service.starts, 0);
      await result.dependencies.dispose();
      expect(service.disposed, isTrue);
    },
  );

  test('partial initialization rolls back opened database', () async {
    final storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    await expectLater(
      composeDependencies(
        openStorage: () async => storage,
        createLocation: () => throw StateError('Failed to create service'),
      ),
      throwsStateError,
    );
    await expectLater(
      storage.routes.getAll(),
      throwsA(isA<DatabaseException>()),
    );
  });
}

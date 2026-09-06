import 'package:domain_models/domain_models.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  test(
    'repository maps persisted active and completed routes into domain models',
    () async {
      final storage = await SqliteStorage.open(
        factory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      addTearDown(storage.close);
      final repository = RoutesRepository(sqliteStorage: storage);
      final start = LocationDM(
        id: '1',
        latitude: 56,
        longitude: 60,
        timestamp: DateTime.utc(2026, 9, 6),
      );
      final id = await repository.startRoute(start);
      expect((await repository.getActiveRoute())!.id, id);
      final end = LocationDM(
        id: '2',
        latitude: 56.01,
        longitude: 60.01,
        timestamp: start.timestamp.add(const Duration(seconds: 10)),
      );
      await repository.addPoint(id, end);
      await repository.finishRoute(id, end.timestamp);
      final route = (await repository.getRoute(id))!;
      expect(route.status, Status.completed);
      expect(route.startPoint!.latitude, start.latitude);
      expect(route.endPoint!.timestamp, end.timestamp);
      expect(route.endTime, end.timestamp);
      expect(await repository.getActiveRoute(), isNull);
      await repository.deleteRoute(id);
      expect(await repository.getRoutes(), isEmpty);
    },
  );
}

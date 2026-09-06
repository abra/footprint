import 'package:domain_models/domain_models.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  late SqliteStorage storage;
  late RoutesRepository repository;
  final start = DateTime.utc(2026, 9, 6);
  LocationDM location(int day) => LocationDM(
    id: '$day',
    latitude: 56,
    longitude: 60,
    timestamp: start.add(Duration(days: day)),
  );

  Future<int> saved(int day, String name) async {
    final id = await repository.startRoute(location(day));
    await repository.finishRoute(
      id,
      location(day).timestamp.add(const Duration(minutes: 10)),
    );
    await repository.renameRoute(id, name);
    return id;
  }

  setUp(() async {
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    repository = RoutesRepository(sqliteStorage: storage);
  });
  tearDown(() => storage.close());

  test(
    'renaming preserves route points, completion, and calculated metrics',
    () async {
      final id = await saved(1, '  Morning walk  ');
      final route = (await repository.getRoute(id))!;
      expect(route.name, 'Morning walk');
      expect(route.status, Status.completed);
      expect(route.routePoints, hasLength(1));
      expect(route.metrics.duration, const Duration(minutes: 10));
      expect(
        (await repository.getRoutePage()).single.routePoints,
        route.routePoints,
      );
    },
  );
  test(
    'search is Unicode case-insensitive and treats SQL wildcards literally',
    () async {
      final id = await saved(1, '\u041c\u043e\u0441\u043a\u0432\u0430 100%');
      await saved(2, 'Forest');
      expect(
        (await repository.getRoutePage(
          query: '\u043c\u043e\u0441\u043a\u0432\u0430',
        )).single.id,
        id,
      );
      expect((await repository.getRoutePage(query: '%')).single.id, id);
      expect(await repository.getRoutePage(query: "' OR 1=1 --"), isEmpty);
    },
  );
  test(
    'pagination is stable and sort order is applied before slicing',
    () async {
      final a = await saved(1, 'Zulu');
      final b = await saved(2, 'Alpha');
      final c = await saved(3, 'Beta');
      expect((await repository.getRoutePage(limit: 2)).map((r) => r.id), [
        c,
        b,
      ]);
      expect((await repository.getRoutePage(limit: 2, offset: 2)).single.id, a);
      expect(
        (await repository.getRoutePage(sort: RouteSort.oldest))
            .map((r) => r.id),
        [a, b, c],
      );
      expect(
        (await repository.getRoutePage(sort: RouteSort.name)).map((r) => r.id),
        [b, c, a],
      );
    },
  );
  test('invalid names and pages are rejected without modifying data', () async {
    final id = await saved(1, 'Original');
    expect(() => repository.renameRoute(id, '  '), throwsArgumentError);
    expect(() => repository.renameRoute(id, 'a' * 81), throwsArgumentError);
    await expectLater(repository.getRoutePage(offset: -1), throwsArgumentError);
    await expectLater(repository.getRoutePage(limit: 101), throwsArgumentError);
    expect((await repository.getRoute(id))!.name, 'Original');
  });
  test('active routes cannot be renamed or deleted', () async {
    final id = await repository.startRoute(location(1));
    await expectLater(repository.renameRoute(id, 'New name'), throwsStateError);
    await expectLater(repository.deleteRoute(id), throwsStateError);
    expect((await repository.getActiveRoute())!.id, id);
    expect((await repository.getRoute(id))!.routePoints, hasLength(1));
  });
}

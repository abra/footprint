import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/resource_disposer.dart';
import 'package:recording_service/recording_service.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../packages/recording_service/test/fakes.dart';

class GatedRepository extends RoutesRepository {
  GatedRepository({required super.sqliteStorage});
  final accepted = Completer<void>();
  final release = Completer<void>();
  @override
  Future<bool> addPoint(int id, LocationDM location) async {
    accepted.complete();
    await release.future;
    return super.addPoint(id, location);
  }
}

void main() {
  test('application shutdown drains recording before closing SQLite', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'footprint-shutdown-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/route.db';
    final storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final repository = GatedRepository(sqliteStorage: storage);
    final locationService = FakeLocationService()..lastLocation = location(1);
    final recording = RecordingService(
      locationService: locationService,
      routesRepository: repository,
    );
    final resources = ResourceDisposer()
      ..add('database', storage.close)
      ..add('location', locationService.dispose)
      ..add('recording', recording.dispose);
    await recording.attachPreview();
    await recording.start();
    final id = recording.state.routeId!;
    locationService.send(location(2));
    await repository.accepted.future;
    final closing = resources.dispose();
    expect((await repository.getRoute(id))!.routePoints, hasLength(1));
    repository.release.complete();
    await closing;
    final reopened = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    try {
      expect(
        (await RoutesRepository(sqliteStorage: reopened).getRoute(id))!
            .routePoints,
        hasLength(2),
      );
    } finally {
      await reopened.close();
    }
  });
}

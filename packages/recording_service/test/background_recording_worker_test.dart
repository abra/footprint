import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recording_service/src/background_recording_worker.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'fakes.dart';

Future<void> tick() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'publishes only after persistence; stop waits for queued points',
    () async {
      final repository = FakeRoutesRepository();
      await repository.startRoute(location(1));
      final stream = StreamController<LocationDM>.broadcast();
      final saved = <LocationDM>[];
      final worker = BackgroundRecordingWorker(
        routesRepository: repository,
        onSaved: saved.add,
        onError: (error, stack) => fail('$error'),
      );
      await worker.start(stream.stream);
      repository.pointGate = Completer<void>();
      stream.add(location(2));
      await tick();
      expect(saved, isEmpty);
      final stopping = worker.stop();
      repository.pointGate!.complete();
      await stopping;
      expect(saved, [location(2)]);
      expect(repository.added, [location(2)]);
      await stream.close();
    },
  );

  test('failed point remains available for a subsequent stop retry', () async {
    final repository = FakeRoutesRepository();
    await repository.startRoute(location(1));
    final stream = StreamController<LocationDM>.broadcast();
    final errors = <Object>[];
    final worker = BackgroundRecordingWorker(
      routesRepository: repository,
      onSaved: (_) {},
      onError: (error, _) => errors.add(error),
    );
    await worker.start(stream.stream);
    repository.failPoint = true;
    stream.add(location(2));
    await tick();
    expect(errors, isNotEmpty);
    await expectLater(worker.stop(), throwsStateError);
    repository.failPoint = false;
    await worker.stop();
    expect(repository.added, [location(2)]);
    await stream.close();
  });

  test('worker saves through its own connection with no UI connection or listeners', () async {
    sqfliteFfiInit();
    final directory = await Directory.systemTemp.createTemp(
      'footprint-background-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/route.db';
    final ui = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final id = await RoutesRepository(sqliteStorage: ui)
        .startRoute(location(1));
    final background = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final stream = StreamController<LocationDM>.broadcast();
    final delivered = Completer<void>();
    var count = 0;
    final worker = BackgroundRecordingWorker(
      routesRepository: RoutesRepository(sqliteStorage: background),
      onSaved: (_) {
        if (++count == 3) delivered.complete();
      },
      onError: (error, stack) => delivered.completeError(error, stack),
    );
    await worker.start(stream.stream);
    await ui.close();
    for (var index = 2; index <= 4; index++) {
      stream.add(location(index));
    }
    await delivered.future;
    await worker.stop();
    await stream.close();
    await background.close();
    final reopened = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    try {
      final route = (await RoutesRepository(sqliteStorage: reopened)
          .getRoute(id))!;
      expect(route.routePoints.map((point) => point.sourceId), [
        '1',
        '2',
        '3',
        '4',
      ]);
    } finally {
      await reopened.close();
    }
  });
}

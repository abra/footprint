import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:recording_service/recording_service.dart';
import 'package:recording_service/src/background_recording_worker.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../../foreground_location_service/test/gps_fixtures.dart';
import 'fakes.dart';

void main() {
  sqfliteFfiInit();

  test('background filtering survives disk reopening and matches the foreground stream', () async {
    final directory = await Directory.systemTemp.createTemp(
      'footprint-filter-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/route.db';
    final storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(storage.close);
    final repository = RoutesRepository(sqliteStorage: storage);
    final first = LocationFilter().add(fix(0, 0))!;
    final id = await repository.startRoute(first);
    final raw = [
      for (var second = 1; second <= 600; second++)
        fix(second, second.isEven ? 1 : -1, speed: 0, speedAccuracy: 0.2),
    ];
    final expected = await LocationFilter(initialLocation: first)
        .bind(Stream.fromIterable(raw))
        .toList();
    final saved = <LocationDM>[];
    final delivered = Completer<void>();
    final worker = BackgroundRecordingWorker(
      routesRepository: repository,
      onSaved: (point) {
        saved.add(point);
        if (point.id == '600') delivered.complete();
      },
      onError: (error, stack) {
        if (!delivered.isCompleted) delivered.completeError(error, stack);
      },
    );
    final stream = StreamController<LocationDM>();
    await worker.start(stream.stream);
    for (final point in raw) {
      stream.add(point);
    }
    await delivered.future.timeout(const Duration(seconds: 30));
    await worker.stop();
    await stream.close();
    expect(saved, expected);
    final before = (await repository.getRoute(id))!;
    expect(before.metrics.distance, 0);
    expect(before.metrics.duration, const Duration(minutes: 10));
    expect(before.endPoint!.isStationary, isTrue);
    expect(before.endPoint!.rawLongitude, raw.last.longitude);
    await storage.close();

    final reopened = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(reopened.close);
    final persisted = RoutesRepository(sqliteStorage: reopened);
    final after = (await persisted.getRoute(id))!;
    expect(after, before);
    expect(after.routePoints.map((p) => p.toLocation()), [first, ...expected]);
    final next = StreamController<LocationDM>();
    final resumed = Completer<LocationDM>();
    final nextWorker = BackgroundRecordingWorker(
      routesRepository: persisted,
      onSaved: resumed.complete,
      onError: resumed.completeError,
    );
    await nextWorker.start(next.stream);
    next.add(fix(601, -1));
    final held = await resumed.future.timeout(const Duration(seconds: 10));
    expect(held.longitude, 0);
    expect(held.isStationary, isTrue);
    expect(held.rawLongitude, fix(601, -1).longitude);
    await nextWorker.stop();
    await next.close();

    final preview = FakeLocationService();
    final recording = RecordingService(
      locationService: preview,
      routesRepository: persisted,
    );
    await recording.initialize();
    expect(recording.state.points.last, held);
    expect(RouteMetrics.fromLocations(recording.state.points).distance, 0);
    await recording.dispose();
    await preview.dispose();
    await persisted.finishRoute(id, gpsEpoch.add(const Duration(seconds: 610)));
    expect(
      (await persisted.getRoute(id))!.metrics.duration,
      const Duration(seconds: 610),
    );
  });

  test(
    'failed filtered point is retried once without filtering it a second time',
    () async {
      final repository = FakeRoutesRepository();
      final seed = LocationFilter().add(fix(0, 0))!;
      await repository.startRoute(seed);
      final stream = StreamController<LocationDM>();
      final failed = Completer<void>();
      final saved = <LocationDM>[];
      final worker = BackgroundRecordingWorker(
        routesRepository: repository,
        onSaved: saved.add,
        onError: (_, _) {
          if (!failed.isCompleted) failed.complete();
        },
      );
      await worker.start(stream.stream);
      repository.failPoint = true;
      stream.add(fix(10, 1));
      await failed.future;
      repository.failPoint = false;
      await worker.stop();
      await stream.close();
      expect(saved, hasLength(1));
      expect(saved.single.longitude, 0);
      expect(saved.single.rawLongitude, fix(10, 1).longitude);
      expect(saved.single.isStationary, isTrue);
      expect(repository.added, saved);
    },
  );
}

import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:recording_service/src/background_recording_worker.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import '../../domain_models/test/walk_fixtures.dart';

void main() {
  sqfliteFfiInit();
  test('background worker persists ordered checkpoints with no map or UI connection', () async {
    final directory = await Directory.systemTemp.createTemp(
      'footprint-walk-worker-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final path = '${directory.path}/walk.db';
    final uiStorage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final plan = loopPlan();
    final id = await RoutesRepository(sqliteStorage: uiStorage)
        .startRoute(walkFix(plan.points.first, 0), plan: plan);
    await uiStorage.close();
    final storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: path,
    );
    final repository = RoutesRepository(sqliteStorage: storage);
    final stream = StreamController<LocationDM>();
    final delivered = Completer<void>();
    final worker = BackgroundRecordingWorker(
      routesRepository: repository,
      onSaved: (p) {
        if (p.id == 'walk:139') delivered.complete();
      },
      onError: (error, stack) {
        if (!delivered.isCompleted) delivered.completeError(error, stack);
      },
    );
    try {
      await worker.start(stream.stream);
      for (final (i, checkpoint) in plan.checkpoints.indexed) {
        for (final offset in [0, 2, 4]) {
          stream.add(walkFix(checkpoint.point, (i + 1) * 45 + offset));
        }
      }
      await delivered.future.timeout(const Duration(seconds: 10));
      await worker.stop();
      final progress = (await WalksRepository(storage: storage)
          .getProgress(id))!;
      expect(progress.reached, plan.checkpoints.length);
      expect(progress.completed, isTrue);
      await repository.finishRoute(
        id,
        walkEpoch.add(const Duration(minutes: 3)),
      );
      expect(
        (await WalksRepository(storage: storage).getProfile()).achievements,
        contains(ExplorationAchievement.firstWalk),
      );
    } finally {
      await worker.stop();
      await stream.close();
      await storage.close();
    }
  });
}

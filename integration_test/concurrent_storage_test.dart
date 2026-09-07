import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UI and recorder connections do not block each other', (
    tester,
  ) async {
    final directory = await Directory.systemTemp.createTemp(
      'footprint-concurrent-',
    );
    final path = '${directory.path}/recording.db';
    final ui = await SqliteStorage.open(path: path);
    final recorder = await SqliteStorage.open(path: path);
    final start = DateTime.utc(2026, 9, 6);
    try {
      final previous = await ui.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: start.subtract(const Duration(days: 1)),
      );
      await ui.routes.complete(previous, start);
      final id = await ui.routes.create(
        latitude: 56,
        longitude: 60,
        timestamp: start,
        sourceId: '0',
      );
      await Future.wait([
        () async {
          for (var index = 1; index <= 30; index++) {
            await recorder.routes.addPoint(
              routeId: id,
              latitude: 56 + index * 0.0001,
              longitude: 60,
              timestamp: start.add(Duration(seconds: index)),
              sourceId: '$index',
            );
          }
        }(),
        () async {
          for (var index = 1; index <= 30; index++) {
            await ui.geocodingCache.add(
              address: 'Test address',
              latitude: 56,
              longitude: 60,
            );
            await ui.routes.getAll();
            await ui.routePhotos.getForRoute(id);
            expect((await ui.statistics.getSummaries()).single.id, previous);
          }
        }(),
      ]).timeout(const Duration(seconds: 20));
      await recorder.close();
      await ui.routes.complete(id, start.add(const Duration(seconds: 30)));
      final saved = (await ui.routes.getById(id))!;
      expect(saved.status, 'completed');
      expect(saved.routePoints, hasLength(31));
      expect(await ui.statistics.getSummaries(), hasLength(2));
      expect(
        saved.routePoints!.map((point) => point.sourceId).toSet(),
        hasLength(31),
      );
    } finally {
      // A regression must fail instead of hanging forever during teardown.
      await Future.wait([ui.close(), recorder.close()])
          .timeout(const Duration(seconds: 5));
      await directory.delete(recursive: true);
    }
  });
}

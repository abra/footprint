import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:route_snapshots/route_snapshots.dart';

String _key(int id, String digest) => '$id-${digest * 64}';

void main() {
  late Directory directory;
  late FileSnapshotStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('footprint-snapshots-');
    store = FileSnapshotStore(directory: () async => directory, maxBytes: 10);
    addTearDown(() => directory.delete(recursive: true));
  });

  test(
    'writes atomically, reopens, and removes only the requested route',
    () async {
      await store.write(_key(1, 'a'), Uint8List.fromList([1, 2]));
      await store.write(_key(2, 'b'), Uint8List.fromList([3]));
      final reopened = FileSnapshotStore(directory: () async => directory);
      expect(await reopened.read(_key(1, 'a')), [1, 2]);
      await reopened.removeRoute(1);
      expect(await reopened.read(_key(1, 'a')), isNull);
      expect(await reopened.read(_key(2, 'b')), [3]);
      expect(
        await directory
            .list()
            .where((entry) => entry.path.endsWith('.tmp'))
            .isEmpty,
        isTrue,
      );
    },
  );

  test(
    'replacement removes old geometry and the disk cache stays bounded',
    () async {
      await store.write(_key(1, 'a'), Uint8List(6));
      await store.write(_key(1, 'b'), Uint8List(6));
      expect(await store.read(_key(1, 'a')), isNull);
      await File('${directory.path}/${_key(1, 'b')}.png')
          .setLastModified(DateTime(2020));
      await store.write(_key(2, 'c'), Uint8List(6));
      expect(await store.read(_key(1, 'b')), isNull);
      expect(await store.read(_key(2, 'c')), hasLength(6));
    },
  );

  test('does not cache oversized files or accept path traversal', () async {
    await store.write(_key(1, 'a'), Uint8List(11));
    expect(await store.read(_key(1, 'a')), isNull);
    await expectLater(store.read('../outside'), throwsArgumentError);
    await expectLater(
      store.write('../outside', Uint8List(1)),
      throwsArgumentError,
    );
  });
}

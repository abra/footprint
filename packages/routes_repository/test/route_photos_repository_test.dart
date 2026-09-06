import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestPicker implements PhotoPicker {
  String? selected;
  String? lost;
  Object? error;
  Object? recoveryError;
  int calls = 0;
  final entered = Completer<void>();
  Completer<String?>? gate;
  @override
  Future<String?> pick(PhotoSource source) async {
    calls++;
    if (!entered.isCompleted) entered.complete();
    if (error case final error?) throw error;
    return gate == null ? selected : gate!.future;
  }

  @override
  Future<String?> recover() async {
    if (recoveryError case final error?) throw error;
    final result = lost;
    lost = null;
    return result;
  }
}

class TestFiles extends LocalPhotoFiles {
  TestFiles(Directory root) : super(directory: () async => root);
  bool fail = false;
  @override
  Future<void> import(String source, String name) async {
    if (fail) throw const FileSystemException('Disk full');
    await super.import(source, name);
  }
}

void main() {
  sqfliteFfiInit();
  final location = LocationDM(
    id: 'fix',
    latitude: 56,
    longitude: 60,
    timestamp: DateTime.utc(2026, 9, 6),
  );
  late Directory directory;
  late SqliteStorage storage;
  late RoutePhotosRepository photos;
  late TestPicker picker;
  late TestFiles files;
  late File original;
  late int routeId;
  var nextId = 0;

  RoutePhotosRepository create() => RoutePhotosRepository(
    dao: storage.routePhotos,
    picker: picker,
    files: files,
    createId: () => 'photo-${++nextId}',
    now: () => location.timestamp,
  );
  Future<void> capture() => photos.capture(
    routeId: routeId,
    location: location,
    source: PhotoSource.camera,
  );

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('footprint-photos-');
    original = await File('${directory.path}/original.png')
        .writeAsBytes([137, 80, 78, 71]);
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/routes.db',
    );
    routeId = await storage.routes.create(
      latitude: 56,
      longitude: 60,
      timestamp: location.timestamp,
    );
    picker = TestPicker()..selected = original.path;
    files = TestFiles(Directory('${directory.path}/photos'));
    photos = create();
  });
  tearDown(() async {
    await photos.dispose();
    await storage.close();
    await directory.delete(recursive: true);
  });

  test('copies privately and persists metadata, coordinates and relative file name', () async {
    await capture();
    final saved = (await photos.getPhotos(routeId)).single;
    expect(saved.latitude, location.latitude);
    expect(saved.capturedAt, location.timestamp);
    expect(saved.path, isNot(original.path));
    expect(await File(saved.path).readAsBytes(), await original.readAsBytes());
    expect(
      (await storage.routePhotos.getForRoute(routeId)).single.fileName,
      endsWith('.image'),
    );
    expect(await storage.routePhotos.getPending(), isNull);
    await original.delete();
    await photos.dispose();
    await storage.close();
    storage = await SqliteStorage.open(
      factory: databaseFactoryFfi,
      path: '${directory.path}/routes.db',
    );
    photos = create();
    expect(
      await File((await photos.getPhotos(routeId)).single.path).exists(),
      isTrue,
    );
  });

  test(
    'cancel and permission denial leave no phantom photo or pending capture',
    () async {
      picker.selected = null;
      await capture();
      expect(await photos.getPhotos(routeId), isEmpty);
      expect(await storage.routePhotos.getPending(), isNull);
      picker.error = const PhotoSelectionException('Camera denied');
      await expectLater(capture(), throwsA(isA<PhotoSelectionException>()));
      expect(await storage.routePhotos.getPending(), isNull);
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'failed copy is retryable, idempotent and retains original coordinates',
    () async {
      files.fail = true;
      await expectLater(capture(), throwsA(isA<FileSystemException>()));
      final pending = (await storage.routePhotos.getPending())!;
      expect(pending.sourcePath, original.path);
      expect(await photos.getPhotos(routeId), isEmpty);
      await photos.dispose();
      photos = create();
      files.fail = false;
      await photos.initialize();
      await photos.retryPending();
      final saved = (await photos.getPhotos(routeId)).single;
      expect(saved.id, pending.id);
      expect(saved.latitude, 56);
      expect(picker.calls, 1);
    },
  );

  test(
    'restores Android lost selection to journaled route, including after stop',
    () async {
      await storage.routePhotos.beginCapture(
        RoutePhoto(
          id: 'lost',
          routeId: routeId,
          fileName: 'lost.image',
          latitude: 12,
          longitude: 23,
          capturedAt: location.timestamp,
        ),
      );
      await storage.routes.complete(routeId, location.timestamp);
      picker.lost = original.path;
      await photos.initialize();
      final photo = (await photos.getPhotos(routeId)).single;
      expect(photo.id, 'lost');
      expect(photo.latitude, 12);
      expect(picker.calls, 0);
    },
  );

  test(
    'recovers committed file even if the temporary source disappeared',
    () async {
      const name = 'interrupted.image';
      final pending = RoutePhoto(
        id: 'interrupted',
        routeId: routeId,
        fileName: name,
        latitude: 56,
        longitude: 60,
        capturedAt: location.timestamp,
      );
      await storage.routePhotos.beginCapture(pending);
      await files.import(original.path, name);
      await original.delete();
      await photos.initialize();
      expect((await photos.getPhotos(routeId)).single.id, 'interrupted');
    },
  );

  test('failed lost-data recovery keeps the journal for a retry', () async {
    await storage.routePhotos.beginCapture(
      RoutePhoto(
        id: 'lost',
        routeId: routeId,
        fileName: 'lost.image',
        latitude: 56,
        longitude: 60,
        capturedAt: location.timestamp,
      ),
    );
    picker.lost = original.path;
    picker.recoveryError = StateError('Recovery failed');
    await expectLater(photos.initialize(), throwsStateError);
    expect(await storage.routePhotos.getPending(), isNotNull);
    picker.recoveryError = null;
    await photos.initialize();
    expect(await photos.getPhotos(routeId), hasLength(1));
  });

  test(
    'a lost selection without a journal is not attached to an arbitrary route',
    () async {
      picker.lost = original.path;
      await photos.initialize();
      expect(await photos.getPhotos(routeId), isEmpty);
      expect(await original.exists(), isTrue);
    },
  );

  test(
    'relative names keep photos readable after the app directory moves',
    () async {
      await capture();
      await photos.dispose();
      final relocated = await Directory('${directory.path}/photos')
          .rename('${directory.path}/relocated-photos');
      files = TestFiles(relocated);
      photos = create();
      final photo = (await photos.getPhotos(routeId)).single;
      expect(photo.path, startsWith(relocated.path));
      expect(await File(photo.path).exists(), isTrue);
    },
  );

  test(
    'concurrent captures are rejected; disposal joins an accepted capture',
    () async {
      picker.gate = Completer<String?>();
      final pending = capture();
      await picker.entered.future;
      await storage.routes.addPoint(
        routeId: routeId,
        latitude: 56.1,
        longitude: 60,
        timestamp: location.timestamp.add(const Duration(seconds: 1)),
      );
      expect(
        (await storage.routes.getById(routeId))!.routePoints,
        hasLength(2),
      );
      await expectLater(capture(), throwsStateError);
      var closed = false;
      final closing = photos.dispose().then((_) => closed = true);
      await Future<void>.delayed(Duration.zero);
      expect(closed, isFalse);
      picker.gate!.complete(original.path);
      await pending;
      await closing;
      expect(await storage.routePhotos.getForRoute(routeId), hasLength(1));
      await expectLater(photos.getPhotos(routeId), throwsStateError);
    },
  );

  test('photo deletion removes only the owned copy, not the original or other routes', () async {
    await capture();
    final photo = (await photos.getPhotos(routeId)).single;
    await photos.deletePhoto(routeId + 1, photo.id);
    expect(await photos.getPhotos(routeId), hasLength(1));
    await photos.deletePhoto(routeId, photo.id);
    expect(await File(photo.path).exists(), isFalse);
    expect(await original.exists(), isTrue);
  });

  test('route deletion cascades metadata and cleans files', () async {
    await capture();
    final path = (await photos.getPhotos(routeId)).single.path;
    final routes = RoutesRepository(sqliteStorage: storage, photos: photos);
    await expectLater(routes.deleteRoute(routeId), throwsStateError);
    await routes.finishRoute(routeId, location.timestamp);
    await routes.deleteRoute(routeId);
    expect(await storage.routePhotos.getForRoute(routeId), isEmpty);
    expect(await File(path).exists(), isFalse);
    expect(await original.exists(), isTrue);
  });

  test(
    'completed routes and invalid coordinates never launch the picker',
    () async {
      await expectLater(
        photos.capture(
          routeId: routeId,
          location: LocationDM(
            id: 'bad',
            latitude: double.nan,
            longitude: 0,
            timestamp: location.timestamp,
          ),
          source: PhotoSource.camera,
        ),
        throwsArgumentError,
      );
      await storage.routes.complete(routeId, location.timestamp);
      await expectLater(capture(), throwsStateError);
      expect(picker.calls, 0);
    },
  );

  test(
    'discard clears a failed import; cleanup never touches unrelated files',
    () async {
      files.fail = true;
      await expectLater(capture(), throwsA(isA<FileSystemException>()));
      final pending = (await storage.routePhotos.getPending())!;
      final temporary = File('${await files.resolve(pending.fileName)}.tmp');
      await temporary.parent.create(recursive: true);
      await temporary.writeAsBytes([1]);
      final unrelated = await File('${temporary.parent.path}/unrelated.txt')
          .writeAsString('keep');
      await photos.discardPending();
      expect(await storage.routePhotos.getPending(), isNull);
      expect(await temporary.exists(), isFalse);
      expect(await original.exists(), isTrue);
      expect(await unrelated.exists(), isTrue);
      await expectLater(files.resolve('../escape.image'), throwsArgumentError);
    },
  );
}

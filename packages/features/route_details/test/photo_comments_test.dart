import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_details/src/route_details_cubit.dart';

import '../../map/test/fakes.dart';
import 'timeline_fakes.dart';

void main() {
  late CommentPhotosRepository photos;
  late FakeRoutesRepository routes;
  late RouteDetailsCubit cubit;
  setUp(() async {
    photos = CommentPhotosRepository()..photos.add(timelinePhoto());
    routes = FakeRoutesRepository()..saved[1] = timelineRoute();
    cubit = RouteDetailsCubit(
      repository: routes,
      routeId: 1,
      photosRepository: photos,
    );
    await cubit.load();
  });
  tearDown(() async {
    await cubit.close();
    await photos.dispose();
  });

  test('comment save keeps route name draft, blocks duplicates and updates another screen', () async {
    final other = RouteDetailsCubit(
      repository: routes,
      routeId: 1,
      photosRepository: photos,
    );
    addTearDown(other.close);
    await other.load();
    cubit.changeName('Unsaved route name');
    photos.saveGate = Completer<void>();
    final pending = cubit.updatePhotoComment('photo', '  By the river  ');
    expect((cubit.state as RouteDetailsReady).photoBusy, isTrue);
    expect(await cubit.updatePhotoComment('photo', 'duplicate'), isFalse);
    expect(await cubit.deletePhoto('photo'), isFalse);
    await cubit.load();
    expect(cubit.state, isA<RouteDetailsReady>());
    photos.saveGate!.complete();
    expect(await pending, isTrue);
    await Future<void>.delayed(Duration.zero);
    final state = cubit.state as RouteDetailsReady;
    expect(state.name, 'Unsaved route name');
    expect(state.dirty, isTrue);
    expect(state.photos.single.comment, 'By the river');
    expect(state.photoBusy, isFalse);
    expect(photos.saves, 1);
    expect(
      (other.state as RouteDetailsReady).photos.single.comment,
      'By the river',
    );
  });

  test('write failure keeps previous comment and supports retry', () async {
    photos.failSave = true;
    expect(await cubit.updatePhotoComment('photo', 'Draft'), isFalse);
    final failed = cubit.state as RouteDetailsReady;
    expect(failed.photos.single.comment, '');
    expect(failed.photoBusy, isFalse);
    expect(failed.photoError, 'Comment could not be saved.');
    photos.failSave = false;
    expect(await cubit.updatePhotoComment('photo', 'Draft'), isTrue);
    expect((cubit.state as RouteDetailsReady).photoError, isNull);
  });

  test('old photo reads cannot overwrite a committed comment', () async {
    final stale = Completer<List<RoutePhotoDM>>();
    photos.readGate = stale;
    final pending = cubit.loadPhotos();
    await cubit.updatePhotoComment('photo', 'New comment');
    await Future<void>.delayed(Duration.zero);
    stale.complete([timelinePhoto()]);
    await pending;
    await Future<void>.delayed(Duration.zero);
    expect(
      (cubit.state as RouteDetailsReady).photos.single.comment,
      'New comment',
    );
  });

  test(
    'closing a screen does not cancel an accepted comment write or emit late',
    () async {
      photos.saveGate = Completer<void>();
      final pending = cubit.updatePhotoComment('photo', 'Keep this');
      await cubit.close();
      final stateAtClose = cubit.state;
      photos.saveGate!.complete();
      expect(await pending, isTrue);
      expect(photos.photos.single.comment, 'Keep this');
      expect(cubit.state, same(stateAtClose));
    },
  );

  test(
    'unknown photos and active routes cannot be edited from route details',
    () async {
      expect(await cubit.updatePhotoComment('missing', 'Comment'), isFalse);
      routes.saved[1] = timelineRoute(status: Status.active);
      await cubit.load();
      expect(await cubit.updatePhotoComment('photo', 'Comment'), isFalse);
      expect(photos.saves, 0);
    },
  );
}

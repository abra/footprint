import 'dart:async';

import 'package:component_library/component_library.dart';
import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_details/route_details.dart';
import 'package:route_details/src/route_details_cubit.dart';
import 'package:routes_repository/routes_repository.dart';

import '../../map/test/fakes.dart';

class TestRoutes extends Fake implements RoutesRepository {
  TestRoutes({String? name = 'Morning walk'})
    : route = RouteDM(
        id: 1,
        name: name,
        startTime: DateTime(2026, 9, 6),
        status: Status.completed,
      );
  RouteDM? route;
  Completer<RouteDM?>? loadGate;
  Completer<void>? saveGate;
  bool fail = false;
  int saves = 0;
  String? savedName;
  @override
  Future<RouteDM?> getRoute(int id) async =>
      loadGate == null ? route : loadGate!.future;
  @override
  Future<void> renameRoute(int id, String name) async {
    saves++;
    await saveGate?.future;
    if (fail) throw StateError('Disk full');
    savedName = name;
  }
}

class TestPhotos extends FakeRoutePhotosRepository {
  bool failLoad = false;
  bool failDelete = false;
  Completer<List<RoutePhotoDM>>? loadGate;
  @override
  Future<List<RoutePhotoDM>> getPhotos(int id) async {
    if (failLoad) throw StateError('Read failed');
    return loadGate == null ? super.getPhotos(id) : loadGate!.future;
  }

  @override
  Future<void> deletePhoto(int routeId, String id) async {
    if (failDelete) throw StateError('Delete failed');
    photos.removeWhere((photo) => photo.routeId == routeId && photo.id == id);
  }
}

void main() {
  for (final keyboard in [false, true]) {
    for (final input in ['', '   ']) {
      testWidgets(
        'optional empty name closes via ${keyboard ? 'keyboard' : 'checkmark'} with ${input.length} spaces',
        (tester) async {
          final repository = TestRoutes(name: null)..fail = true;
          var closes = 0;
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              builder: AppTheme.builder,
              home: RouteDetailsScreen(
                justRecorded: true,
                photosRepository: FakeRoutePhotosRepository(),
                routeId: 1,
                repository: repository,
                onClosed: (value) {
                  expect(value, isTrue);
                  closes++;
                },
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Name this walk (optional)'), findsOneWidget);
          await tester.enterText(find.byType(EditableText), input);
          if (keyboard) {
            await tester.testTextInput.receiveAction(TextInputAction.done);
          } else {
            await tester.tap(find.byTooltip('Save route name'));
          }
          await tester.pumpAndSettle();
          expect(closes, 1);
          expect(repository.saves, 0);
          expect(repository.route!.name, isNull);
          expect(repository.route!.status, Status.completed);
          expect(find.textContaining('characters'), findsNothing);
          expect(find.byType(AppSheet), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }

  test(
    'unchanged name is accepted without persistence or duplicate completion',
    () async {
      final repository = TestRoutes()..fail = true;
      final cubit = RouteDetailsCubit(
        repository: repository,
        routeId: 1,
        photosRepository: FakeRoutePhotosRepository(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.changeName('  Morning walk  ');
      await cubit.save();
      final saved = cubit.state as RouteDetailsReady;
      expect(saved.saved, isTrue);
      expect(saved.name, 'Morning walk');
      expect(saved.error, isNull);
      await cubit.save();
      expect(cubit.state, same(saved));
      expect(repository.saves, 0);
    },
  );

  test(
    'clearing a name persists the change and can retry after failure',
    () async {
      final repository = TestRoutes()..fail = true;
      final cubit = RouteDetailsCubit(
        repository: repository,
        routeId: 1,
        photosRepository: FakeRoutePhotosRepository(),
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.changeName('   ');
      expect((cubit.state as RouteDetailsReady).dirty, isTrue);
      await cubit.save();
      final failed = cubit.state as RouteDetailsReady;
      expect(failed.name, '');
      expect(failed.saved, isFalse);
      expect(failed.saving, isFalse);
      expect(failed.error, contains('Name could not be saved'));
      repository.fail = false;
      await cubit.save();
      expect(repository.savedName, '');
      expect((cubit.state as RouteDetailsReady).saved, isTrue);
      expect((cubit.state as RouteDetailsReady).error, isNull);
    },
  );

  testWidgets('recorded route is already saved and naming is optional', (
    tester,
  ) async {
    final repository = TestRoutes();
    bool? closed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: RouteDetailsScreen(
          justRecorded: true,
          photosRepository: FakeRoutePhotosRepository(),
          routeId: 1,
          repository: repository,
          onClosed: (value) => closed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Route saved'), findsOneWidget);
    expect(find.text('Name this walk (optional)'), findsOneWidget);
    expect(find.text('Save route'), findsNothing);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(find.byType(AppSheet), findsNothing);
    expect(repository.route, isNotNull);
    expect(repository.saves, 0);
  });

  testWidgets('renaming retains the checkmark and exposes pending status', (
    tester,
  ) async {
    final repository = TestRoutes()..saveGate = Completer<void>();
    bool? closed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: RouteDetailsScreen(
          justRecorded: true,
          photosRepository: FakeRoutePhotosRepository(),
          routeId: 1,
          repository: repository,
          onClosed: (value) => closed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Evening');
    final save = find.byWidgetPredicate(
      (widget) =>
          widget is AppIconButton && widget.tooltip == 'Save route name',
    );
    final icon = tester.widget<AppIconButton>(save).icon as Icon;
    await tester.tap(save);
    await tester.pumpAndSettle();
    expect(tester.widget<AppIconButton>(save).onPressed, isNull);
    expect((tester.widget<AppIconButton>(save).icon as Icon).icon, icon.icon);
    expect(find.text('Saving name...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(closed, isNull);
    repository.saveGate!.complete();
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(repository.savedName, 'Evening');
  });

  final photo = RoutePhotoDM(
    id: 'photo',
    routeId: 1,
    path: '/missing.png',
    latitude: 56,
    longitude: 60,
    capturedAt: DateTime(2026),
  );
  test('photo load failure preserves name edits and can be retried', () async {
    final photos = TestPhotos()..failLoad = true;
    final cubit = RouteDetailsCubit(
      repository: TestRoutes(),
      routeId: 1,
      photosRepository: photos,
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeName('Edited route');
    expect((cubit.state as RouteDetailsReady).photoError, isNotNull);
    photos.failLoad = false;
    photos.photos.add(photo);
    await cubit.loadPhotos();
    final state = cubit.state as RouteDetailsReady;
    expect(state.name, 'Edited route');
    expect(state.photos, [photo]);
    expect(state.photoError, isNull);
  });
  test(
    'failed photo deletion retains the photo and edited route name',
    () async {
      final photos = TestPhotos()
        ..photos.add(photo)
        ..failDelete = true;
      final cubit = RouteDetailsCubit(
        repository: TestRoutes(),
        routeId: 1,
        photosRepository: photos,
      );
      addTearDown(cubit.close);
      await cubit.load();
      cubit.changeName('Edited route');
      expect(await cubit.deletePhoto(photo.id), isFalse);
      expect((cubit.state as RouteDetailsReady).photos, [photo]);
      expect((cubit.state as RouteDetailsReady).photoBusy, isFalse);
      photos.failDelete = false;
      expect(await cubit.deletePhoto(photo.id), isTrue);
      expect((cubit.state as RouteDetailsReady).photos, isEmpty);
      expect((cubit.state as RouteDetailsReady).name, 'Edited route');
    },
  );
  test('late photo results are ignored after screen closes', () async {
    final photos = TestPhotos();
    final cubit = RouteDetailsCubit(
      repository: TestRoutes(),
      routeId: 1,
      photosRepository: photos,
    );
    await cubit.load();
    photos.loadGate = Completer<List<RoutePhotoDM>>();
    final pending = cubit.loadPhotos();
    await cubit.close();
    photos.loadGate!.complete([photo]);
    await pending;
    expect((cubit.state as RouteDetailsReady).photos, isEmpty);
  });
  testWidgets(
    'saved route gallery opens viewer and removes a confirmed photo',
    (tester) async {
      final photos = TestPhotos()..photos.add(photo);
      await tester.pumpWidget(
        MaterialApp(
          builder: AppTheme.builder,
          home: RouteDetailsScreen(
            routeId: 1,
            repository: TestRoutes(),
            photosRepository: photos,
            onClosed: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      final thumbnail = find.byKey(const ValueKey('route-photo-photo'));
      await tester.ensureVisible(thumbnail);
      await tester.pumpAndSettle();
      await tester.tap(thumbnail);
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsOneWidget);
      await tester.tap(find.byTooltip('Delete photo'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.byType(PageView), findsNothing);
      expect(photos.photos, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
  test('save validates, rejects concurrent submits, and trims names', () async {
    final repository = TestRoutes()..saveGate = Completer<void>();
    final cubit = RouteDetailsCubit(
      photosRepository: FakeRoutePhotosRepository(),
      repository: repository,
      routeId: 1,
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeName('a' * 81);
    await cubit.save();
    expect((cubit.state as RouteDetailsReady).error, isNotNull);
    expect(repository.saves, 0);
    cubit.changeName('  New route  ');
    final pending = cubit.save();
    await cubit.save();
    cubit.changeName('Ignored while saving');
    expect(repository.saves, 1);
    repository.saveGate!.complete();
    await pending;
    expect(repository.savedName, 'New route');
    expect((cubit.state as RouteDetailsReady).saved, isTrue);
  });
  test('failed save retains input and can be retried', () async {
    final repository = TestRoutes()..fail = true;
    final cubit = RouteDetailsCubit(
      photosRepository: FakeRoutePhotosRepository(),
      repository: repository,
      routeId: 1,
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeName('Trail');
    await cubit.save();
    expect((cubit.state as RouteDetailsReady).name, 'Trail');
    expect((cubit.state as RouteDetailsReady).saving, isFalse);
    repository.fail = false;
    await cubit.save();
    expect(repository.savedName, 'Trail');
  });
  test('missing route and late result after close are handled', () async {
    final repository = TestRoutes()..route = null;
    final cubit = RouteDetailsCubit(
      photosRepository: FakeRoutePhotosRepository(),
      repository: repository,
      routeId: 1,
    );
    await cubit.load();
    expect(cubit.state, isA<RouteDetailsFailure>());
    repository.loadGate = Completer<RouteDM?>();
    final load = cubit.load();
    await cubit.close();
    repository.loadGate!.complete(null);
    await load;
  });
  test('active route is read-only', () async {
    final repository = TestRoutes()
      ..route = RouteDM(
        id: 1,
        startTime: DateTime(2026),
        status: Status.active,
      );
    final cubit = RouteDetailsCubit(
      photosRepository: FakeRoutePhotosRepository(),
      repository: repository,
      routeId: 1,
    );
    addTearDown(cubit.close);
    await cubit.load();
    cubit.changeName('Test');
    await cubit.save();
    expect(repository.saves, 0);
  });
  testWidgets('back asks about dirty name; discard never deletes the route', (
    tester,
  ) async {
    final repository = TestRoutes();
    bool? closed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: RouteDetailsScreen(
          photosRepository: FakeRoutePhotosRepository(),
          routeId: 1,
          repository: repository,
          onClosed: (value) => closed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Changed');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard name changes?'), findsOneWidget);
    await tester.tap(find.text('Keep editing'));
    await tester.pumpAndSettle();
    expect(closed, isNull);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard changes'));
    await tester.pumpAndSettle();
    expect(closed, isFalse);
    expect(repository.route!.name, 'Morning walk');
    expect(repository.saves, 0);
  });
  testWidgets('checkmark saves edited name and returns success', (
    tester,
  ) async {
    final repository = TestRoutes();
    bool? closed;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: RouteDetailsScreen(
          photosRepository: FakeRoutePhotosRepository(),
          routeId: 1,
          repository: repository,
          onClosed: (value) => closed = value,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear name'));
    await tester.enterText(find.byType(EditableText), 'Forest walk');
    await tester.tap(find.byTooltip('Save route name'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(repository.savedName, 'Forest walk');
  });

  testWidgets('cursor movement preserves a save error until the name changes', (
    tester,
  ) async {
    final repository = TestRoutes()..fail = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: AppTheme.builder,
        home: RouteDetailsScreen(
          photosRepository: FakeRoutePhotosRepository(),
          routeId: 1,
          repository: repository,
          onClosed: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(EditableText), 'Forest walk');
    await tester.tap(find.byTooltip('Save route name'));
    await tester.pumpAndSettle();
    final field = tester.widget<EditableText>(find.byType(EditableText));
    final error = find.text(
      'Name could not be saved. Your recorded route is still available.',
    );
    expect(error, findsOneWidget);
    field.controller.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();
    expect(error, findsOneWidget);
    await tester.enterText(find.byType(EditableText), 'Evening walk');
    await tester.pumpAndSettle();
    expect(error, findsNothing);
    repository.fail = false;
    await tester.tap(find.byTooltip('Save route name'));
    await tester.pumpAndSettle();
    expect(repository.savedName, 'Evening walk');
  });
}

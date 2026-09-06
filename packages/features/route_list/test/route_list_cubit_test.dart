import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_list/src/route_list_cubit.dart';
import 'package:routes_repository/routes_repository.dart';

class PageRepository extends Fake implements RoutesRepository {
  final requests = <({String query, RouteSort sort, int offset})>[];
  final deleted = <int>[];
  Future<List<RouteDM>> Function(int) response = (_) async => [];
  @override
  Future<List<RouteDM>> getRoutePage({
    String query = '',
    RouteSort sort = RouteSort.newest,
    int offset = 0,
    int limit = 20,
  }) {
    requests.add((query: query, sort: sort, offset: offset));
    return response(offset);
  }

  @override
  Future<void> deleteRoute(int id) async {
    deleted.add(id);
  }
}

RouteDM route(int id, {Status status = Status.completed}) =>
    RouteDM(id: id, startTime: DateTime(2026), status: status);

void main() {
  test(
    'pagination appends and preserves entries when next page fails',
    () async {
      final repository = PageRepository()
        ..response = (_) async => List.generate(20, route);
      final cubit = RouteListCubit(routesRepository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      repository.response = (_) async => throw StateError('Read failed');
      await cubit.loadMore();
      expect((cubit.state as RouteListLoaded).routes, hasLength(20));
      expect((cubit.state as RouteListLoaded).error, isNotNull);
      repository.response = (_) async => [route(20)];
      await cubit.loadMore();
      expect((cubit.state as RouteListLoaded).routes, hasLength(21));
      expect((cubit.state as RouteListLoaded).hasMore, isFalse);
      expect(repository.requests.last.offset, 20);
    },
  );
  test('newest load wins over a delayed earlier response', () async {
    final gate = Completer<List<RouteDM>>();
    final repository = PageRepository()..response = (_) => gate.future;
    final cubit = RouteListCubit(routesRepository: repository);
    addTearDown(cubit.close);
    final stale = cubit.load();
    repository.response = (_) async => [route(2)];
    await cubit.load();
    gate.complete([route(1)]);
    await stale;
    expect((cubit.state as RouteListLoaded).routes.single.id, 2);
  });
  testWidgets('search coalesces input and pagination cannot mix queries', (
    tester,
  ) async {
    final repository = PageRepository()
      ..response = (_) async => List.generate(20, route);
    final cubit = RouteListCubit(routesRepository: repository);
    await cubit.load();
    cubit.search('f');
    cubit.search('fo');
    cubit.search('forest');
    await cubit.loadMore();
    await tester.pump(const Duration(milliseconds: 301));
    expect(repository.requests.map((r) => r.query), ['', 'forest']);
    expect(repository.requests.last.offset, 0);
    cubit.sortBy(RouteSort.oldest);
    await tester.pump();
    expect(repository.requests.last.sort, RouteSort.oldest);
    cubit.search('cancelled');
    await cubit.close();
    await tester.pump(const Duration(seconds: 1));
    expect(repository.requests, hasLength(3));
  });
  test(
    'active routes are protected; saved routes are deleted and reloaded',
    () async {
      final repository = PageRepository()..response = (_) async => [route(1)];
      final cubit = RouteListCubit(routesRepository: repository);
      addTearDown(cubit.close);
      await cubit.load();
      await cubit.delete(route(2, status: Status.active));
      expect(repository.deleted, isEmpty);
      await cubit.delete(route(1));
      expect(repository.deleted, [1]);
      expect(repository.requests, hasLength(2));
    },
  );
}

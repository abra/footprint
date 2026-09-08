import 'package:component_library/component_library.dart';

import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:route_list/route_list.dart';
import 'package:route_list/src/route_list_cubit.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:route_snapshots/route_snapshots.dart';

import '../../../route_snapshots/test/fakes.dart';

class TestRoutes extends Fake implements RoutesRepository {
  Future<List<RouteDM>> Function() response = () async => [];
  @override
  Future<List<RouteDM>> getRoutePage({
    String query = '',
    RouteSort sort = RouteSort.newest,
    int offset = 0,
    int limit = 20,
  }) => response();
}

void main() {
  late RouteSnapshotRepository snapshots;
  setUp(() {
    snapshots = unavailableSnapshots();
    addTearDown(snapshots.dispose);
  });
  testWidgets('list renders loading, error, retry and empty states', (
    tester,
  ) async {
    final result = Completer<List<RouteDM>>();
    final repository = TestRoutes()..response = () => result.future;
    await tester.pumpWidget(
      MaterialApp(
        builder: AppTheme.builder,
        home: RouteListScreen(
          snapshots: snapshots,
          routesRepository: repository,
          onPageChangeRequested: () {},
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    result.completeError(Exception('Database unavailable'));
    await tester.pumpAndSettle();
    expect(find.text('Routes could not be loaded.'), findsOneWidget);
    repository.response = () async => [];
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('No recorded routes'), findsOneWidget);
  });

  testWidgets('list shows saved and active records and invokes navigation', (
    tester,
  ) async {
    var navigated = false;
    final repository = TestRoutes()
      ..response = () async => [
        RouteDM(
          id: 1,
          name: 'Morning walk',
          startTime: DateTime(2026, 9, 6),
          status: Status.completed,
        ),
        RouteDM(id: 2, startTime: DateTime(2026, 9, 6), status: Status.active),
      ];
    await tester.pumpWidget(
      MaterialApp(
        builder: AppTheme.builder,
        home: RouteListScreen(
          snapshots: snapshots,
          routesRepository: repository,
          onPageChangeRequested: () => navigated = true,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Morning walk'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Recording'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('Recording'), findsOneWidget);
    await tester.tap(find.byTooltip('Back to map'));
    await tester.pumpAndSettle();
    expect(navigated, isTrue);
  });

  test('list ignores completion after cubit disposal', () async {
    final result = Completer<List<RouteDM>>();
    final repository = TestRoutes()..response = () => result.future;
    final cubit = RouteListCubit(routesRepository: repository);
    final loading = cubit.load();
    await cubit.close();
    result.complete([]);
    await loading;
    expect(cubit.isClosed, isTrue);
  });
}

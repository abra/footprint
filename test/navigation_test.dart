import 'package:flutter/cupertino.dart' show CupertinoPageTransition;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/config/application_config.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:footprint/app/routing.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';
import 'package:route_details/src/route_details_view.dart';
import 'package:route_list/src/route_list_cubit.dart';
import 'package:route_list/src/route_list_view.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:domain_models/domain_models.dart';
import 'package:statistics/src/statistics_cubit.dart';
import 'package:statistics/src/statistics_view.dart';

import '../packages/features/map/test/fakes.dart';
import '../packages/features/map/test/pump_recording_ui.dart';

final class NavigationDependencies extends TestDependenciesContainer {
  NavigationDependencies(this._service) {
    _recording = RecordingService(
      locationService: _service,
      routesRepository: _routes,
    );
  }
  final FakeLocationService _service;
  final _routes = FakeRoutesRepository();
  @override
  WalksRepository get walksRepository => _walks;
  final _walks = _NavigationWalks();
  final _photos = FakeRoutePhotosRepository();
  @override
  FakeRoutePhotosRepository get photosRepository => _photos;
  final _geocoding = FakeGeocodingManager();
  late final RecordingService _recording;
  @override
  RecordingService get recordingService => _recording;
  @override
  FakeLocationService get foregroundLocationService => _service;
  @override
  FakeRoutesRepository get routesRepository => _routes;
  @override
  FakeGeocodingManager get geocodingManager => _geocoding;
  @override
  ApplicationConfig get config => const ApplicationConfig();
}

class _NavigationWalks extends Fake implements WalksRepository {
  @override
  Future<WalkProgress?> getProgress(int routeId) async => null;
}

Future<void> withRecordingNavigation(
  WidgetTester tester,
  Future<void> Function(FakeLocationService, GoRouter, MapCubit) test,
) async {
  final service = FakeLocationService();
  final dependencies = NavigationDependencies(service);
  final router = buildRouter(dependencies: dependencies);
  try {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    service.send(location(1));
    await tester.pump(const Duration(milliseconds: 400));
    final mapContext = tester.element(find.byType(MapView));
    expect(ModalRoute.of(mapContext)!.settings, isA<MaterialPage<void>>());
    final cubit = mapContext.read<MapCubit>();
    await tester.tap(find.text('Record route'));
    await tester.pump();
    expect(cubit.state.isRecording, isTrue);
    await test(service, router, cubit);
    expect(tester.takeException(), isNull);
  } finally {
    await tester.pumpWidget(const SizedBox.shrink());
    await pumpRecordingUi(tester);
    router.dispose();
    await tester.runAsync(() async {
      await dependencies.recordingService.dispose();
      await service.dispose();
    });
  }
}

void main() {
  testWidgets(
    'statistics round trip preserves history, camera and active recording',
    (tester) => withRecordingNavigation(tester, (service, router, cubit) async {
      await tester.tap(find.byTooltip('Routes'));
      await pumpRecordingUi(tester);
      final listCubit = tester
          .element(find.byType(RouteListView))
          .read<RouteListCubit>();
      await tester.enterText(find.byType(TextField), 'recording');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Statistics'));
      await pumpRecordingUi(tester);
      final context = tester.element(find.byType(StatisticsView));
      expect(ModalRoute.of(context)!.settings, isA<MaterialPage<void>>());
      final statistics = context.read<StatisticsCubit>();
      expect(statistics.state.data!.totals.routes, 0);
      service.send(location(2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Back to routes'));
      await pumpRecordingUi(tester);
      expect(statistics.isClosed, isTrue);
      expect(
        tester.element(find.byType(RouteListView)).read<RouteListCubit>(),
        same(listCubit),
      );
      expect(listCubit.query, 'recording');
      await tester.tap(find.byTooltip('Back to map'));
      await pumpRecordingUi(tester);
      expect(cubit.state.isRecording, isTrue);
      expect(cubit.state.points, hasLength(2));
      expect(service.disposed, isFalse);
    }),
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'platform pages retain the map and recording on a routes round trip',
    (tester) => withRecordingNavigation(tester, (service, router, cubit) async {
      await tester.tap(find.byTooltip('Routes'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      final list = find.byType(RouteListView);
      final context = tester.element(list);
      final route = ModalRoute.of(context)! as PageRoute<void>;
      expect(route.settings, isA<MaterialPage<void>>());
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoPageTransition), findsWidgets);
        expect(tester.getTopLeft(list).dx, greaterThan(0));
        expect(
          tester.getTopLeft(list).dx,
          lessThan(tester.getSize(list).width),
        );
      }
      await pumpRecordingUi(tester);
      expect(find.text('Recording'), findsOneWidget);
      expect(cubit.isClosed, isFalse);
      expect(service.disposed, isFalse);
      service.send(location(2));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.byTooltip('Back to map'));
      await pumpRecordingUi(tester);
      expect(
        tester.element(find.byType(MapView)).read<MapCubit>(),
        same(cubit),
      );
      expect(cubit.state.points, hasLength(2));
      expect(find.text('Stop recording'), findsOneWidget);
      expect(router.canPop(), isFalse);
    }),
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  testWidgets(
    'Android system back returns to the recording map',
    (tester) => withRecordingNavigation(tester, (service, router, cubit) async {
      await tester.tap(find.byTooltip('Routes'));
      await pumpRecordingUi(tester);
      await tester.binding.handlePopRoute();
      await pumpRecordingUi(tester);
      expect(router.canPop(), isFalse);
      expect(find.byType(RouteListView), findsNothing);
      expect(
        tester.element(find.byType(MapView)).read<MapCubit>(),
        same(cubit),
      );
      expect(cubit.state.isRecording, isTrue);
      expect(service.disposed, isFalse);
    }),
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  testWidgets(
    'details use a platform page and return a typed result to the same list',
    (tester) => withRecordingNavigation(tester, (service, router, cubit) async {
      await tester.tap(find.byTooltip('Routes'));
      await pumpRecordingUi(tester);
      final list = find.byType(RouteListView);
      final listCubit = tester.element(list).read<RouteListCubit>();
      final result = router.push<bool>('${AppRoutes.routes}/1');
      await pumpRecordingUi(tester);
      final detailsContext = tester.element(find.byType(RouteDetailsView));
      final route = ModalRoute.of(detailsContext)! as PageRoute<bool>;
      expect(route.settings, isA<MaterialPage<bool>>());
      expect(route.settings.name, '${AppRoutes.routes}/:id');
      expect(route.settings.arguments, {'id': '1'});
      if (Theme.of(detailsContext).platform == TargetPlatform.iOS) {
        expect(find.byType(CupertinoPageTransition), findsWidgets);
        expect(route.popGestureEnabled, isTrue);
      }
      await tester.tap(find.byTooltip('Back'));
      await pumpRecordingUi(tester);
      expect(await result, isFalse);
      expect(tester.element(list).read<RouteListCubit>(), same(listCubit));
      expect(listCubit.isClosed, isFalse);
      expect(cubit.isClosed, isFalse);
      expect(cubit.state.isRecording, isTrue);
      expect(service.disposed, isFalse);
    }),
    variant: const TargetPlatformVariant({
      TargetPlatform.iOS,
      TargetPlatform.android,
    }),
  );

  for (final complete in [false, true]) {
    testWidgets(
      'iOS back swipe ${complete ? 'completes' : 'cancels'} without losing map state',
      (tester) => withRecordingNavigation(tester, (
        service,
        router,
        cubit,
      ) async {
        cubit.setCentered(false);
        final controller = tester
            .widget<FlutterMap>(find.byType(FlutterMap))
            .mapController!;
        const center = LatLng(10, 20);
        controller.move(center, 14);
        await tester.tap(find.byKey(const ValueKey('recording-stats-panel')));
        await pumpRecordingUi(tester);
        expect(cubit.state.statsExpanded, isTrue);
        await tester.tap(find.byTooltip('Routes'));
        await pumpRecordingUi(tester);
        final list = find.byType(RouteListView);
        final listContext = tester.element(list);
        final listCubit = listContext.read<RouteListCubit>();
        final route = ModalRoute.of(listContext)! as PageRoute<void>;
        expect(route.popGestureEnabled, isTrue);
        final size = tester.getSize(list);
        final gesture = await tester.startGesture(Offset(4, size.height / 2));
        try {
          // Resolve the edge swipe against the list's scroll recognizer.
          await gesture.moveBy(const Offset(24, 0));
          await tester.pump();
          await gesture.moveBy(
            Offset(size.width * 0.7, 0),
            timeStamp: const Duration(milliseconds: 100),
          );
          await tester.pump();
          expect(route.navigator!.userGestureInProgress, isTrue);
          expect(tester.getTopLeft(list).dx, closeTo(size.width * 0.7, 0.1));
          service.send(location(2));
          await tester.pump(const Duration(milliseconds: 100));
          if (!complete) {
            await gesture.moveBy(
              Offset(-size.width * 0.6, 0),
              timeStamp: const Duration(milliseconds: 300),
            );
            await tester.pump();
            expect(tester.getTopLeft(list).dx, closeTo(size.width * 0.1, 0.1));
          }
        } finally {
          await gesture.up(timeStamp: const Duration(milliseconds: 800));
        }
        await pumpRecordingUi(tester);
        if (!complete) {
          expect(router.canPop(), isTrue);
          expect(tester.getTopLeft(list).dx, closeTo(0, 0.01));
          expect(tester.element(list).read<RouteListCubit>(), same(listCubit));
          expect(listCubit.isClosed, isFalse);
          await tester.tap(find.byTooltip('Back to map'));
          await pumpRecordingUi(tester);
        }
        expect(router.canPop(), isFalse);
        expect(list, findsNothing);
        expect(listCubit.isClosed, isTrue);
        expect(
          tester.element(find.byType(MapView)).read<MapCubit>(),
          same(cubit),
        );
        expect(
          tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController,
          same(controller),
        );
        expect(controller.camera.center, center);
        expect(controller.camera.zoom, 14);
        expect(cubit.state.statsExpanded, isTrue);
        expect(cubit.state.isRecording, isTrue);
        expect(cubit.state.points, hasLength(2));
        expect(service.disposed, isFalse);
      }),
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }
}

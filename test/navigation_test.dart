import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:footprint/app/config/application_config.dart';
import 'package:footprint/app/dependency_container.dart';
import 'package:footprint/app/routing.dart';
import 'package:map/src/map_cubit.dart';
import 'package:map/src/map_view.dart';
import 'package:recording_service/recording_service.dart';

import '../packages/features/map/test/fakes.dart';

final class NavigationDependencies extends TestDependenciesContainer {
  NavigationDependencies(this._service) {
    _recording = RecordingService(
      locationService: _service,
      routesRepository: _routes,
    );
  }
  final FakeLocationService _service;
  final _routes = FakeRoutesRepository();
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

void main() {
  testWidgets('routes round trip retains map cubit and active recording', (
    tester,
  ) async {
    final service = FakeLocationService();
    final dependencies = NavigationDependencies(service);
    final router = buildRouter(dependencies: dependencies);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();
    service.send(location(1));
    await tester.pump(const Duration(milliseconds: 400));
    final mapContext = tester.element(find.byType(MapView));
    final cubit = mapContext.read<MapCubit>();
    await tester.tap(find.text('Record route'));
    await tester.pump();
    expect(cubit.state.isRecording, isTrue);
    await tester.tap(find.byTooltip('Routes'));
    await tester.pumpAndSettle();
    expect(find.text('Recording'), findsOneWidget);
    expect(cubit.isClosed, isFalse);
    expect(service.disposed, isFalse);
    service.send(location(2));
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Back to map'));
    await tester.pumpAndSettle();
    expect(tester.element(find.byType(MapView)).read<MapCubit>(), same(cubit));
    expect(cubit.state.points, hasLength(2));
    expect(find.text('Stop recording'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    router.dispose();
    await tester.runAsync(() async {
      await dependencies.recordingService.dispose();
      await service.dispose();
    });
  });
}

import 'dart:async';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:map/src/map_cubit.dart';
import 'package:recording_service/recording_service.dart';
import 'package:routes_repository/routes_repository.dart';

import 'fakes.dart';

class TestPhotos extends FakeRoutePhotosRepository {
  Completer<void>? captureGate;
  Completer<List<RoutePhotoDM>>? loadGate;
  Object? error;
  int captures = 0;
  int retries = 0;
  @override
  Future<List<RoutePhotoDM>> getPhotos(int id) async =>
      loadGate == null ? super.getPhotos(id) : loadGate!.future;
  @override
  Future<void> retryPending() async => retries++;
  @override
  Future<void> capture({
    required int routeId,
    required LocationDM location,
    required PhotoSource source,
  }) async {
    captures++;
    await captureGate?.future;
    if (error case final error?) throw error;
    photos.add(
      RoutePhotoDM(
        id: 'photo',
        routeId: routeId,
        path: '/fixture/photo.png',
        latitude: location.latitude,
        longitude: location.longitude,
        capturedAt: location.timestamp,
      ),
    );
  }
}

void main() {
  late FakeLocationService service;
  late RecordingService recording;
  late TestPhotos photos;
  late MapCubit cubit;
  setUp(() async {
    service = FakeLocationService()..lastLocation = location(1);
    recording = RecordingService(
      locationService: service,
      routesRepository: FakeRoutesRepository(),
    );
    photos = TestPhotos();
    cubit = MapCubit(
      recordingService: recording,
      geocodingManager: FakeGeocodingManager(),
      photosRepository: photos,
    );
    await cubit.initialize();
    await cubit.startRecording();
    if (!cubit.state.isRecording || cubit.state.recordingBusy) {
      await cubit.stream.firstWhere(
        (state) => state.isRecording && !state.recordingBusy,
      );
    }
  });
  tearDown(() async {
    await cubit.close();
    await recording.dispose();
    await service.dispose();
  });

  test('capture pins the button-time location and prevents concurrent capture or stop', () async {
    photos.captureGate = Completer<void>();
    final pending = cubit.capturePhoto(PhotoSource.camera);
    service.send(location(2));
    await Future<void>.delayed(Duration.zero);
    await cubit.capturePhoto(PhotoSource.gallery);
    await cubit.stopRecording();
    expect(photos.captures, 1);
    expect(cubit.state.isRecording, isTrue);
    expect(cubit.state.photoBusy, isTrue);
    expect(cubit.state.points, hasLength(2));
    photos.captureGate!.complete();
    await pending;
    expect(cubit.state.photos.single.latitude, location(1).latitude);
    expect(cubit.state.photoBusy, isFalse);
    await cubit.stopRecording();
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.photos, isEmpty);
  });

  test('photo failure stays independent from GPS and recording errors, and retries', () async {
    photos.error = const PhotoSelectionException('Camera denied');
    await cubit.capturePhoto(PhotoSource.camera);
    expect(cubit.state.photoError, 'Camera denied');
    expect(cubit.state.error, isNull);
    service.send(location(2));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.photoError, 'Camera denied');
    expect(cubit.state.isRecording, isTrue);
    await cubit.retryPhotos();
    expect(cubit.state.photoError, isNull);
    expect(photos.retries, 2);
  });

  test(
    'closing the map does not cancel capture persistence or emit late state',
    () async {
      photos.captureGate = Completer<void>();
      final pending = cubit.capturePhoto(PhotoSource.gallery);
      await cubit.close();
      photos.captureGate!.complete();
      await pending;
      expect(photos.photos, hasLength(1));
      expect(recording.state.isRecording, isTrue);
    },
  );

  test(
    'photo result for a previous route cannot overwrite the idle map',
    () async {
      photos.loadGate = Completer<List<RoutePhotoDM>>();
      final reload = cubit.retryPhotos();
      await Future<void>.delayed(Duration.zero);
      await recording.stop();
      photos.loadGate!.complete([
        RoutePhotoDM(
          id: 'old',
          routeId: 1,
          path: '/old',
          latitude: 0,
          longitude: 0,
          capturedAt: location(1).timestamp,
        ),
      ]);
      await reload;
      expect(cubit.state.photos, isEmpty);
      expect(cubit.state.isRecording, isFalse);
    },
  );
}

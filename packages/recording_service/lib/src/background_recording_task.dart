import 'dart:async';
import 'dart:developer';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:foreground_location_service/foreground_location_service.dart';
import 'package:routes_repository/routes_repository.dart';
import 'package:sqlite_storage/sqlite_storage.dart';

import 'background_recording_worker.dart';

@pragma('vm:entry-point')
void startRecordingTask() {
  FlutterForegroundTask.setTaskHandler(BackgroundRecordingTask());
}

class BackgroundRecordingTask extends TaskHandler {
  SqliteStorage? _storage;
  BackgroundRecordingWorker? _worker;
  Future<void>? _initialization;
  Object? _startupError;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) =>
      _initialization = _start();

  Future<void> _start() async {
    try {
      final storage = await SqliteStorage.open();
      _storage = storage;
      final worker = BackgroundRecordingWorker(
        routesRepository: RoutesRepository(sqliteStorage: storage),
        onSaved: (location) => FlutterForegroundTask.sendDataToMain(
          LocationTaskMessage.forLocation(location),
        ),
        onError: _report,
      );
      _worker = worker;
      await worker.start(
        DeviceLocation().positions(apple: false, background: true),
      );
      FlutterForegroundTask.sendDataToMain(LocationTaskMessage.ready());
    } on Object catch (error, stack) {
      _startupError = error;
      _report(error, stack);
    }
  }

  void _report(Object error, StackTrace stack) {
    log(
      'Background recording failed',
      name: 'BackgroundRecordingTask',
      error: error,
      stackTrace: stack,
    );
    FlutterForegroundTask.sendDataToMain(LocationTaskMessage.forError(error));
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;
    switch (data['command']) {
      case 'status':
        unawaited(_reportStatus());
      case 'stop':
        unawaited(_stop());
    }
  }

  Future<void> _reportStatus() async {
    await _initialization;
    FlutterForegroundTask.sendDataToMain(
      _startupError == null
          ? LocationTaskMessage.ready()
          : LocationTaskMessage.forError(_startupError!),
    );
  }

  Future<void> _stop() async {
    try {
      await _initialization;
      await _worker?.stop();
      FlutterForegroundTask.sendDataToMain(LocationTaskMessage.stopped());
    } on Object catch (error, stack) {
      _report(error, stack);
      FlutterForegroundTask.sendDataToMain(LocationTaskMessage.stopped(error));
    }
  }

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    await _initialization;
    try {
      await _worker?.stop();
    } finally {
      await _storage?.close();
    }
  }
}

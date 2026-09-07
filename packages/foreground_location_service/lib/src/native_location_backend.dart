import 'dart:async';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import 'device_location.dart';
import 'location_filter.dart';
import 'location_service.dart';
import 'location_task_message.dart';

class NativeLocationBackend implements LocationBackend {
  NativeLocationBackend({
    required this.recordingCallback,
    DeviceLocation? device,
  }) : _device = device ?? DeviceLocation();

  final void Function() recordingCallback;
  final DeviceLocation _device;
  final _locations = StreamController<LocationDM>.broadcast();
  StreamSubscription<LocationDM>? _subscription;
  Completer<void>? _ready;
  Completer<void>? _stopped;
  bool _recording = false;
  bool _listening = false;

  @override
  Stream<LocationDM> get locations => _locations.stream;

  @override
  Future<LocationDM> currentLocation() => _device.currentLocation();

  @override
  Future<void> start({
    required bool background,
    LocationDM? initialLocation,
  }) async {
    await _device.ensureAvailable();
    if (!Platform.isAndroid && !Platform.isIOS) {
      throw UnsupportedError('Location tracking supports Android and iOS.');
    }
    if (Platform.isIOS || !background) {
      _subscription = LocationFilter(initialLocation: initialLocation)
          .bind(
            _device.positions(apple: Platform.isIOS, background: background),
          )
          .listen(
            _locations.add,
            onError: _locations.addError,
            onDone: () => _locations.addError(
              StateError('Location stream stopped unexpectedly.'),
            ),
          );
      return;
    }
    var permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      permission = await FlutterForegroundTask.requestNotificationPermission();
    }
    if (permission != NotificationPermission.granted) {
      throw NotificationPermissionDeniedException();
    }
    _ready = Completer<void>();
    final ready = _ready!.future.timeout(const Duration(seconds: 15));
    // Attach the error handler before native startup can report a failure.
    unawaited(ready.then<void>((_) {}, onError: (Object _, StackTrace _) {}));
    FlutterForegroundTask.addTaskDataCallback(_receive);
    _listening = true;
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'footprint_foreground_service',
        channelName: 'Route recording',
        channelDescription: 'Footprint route recording',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        stopWithTask: false,
      ),
    );
    _recording = true;
    if (await FlutterForegroundTask.isRunningService) {
      FlutterForegroundTask.sendDataToTask({'command': 'status'});
    } else {
      final result = await FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Footprint',
        notificationText: 'Route recording is active',
        callback: recordingCallback,
      );
      if (result is ServiceRequestFailure) throw result.error;
    }
    await ready;
  }

  void _receive(Object data) {
    try {
      final message = LocationTaskMessage.decode(data);
      switch (message.type) {
        case LocationTaskMessageType.location:
          _locations.add(message.location!);
        case LocationTaskMessageType.error:
          final error = message.error!;
          if (_ready case final ready? when !ready.isCompleted) {
            ready.completeError(error);
          }
          _locations.addError(error);
        case LocationTaskMessageType.ready:
          if (_ready case final ready? when !ready.isCompleted) {
            ready.complete();
          }
        case LocationTaskMessageType.stopped:
          if (_stopped case final stopped? when !stopped.isCompleted) {
            if (message.error case final error?) {
              stopped.completeError(error);
            } else {
              stopped.complete();
            }
          }
      }
    } on Object catch (error, stack) {
      _locations.addError(error, stack);
    }
  }

  @override
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    if (_recording && await FlutterForegroundTask.isRunningService) {
      _stopped = Completer<void>();
      FlutterForegroundTask.sendDataToTask({'command': 'stop'});
      // The worker acknowledges only after draining its own database writes.
      await _stopped!.future.timeout(const Duration(seconds: 15));
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestFailure) throw result.error;
    }
    _recording = false;
    if (_listening) FlutterForegroundTask.removeTaskDataCallback(_receive);
    _listening = false;
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    if (_listening) FlutterForegroundTask.removeTaskDataCallback(_receive);
    await _locations.close();
  }
}

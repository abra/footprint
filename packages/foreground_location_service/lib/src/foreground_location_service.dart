import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import 'location_service.dart';
import 'mappers/position_to_domain.dart';

final List<Exception> exceptions = [
  LocationServiceDisabledStateException(),
  LocationServicePermissionDeniedException(),
  LocationServicePermanentlyDeniedException(),
  NotificationPermissionDeniedException(),
  NotificationPermissionPermanentlyDeniedException(),
  RequestForPermissionInProgressException(),
  DefinitionsForPermissionNotFoundException(),
];

class ForegroundLocationService {
  State? _state;

  static Future<void> initCommunicationPort() async =>
      FlutterForegroundTask.initCommunicationPort();

  Future<void> _requestNotificationPermissions() async {
    PermissionStatus status = await Permission.notification.status;

    if (status.isGranted) {
      if (Platform.isAndroid) {
        final batteryOptimizationGranted =
            await Permission.ignoreBatteryOptimizations.status;
        final systemAlertWindowGranted =
            await Permission.systemAlertWindow.status;

        if (batteryOptimizationGranted == PermissionStatus.granted) {
          await Permission.ignoreBatteryOptimizations.request();
        }
        if (systemAlertWindowGranted == PermissionStatus.granted) {
          await Permission.systemAlertWindow.request();
        }
      }
    }

    if (status.isDenied) {
      status = await Permission.notification.request();
      if (status.isDenied) {
        throw NotificationPermissionDeniedException();
      }
    }

    if (status.isPermanentlyDenied) {
      final result = await openAppSettings();
      if (result) {
        status = await Permission.notification.status;
        if (status == PermissionStatus.denied) {
          throw NotificationPermissionDeniedException();
        }
        if (status == PermissionStatus.permanentlyDenied) {
          throw NotificationPermissionPermanentlyDeniedException();
        }
      }
    }
  }

  Future<void> _requestLocationPermissions() async {
    await LocationService.ensureServiceEnabled();
    await LocationService.ensurePermissionsGranted();
  }

  Future<void> _initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'footprint_foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: const ForegroundTaskOptions(
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> isRunningService() async =>
      await FlutterForegroundTask.isRunningService;

  Future<void> _startService() async {
    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: 'Foreground Service is running',
      notificationText: 'Tap to return to the app',
      notificationIcon: const NotificationIconData(
        resType: ResourceType.mipmap,
        resPrefix: ResourcePrefix.ic,
        name: 'launcher',
      ),
      // notificationButtons: [
      //   const NotificationButton(id: 'btn_hello', text: 'hello'),
      // ],
      callback: startCallback,
    );

    if (!result.success) {
      throw result.error ??
          Exception('An error occurred and the service could not be started.');
    }
  }

  void _onReceiveTaskData(Object data) {
    if (data is String && !data.startsWith('Error:')) {
      final Map<String, dynamic> locationJson = jsonDecode(data);
      final location = LocationDM.fromMap(locationJson);
      // onLocationUpdated(location);
      // locationState.value = LocationUpdateSuccess(location: location);
    }
    if (data is String && data.startsWith('Error:')) {
      final parts = data.split(':');
      final code = parts[1].trim();
      final exception = exceptions.firstWhere(
        (ex) => ex.runtimeType.toString() == code,
        orElse: () => Exception(data),
      );
      // onLocationUpdateError(exception);
      // locationState.value = LocationUpdateFailure(error: exception);
    }
  }

  @mustCallSuper
  void attach(State state) {
    _state = state;
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);

    try {
      // check permissions -> if granted -> start service
      _requestNotificationPermissions().then((_) {
        _requestLocationPermissions().then((_) async {
          // already started
          if (await FlutterForegroundTask.isRunningService) {
            return;
          }

          await _initService();
          _startService();
        });
      });
    } catch (e, s) {
      _handleError(e, s);
    }
  }

  @mustCallSuper
  void detach() {
    log('detach', name: 'ExamplePageController', time: DateTime.now());
    _state = null;
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
  }

  @mustCallSuper
  void dispose() {
    log('dispose', name: 'ExamplePageController', time: DateTime.now());
    detach();
  }

  // TODO: Refactor this method to handle errors in the foreground service
  void _handleError(Object e, StackTrace s) {
    String errorMessage;
    if (e is PlatformException) {
      errorMessage = '${e.code}: ${e.message}';
    } else {
      errorMessage = e.toString();
    }

    // print error to console.
    log('$errorMessage\n${s.toString()}');

    // show error to user.
    final State? state = _state;
    if (state != null && state.mounted) {
      final SnackBar snackBar = SnackBar(content: Text(errorMessage));
      ScaffoldMessenger.of(state.context).showSnackBar(snackBar);
    }
  }
}

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() async {
  // The setTaskHandler function must be called to handle
  // the task in the background.
  log('@pragma[vm:entry-point] startCallback');
  // FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
  FlutterForegroundTask.setTaskHandler(
    ForegroundLocationTaskHandler(),
  );
}

class ForegroundLocationTaskHandler extends TaskHandler {
  StreamSubscription<Position>? _positionStreamSubscription;

  // Called when the task is started.
  @override
  void onStart(DateTime timestamp) async {
    _positionStreamSubscription = LocationService.stream.listen((position) {
      final location = jsonEncode(position.toDomainModel().toMap());
      FlutterForegroundTask.sendDataToMain(
        location,
      );
    }, onError: (error) async {
      final exception = switch (error) {
        LocationServiceDisabledStateException() =>
          LocationServiceDisabledStateException(),
        LocationServicePermissionDeniedException() =>
          LocationServicePermissionDeniedException(),
        LocationServicePermanentlyDeniedException() =>
          LocationServicePermanentlyDeniedException(),
        NotificationPermissionDeniedException() =>
          NotificationPermissionDeniedException(),
        NotificationPermissionPermanentlyDeniedException() =>
          NotificationPermissionPermanentlyDeniedException(),
        RequestForPermissionInProgressException() =>
          RequestForPermissionInProgressException(),
        DefinitionsForPermissionNotFoundException() =>
          DefinitionsForPermissionNotFoundException(),
        _ => Exception(error.toString()),
      };

      FlutterForegroundTask.sendDataToMain('Error:${exception.runtimeType}');
    });
  }

  // Called every [ForegroundTaskOptions.interval] milliseconds.
  @override
  void onRepeatEvent(DateTime timestamp) async {
    // // Send data to main isolate.
    // FlutterForegroundTask.sendDataToMain('[$runtimeType] FROM TASK: location');
  }

  // Called when the task is destroyed.
  @override
  void onDestroy(DateTime timestamp) {
    log('[$runtimeType] onDestroy');
    _positionStreamSubscription?.cancel();
    _positionStreamSubscription = null;
  }

  // Called when data is sent using [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    // print('onReceiveData: $data');
    if (data is String) {
      // location = data;
      log('[$runtimeType] LOG: [$data]');
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    log('[$runtimeType] onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  //
  // AOS: "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted
  // for this function to be called.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    log('[$runtimeType] onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  //
  // AOS: only work Android 14+
  // iOS: only work iOS 10+
  @override
  void onNotificationDismissed() {
    log('[$runtimeType] onNotificationDismissed');
  }
}

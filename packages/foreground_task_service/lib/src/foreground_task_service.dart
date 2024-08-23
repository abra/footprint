import 'dart:developer';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:permission_handler/permission_handler.dart';

// Controller
class ForegroundLocationTaskService {
  ForegroundLocationTaskService._internal();

  static final ForegroundLocationTaskService _instance =
      ForegroundLocationTaskService._internal();

  factory ForegroundLocationTaskService() => _instance;

  State? state;

  Future<void> initTaskService() async {
    // await requestPermissions();
    await initCommunicationPort();
    await initService();
  }

  Future<void> initCommunicationPort() async =>
      FlutterForegroundTask.initCommunicationPort();

  Future<bool> requestPermissions() async {
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
      return true;
    }

    if (status.isDenied) {
      status = await Permission.notification.request();
      if (status.isDenied) {
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      final result = await openAppSettings();
      if (result) {
        status = await Permission.notification.status;
        return switch (status) {
          PermissionStatus.granted => true,
          PermissionStatus.denied => false,
          PermissionStatus.permanentlyDenied => false,
          _ => false,
        };
      }
    }

    return false;
  }

  Future<void> initService() async {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'footprint_foreground_service',
        channelName: 'Foreground Service Notification',
        channelDescription:
            'This notification appears when the foreground service is running.',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: const ForegroundTaskOptions(
        interval: 5000,
        isOnceEvent: false,
        autoRunOnBoot: true,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<bool> isRunningService() async =>
      await FlutterForegroundTask.isRunningService;

  Future<ServiceRequestResult> startService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.startService(
        serviceId: 256,
        notificationTitle: 'Foreground Service is running',
        notificationText: 'Tap to return to the app',
        notificationIcon: const NotificationIconData(
          resType: ResourceType.mipmap,
          resPrefix: ResourcePrefix.ic,
          name: 'launcher',
        ),
        notificationButtons: [
          const NotificationButton(id: 'btn_hello', text: 'hello'),
        ],
        callback: startCallback,
      );
    } else {
      print('[$runtimeType] updateService');
      // return FlutterForegroundTask.restartService();
      return await FlutterForegroundTask.updateService();
    }
  }

  Future<ServiceRequestResult> stopService() async {
    return await FlutterForegroundTask.stopService();
  }

  void sendDataToMain(dynamic data) {
    FlutterForegroundTask.sendDataToMain(data);
  }

  void sendDataToTask(Object data) {
    FlutterForegroundTask.sendDataToTask(data);
  }

  void addTaskDataCallback(Function(dynamic) callback) {
    FlutterForegroundTask.addTaskDataCallback(callback);
  }

  void removeTaskDataCallback(Function(dynamic) callback) {
    FlutterForegroundTask.removeTaskDataCallback(callback);
  }
}

// The callback function should always be a top-level function.
@pragma('vm:entry-point')
void startCallback() async {
  // The setTaskHandler function must be called to handle
  // the task in the background.
  print('@pragma[vm:entry-point] startCallback');
  FlutterForegroundTask.setTaskHandler(ForegroundTaskHandler());
}

class ForegroundTaskHandler extends TaskHandler {
  String location = '';

  // Called when the task is started.
  @override
  void onStart(DateTime timestamp) {
    print('[$runtimeType] onStart');
  }

  // Called every [ForegroundTaskOptions.interval] milliseconds.
  @override
  void onRepeatEvent(DateTime timestamp) async {
    FlutterForegroundTask.updateService(
      notificationText: 'Address: $location',
    );

    // Send data to main isolate.
    FlutterForegroundTask.sendDataToMain('[$runtimeType] FROM TASK: $location');
  }

  // Called when the task is destroyed.
  @override
  void onDestroy(DateTime timestamp) {
    print('[$runtimeType] onDestroy');
  }

  // Called when data is sent using [FlutterForegroundTask.sendDataToTask].
  @override
  void onReceiveData(Object data) {
    // print('onReceiveData: $data');
    if (data is String) {
      location = data;
      log('[$runtimeType] LOG: [$data]');
    }
  }

  // Called when the notification button is pressed.
  @override
  void onNotificationButtonPressed(String id) {
    print('[$runtimeType] onNotificationButtonPressed: $id');
  }

  // Called when the notification itself is pressed.
  //
  // AOS: "android.permission.SYSTEM_ALERT_WINDOW" permission must be granted
  // for this function to be called.
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    print('[$runtimeType] onNotificationPressed');
  }

  // Called when the notification itself is dismissed.
  //
  // AOS: only work Android 14+
  // iOS: only work iOS 10+
  @override
  void onNotificationDismissed() {
    print('[$runtimeType] onNotificationDismissed');
  }
}

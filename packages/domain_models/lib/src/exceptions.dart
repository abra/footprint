class LocationServiceDisabledStateException implements Exception {
  LocationServiceDisabledStateException({
    this.message = 'The location service on the device is disabled.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class LocationServicePermissionDeniedException implements Exception {
  LocationServicePermissionDeniedException({
    this.message = 'Permission to access the device\'s location is denied.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class LocationServicePermanentlyDeniedException implements Exception {
  LocationServicePermanentlyDeniedException({
    this.message =
        'Permission to access the device\'s location is permanently denied.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class NotificationPermissionDeniedException implements Exception {
  NotificationPermissionDeniedException({
    this.message = 'Notification permission is denied.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class NotificationPermissionPermanentlyDeniedException implements Exception {
  NotificationPermissionPermanentlyDeniedException({
    this.message = 'Notification permission is permanently denied.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class RequestForPermissionInProgressException implements Exception {
  RequestForPermissionInProgressException({
    this.message =
        'A request for location permissions is already running, please '
            'wait for it to complete before doing another request.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class DefinitionsForPermissionNotFoundException implements Exception {
  DefinitionsForPermissionNotFoundException({
    this.message = 'Definitions for the permission are missing.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

class CouldNotGetPlaceAddressException implements Exception {
  const CouldNotGetPlaceAddressException({
    this.message = 'Could not get the place address.',
    this.stackTrace,
  });

  final String message;
  final StackTrace? stackTrace;

  @override
  String toString() => message;
}

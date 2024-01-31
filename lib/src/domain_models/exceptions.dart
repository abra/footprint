class ServiceDisabledException implements Exception {
  @override
  String toString() {
    return 'The location service on the device is disabled.';
  }
}

class PermissionDeniedException implements Exception {
  @override
  String toString() {
    return 'Permission to access the device\'s location is denied.';
  }
}

class PermissionsPermanentlyDeniedException implements Exception {
  @override
  String toString() {
    return 'Permissions are denied forever, handle appropriately, '
        'until the user updates the permission in the App settings.';
  }
}

class PermissionRequestInProgressException implements Exception {
  @override
  String toString() {
    return 'A request for location permissions is already running, please '
        'wait for it to complete before doing another request.';
  }
}

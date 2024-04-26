class ServiceDisabledException implements Exception {
  @override
  String toString() {
    return 'The location service on the device is disabled.';
  }
}

class ServicePermissionDeniedException implements Exception {
  @override
  String toString() {
    return 'Permission to access the device\'s location is denied.';
  }
}

class PermissionsPermanentlyDeniedException implements Exception {
  @override
  String toString() {
    return 'Permissions will be permanently denied until you update '
        'the permission in the App settings of your phone.';
  }
}

class RequestForPermissionInProgressException implements Exception {
  @override
  String toString() {
    return 'A request for location permissions is already running, please '
        'wait for it to complete before doing another request.';
  }
}

class DefinitionsForPermissionNotFoundException implements Exception {
  @override
  String toString() {
    return 'Configuration is missing (e.g. in the AndroidManifest.xml'
        ' on Android or the Info.plist on iOS)';
  }
}


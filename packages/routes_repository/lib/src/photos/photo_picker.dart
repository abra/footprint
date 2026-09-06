import 'dart:io';

import 'package:domain_models/domain_models.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

class PhotoSelectionException implements Exception {
  const PhotoSelectionException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class PhotoPicker {
  Future<String?> pick(PhotoSource source);
  Future<String?> recover();
}

class NativePhotoPicker implements PhotoPicker {
  NativePhotoPicker({ImagePicker? picker}) : _picker = picker ?? ImagePicker();
  final ImagePicker _picker;

  @override
  Future<String?> pick(PhotoSource source) async {
    try {
      return (await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: 2048,
        maxHeight: 2048,
        imageQuality: 85,
        requestFullMetadata: false,
      ))?.path;
    } on PlatformException catch (error) {
      throw PhotoSelectionException(switch (error.code) {
        'camera_access_denied' || 'camera_access_restricted' => 'Camera access is unavailable. Check app permissions in Settings or choose a photo.',
        'photo_access_denied' || 'photo_access_restricted' =>
          'Photo access is unavailable. Check app permissions in Settings.',
        'no_available_camera' =>
          'No camera is available. Choose a photo from your library.',
        _ => 'The photo could not be selected. Please try again.',
      });
    }
  }

  @override
  Future<String?> recover() async {
    if (!Platform.isAndroid) return null;
    final response = await _picker.retrieveLostData();
    if (response.exception case final error?) throw error;
    return response.files?.firstOrNull?.path;
  }
}

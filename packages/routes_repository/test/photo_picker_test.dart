import 'package:domain_models/domain_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:routes_repository/routes_repository.dart';

class TestImagePicker extends Fake implements ImagePicker {
  PlatformException? error;
  ImageSource? selectedSource;
  bool? metadata;
  double? width;
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    selectedSource = source;
    metadata = requestFullMetadata;
    width = maxWidth;
    if (error case final error?) throw error;
    return null;
  }
}

void main() {
  test('native picker bounds image size and avoids requesting full library metadata', () async {
    final plugin = TestImagePicker();
    final picker = NativePhotoPicker(picker: plugin);
    expect(await picker.pick(PhotoSource.gallery), isNull);
    expect(plugin.selectedSource, ImageSource.gallery);
    expect(plugin.metadata, isFalse);
    expect(plugin.width, 2048);
    await picker.pick(PhotoSource.camera);
    expect(plugin.selectedSource, ImageSource.camera);
  });
  for (final (code, expected) in [
    ('camera_access_denied', 'Camera access'),
    ('photo_access_restricted', 'Photo access'),
    ('no_available_camera', 'No camera'),
    ('invalid_image', 'could not be selected'),
  ]) {
    test('native $code is translated to actionable feedback', () async {
      final plugin = TestImagePicker()..error = PlatformException(code: code);
      await expectLater(
        NativePhotoPicker(picker: plugin).pick(PhotoSource.camera),
        throwsA(
          isA<PhotoSelectionException>().having(
            (error) => error.message,
            'message',
            contains(expected),
          ),
        ),
      );
    });
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class PhotoFiles {
  Future<String> resolve(String name);
  Future<void> import(String sourcePath, String name);
  Future<bool> exists(String name);
  Future<void> prune(Set<String> referenced);
}

class LocalPhotoFiles implements PhotoFiles {
  LocalPhotoFiles({Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;
  final Future<Directory> Function() _directory;
  Future<Directory>? _root;

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getApplicationSupportDirectory()).path, 'route_photos'),
  );

  Future<Directory> _getRoot() => _root ??= _directory();

  @override
  Future<String> resolve(String name) async {
    if (!RegExp(r'^[a-zA-Z0-9-]+\.image$').hasMatch(name)) {
      throw ArgumentError.value(name, 'name', 'Invalid photo file name');
    }
    return p.join((await _getRoot()).path, name);
  }

  @override
  Future<bool> exists(String name) async => File(await resolve(name)).exists();

  @override
  Future<void> import(String sourcePath, String name) async {
    final source = File(sourcePath);
    final size = await source.length();
    if (size == 0 || size > 30 * 1024 * 1024) {
      throw const FormatException('Photo must be between 1 byte and 30 MB.');
    }
    final target = await resolve(name);
    await (await _getRoot()).create(recursive: true);
    final temporary = await source.copy('$target.tmp');
    await temporary.rename(target);
  }

  @override
  Future<void> prune(Set<String> referenced) async {
    final root = await _getRoot();
    if (!await root.exists()) return;
    await for (final entry in root.list(followLinks: false)) {
      final name = p.basename(entry.path);
      if (entry is File &&
          RegExp(r'^[a-zA-Z0-9-]+\.image(?:\.tmp)?$').hasMatch(name) &&
          !referenced.contains(name.replaceFirst(RegExp(r'\.tmp$'), ''))) {
        await entry.delete();
      }
    }
  }
}

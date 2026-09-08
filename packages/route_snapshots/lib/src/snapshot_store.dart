import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

abstract interface class SnapshotStore {
  Future<Uint8List?> read(String key);
  Future<void> write(String key, Uint8List bytes);
  Future<void> remove(String key);
  Future<void> removeRoute(int routeId);
}

class FileSnapshotStore implements SnapshotStore {
  FileSnapshotStore({
    Future<Directory> Function()? directory,
    this.maxBytes = 50 * 1024 * 1024,
  }) : _directory = directory ?? _defaultDirectory;

  final Future<Directory> Function() _directory;
  final int maxBytes;
  Future<Directory>? _root;

  static Future<Directory> _defaultDirectory() async => Directory(
    p.join((await getTemporaryDirectory()).path, 'route_snapshots'),
  );

  Future<Directory> _getRoot() async {
    try {
      return await (_root ??= _directory());
    } on Object {
      _root = null;
      rethrow;
    }
  }

  Future<File> _file(String key) async {
    if (!RegExp(r'^\d+-[a-f0-9]{64}$').hasMatch(key)) {
      throw ArgumentError.value(key, 'key', 'Invalid snapshot key');
    }
    return File(p.join((await _getRoot()).path, '$key.png'));
  }

  @override
  Future<Uint8List?> read(String key) async {
    final file = await _file(key);
    if (!await file.exists()) return null;
    if (await file.length() > maxBytes) {
      await file.delete();
      return null;
    }
    final bytes = await file.readAsBytes();
    await file.setLastModified(DateTime.now());
    return bytes;
  }

  @override
  Future<void> write(String key, Uint8List bytes) async {
    if (bytes.length > maxBytes) return;
    final file = await _file(key);
    await file.parent.create(recursive: true);
    final temporary = File('${file.path}.tmp');
    try {
      await temporary.writeAsBytes(bytes, flush: true);
      await temporary.rename(file.path);
      await _prune(key);
    } finally {
      if (await temporary.exists()) await temporary.delete();
    }
  }

  Future<List<File>> _files() async {
    final root = await _getRoot();
    if (!await root.exists()) return [];
    return [
      await for (final entry in root.list(followLinks: false))
        if (entry is File &&
            RegExp(r'^\d+-[a-f0-9]{64}\.png(?:\.tmp)?$')
                .hasMatch(p.basename(entry.path)))
          entry,
    ];
  }

  Future<void> _prune(String key) async {
    final prefix = '${key.split('-').first}-';
    final files = <({File file, FileStat stat})>[];
    var total = 0;
    for (final file in await _files()) {
      final name = p.basename(file.path);
      if (name.endsWith('.tmp') ||
          (name.startsWith(prefix) && name != '$key.png')) {
        await file.delete();
      } else {
        final stat = await file.stat();
        total += stat.size;
        files.add((file: file, stat: stat));
      }
    }
    files.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in files) {
      if (total <= maxBytes) break;
      await entry.file.delete();
      total -= entry.stat.size;
    }
  }

  @override
  Future<void> remove(String key) async {
    final file = await _file(key);
    if (await file.exists()) await file.delete();
  }

  @override
  Future<void> removeRoute(int routeId) async {
    for (final file in await _files()) {
      if (p.basename(file.path).startsWith('$routeId-')) await file.delete();
    }
  }
}

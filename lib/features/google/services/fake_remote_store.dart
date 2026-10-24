import 'dart:async';
import 'dart:typed_data';
import '../models/remote_file.dart';
import 'remote_store.dart';

class FakeRemoteStore implements RemoteStore {
  final Map<String, ({RemoteFile meta, Uint8List data})> _files = {};
  int _idCounter = 0;
  bool throwOnUpload = false;
  int? failOnNthUpload;
  int uploadCallCount = 0;

  @override
  Future<Map<String, RemoteFile>> list() async {
    final result = <String, RemoteFile>{};
    for (final entry in _files.values) {
      final name = entry.meta.name;
      if (!result.containsKey(name) || entry.meta.modified.isAfter(result[name]!.modified)) {
        result[name] = entry.meta;
      }
    }
    return result;
  }

  @override
  Future<void> upload(
    String name,
    Stream<List<int>> bytes,
    int length, {
    String? existingId,
    Map<String, String>? properties,
  }) async {
    uploadCallCount++;
    if (throwOnUpload || (failOnNthUpload != null && uploadCallCount == failOnNthUpload)) {
      throw Exception('Simulated remote store failure during upload of $name');
    }

    final builder = BytesBuilder();
    await for (final chunk in bytes) {
      builder.add(chunk);
    }
    final data = builder.takeBytes();

    final id = existingId ?? 'fake_remote_${++_idCounter}';
    final meta = RemoteFile(
      id: id,
      name: name,
      size: data.length,
      modified: DateTime.now(),
      properties: properties ?? const {},
    );

    _files[id] = (meta: meta, data: data);
  }

  @override
  Future<Stream<List<int>>> download(String id) async {
    final file = _files[id];
    if (file == null) {
      throw Exception('File not found in fake remote store: $id');
    }
    return Stream.value(file.data);
  }

  @override
  Future<void> delete(String id) async {
    _files.remove(id);
  }

  void clear() {
    _files.clear();
    uploadCallCount = 0;
    failOnNthUpload = null;
    throwOnUpload = false;
  }

  bool containsName(String name) {
    return _files.values.any((f) => f.meta.name == name);
  }

  RemoteFile? getByName(String name) {
    for (final f in _files.values) {
      if (f.meta.name == name) return f.meta;
    }
    return null;
  }
}

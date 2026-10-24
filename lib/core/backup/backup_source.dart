import 'dart:async';

class BackupItem {
  const BackupItem({
    required this.id,        // stable, opaque, e.g. "vault/data/<uuid>.bin"
    required this.size,      // bytes that will be uploaded
    required this.sha256,    // hex SHA-256 of the bytes that will be uploaded
    required this.modified,
    required this.openRead,  // opens a fresh byte stream each call
  });

  final String id;
  final int size;
  final String sha256;
  final DateTime modified;
  final Stream<List<int>> Function() openRead;
}

abstract class BackupSource {
  Future<List<BackupItem>> listItems();
  /// Writes restored bytes to the item's place atomically (temp file, then rename).
  Future<void> restoreItem(String id, Stream<List<int>> bytes);
}

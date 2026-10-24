import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/backup/backup_source.dart';
import '../../../core/crypto/sha256.dart';

class _HashCacheEntry {
  final int size;
  final int modifiedMs;
  final String sha256;

  _HashCacheEntry(this.size, this.modifiedMs, this.sha256);
}

class VaultBackupSource implements BackupSource {
  VaultBackupSource(this.vaultDir);

  final Directory vaultDir;
  final Map<String, _HashCacheEntry> _hashCache = {};

  static final RegExp _validDataBlobPattern = RegExp(r'^[a-zA-Z0-9_\-]+\.bin$');

  @override
  Future<List<BackupItem>> listItems() async {
    if (!await vaultDir.exists()) {
      return [];
    }

    final items = <BackupItem>[];

    // 1. vault.header
    final headerFile = File(p.join(vaultDir.path, 'vault.header'));
    if (await headerFile.exists()) {
      items.add(await _buildItem('vault/vault.header', headerFile));
    }

    // 2. index.enc
    final indexFile = File(p.join(vaultDir.path, 'index.enc'));
    if (await indexFile.exists()) {
      items.add(await _buildItem('vault/index.enc', indexFile));
    }

    // 3. data/*.bin
    final dataDir = Directory(p.join(vaultDir.path, 'data'));
    if (await dataDir.exists()) {
      final entities = dataDir.listSync(followLinks: false);
      for (final entity in entities) {
        if (entity is File && entity.path.endsWith('.bin')) {
          final fileName = p.basename(entity.path);
          if (_validDataBlobPattern.hasMatch(fileName)) {
            items.add(await _buildItem('vault/data/$fileName', entity));
          }
        }
      }
    }

    return items;
  }

  Future<BackupItem> _buildItem(String id, File file) async {
    final stat = await file.stat();
    final size = stat.size;
    final mtime = stat.modified;
    final cacheKey = file.path;

    String hash;
    final cached = _hashCache[cacheKey];
    if (cached != null && cached.size == size && cached.modifiedMs == mtime.millisecondsSinceEpoch) {
      hash = cached.sha256;
    } else {
      final digest = await Sha256.digestStream(file.openRead());
      hash = Sha256.hex(digest);
      _hashCache[cacheKey] = _HashCacheEntry(size, mtime.millisecondsSinceEpoch, hash);
    }

    return BackupItem(
      id: id,
      size: size,
      sha256: hash,
      modified: mtime,
      openRead: () => file.openRead(),
    );
  }

  @override
  Future<void> restoreItem(String id, Stream<List<int>> bytes) async {
    _validateId(id);

    File targetFile;
    if (id == 'vault/vault.header') {
      targetFile = File(p.join(vaultDir.path, 'vault.header'));
    } else if (id == 'vault/index.enc') {
      targetFile = File(p.join(vaultDir.path, 'index.enc'));
    } else if (id.startsWith('vault/data/')) {
      final blobName = p.basename(id);
      targetFile = File(p.join(vaultDir.path, 'data', blobName));
    } else {
      throw ArgumentError('Unsupported item id: $id');
    }

    await targetFile.parent.create(recursive: true);

    final tmpDir = Directory(p.join(vaultDir.path, 'vault_tmp'));
    await tmpDir.create(recursive: true);

    final tmpFile = File(p.join(
      tmpDir.path,
      '${p.basename(targetFile.path)}_${DateTime.now().microsecondsSinceEpoch}.tmp',
    ));

    final raf = await tmpFile.open(mode: FileMode.write);
    try {
      await for (final chunk in bytes) {
        await raf.writeFrom(chunk);
      }
      await raf.flush();
      await raf.close();

      await tmpFile.rename(targetFile.path);
    } catch (e) {
      try {
        await raf.close();
      } catch (_) {}
      if (await tmpFile.exists()) {
        try {
          await tmpFile.delete();
        } catch (_) {}
      }
      rethrow;
    }
  }

  void _validateId(String id) {
    if (id.contains('..') || id.contains('\\') || id.startsWith('/')) {
      throw ArgumentError('Invalid backup id (path traversal detected): $id');
    }

    if (id == 'vault/vault.header' || id == 'vault/index.enc') {
      return;
    }

    if (id.startsWith('vault/data/')) {
      final filename = id.substring('vault/data/'.length);
      if (_validDataBlobPattern.hasMatch(filename)) {
        return;
      }
    }

    throw ArgumentError('Disallowed backup id: $id');
  }
}

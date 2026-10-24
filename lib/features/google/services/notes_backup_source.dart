import 'dart:async';
import 'dart:io';
import 'package:path/path.dart' as p;
import '../../../core/backup/backup_source.dart';
import '../../../core/crypto/sha256.dart';
import '../../files/sandbox.dart';

class _NotesHashCacheEntry {
  final int size;
  final int modifiedMs;
  final String sha256;
  _NotesHashCacheEntry(this.size, this.modifiedMs, this.sha256);
}

class NotesBackupSource implements BackupSource {
  NotesBackupSource(this.sandbox);

  final Sandbox sandbox;
  final Map<String, _NotesHashCacheEntry> _hashCache = {};

  @override
  Future<List<BackupItem>> listItems() async {
    final rootDir = Directory(sandbox.root);
    if (!await rootDir.exists()) return [];

    final items = <BackupItem>[];
    final entities = rootDir.listSync(recursive: true, followLinks: false);

    for (final entity in entities) {
      if (entity is! File) continue;

      final rel = sandbox.relativeOf(entity.path);
      final normRel = p.normalize(rel);

      // Exclude vault, trash, and hidden files/directories
      if (sandbox.isHidden(normRel) ||
          normRel.startsWith('.trash') ||
          normRel.startsWith('vault')) {
        continue;
      }

      final stat = entity.statSync();
      final size = stat.size;
      final mtime = stat.modified;
      final cacheKey = entity.path;

      String hash;
      final cached = _hashCache[cacheKey];
      if (cached != null && cached.size == size && cached.modifiedMs == mtime.millisecondsSinceEpoch) {
        hash = cached.sha256;
      } else {
        final digest = await Sha256.digestStream(entity.openRead());
        hash = Sha256.hex(digest);
        _hashCache[cacheKey] = _NotesHashCacheEntry(size, mtime.millisecondsSinceEpoch, hash);
      }

      items.add(BackupItem(
        id: normRel,
        size: size,
        sha256: hash,
        modified: mtime,
        openRead: () => entity.openRead(),
      ));
    }

    return items;
  }

  @override
  Future<void> restoreItem(String id, Stream<List<int>> bytes) async {
    final normRel = p.normalize(id);

    // Security check: reject path traversal and forbidden directories
    if (normRel.startsWith('..') ||
        normRel.startsWith('/') ||
        normRel.startsWith('\\') ||
        normRel.startsWith('vault') ||
        normRel.startsWith('.trash') ||
        sandbox.isHidden(normRel)) {
      throw ArgumentError('Forbidden or unsafe backup item ID: $id');
    }

    // Resolve target path safely using sandbox
    final targetAbs = sandbox.resolve(normRel);
    final targetFile = File(targetAbs);

    await targetFile.parent.create(recursive: true);

    final tmpFile = File('${targetFile.path}_${DateTime.now().microsecondsSinceEpoch}.tmp');
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
}

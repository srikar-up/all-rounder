import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'file_entry.dart';
import 'names.dart';
import 'sandbox.dart';

class FileOpException implements Exception {
  final String message;
  const FileOpException(this.message);
  @override
  String toString() => message;
}

sealed class FsEvent {
  const FsEvent();
}

class FsCreated extends FsEvent {
  final String rel;
  const FsCreated(this.rel);
}

class FsMoved extends FsEvent {
  final String from;
  final String to;
  const FsMoved(this.from, this.to);
}

class FsDeleted extends FsEvent {
  final String rel;
  const FsDeleted(this.rel);
}

class StorageUsage {
  final int totalBytes;
  final int notesBytes;
  final int htmlBytes;
  final int imagesBytes;
  final int otherBytes;
  final int vaultBytes;

  const StorageUsage({
    this.totalBytes = 0,
    this.notesBytes = 0,
    this.htmlBytes = 0,
    this.imagesBytes = 0,
    this.otherBytes = 0,
    this.vaultBytes = 0,
  });
}

class FileService {
  FileService(String rootPath) : sandbox = Sandbox(rootPath);

  final Sandbox sandbox;
  final StreamController<FsEvent> _eventController = StreamController<FsEvent>.broadcast();

  Stream<FsEvent> get events => _eventController.stream;

  /// Ensures root system folders exist on first start
  Future<void> initRoot() async {
    final notesDir = Directory(sandbox.resolve('notes'));
    if (!await notesDir.exists()) {
      await notesDir.create(recursive: true);
    }
    final attachmentsDir = Directory(sandbox.resolve('attachments'));
    if (!await attachmentsDir.exists()) {
      await attachmentsDir.create(recursive: true);
    }
  }

  /// Lists entries in a directory relative to sandbox root
  Future<List<FileEntry>> list(String dirRel, {bool showHidden = false}) async {
    final targetAbs = sandbox.resolve(dirRel);
    final targetDir = Directory(targetAbs);
    if (!await targetDir.exists()) {
      throw FileOpException('Folder "$dirRel" does not exist.');
    }

    if (kIsWeb) {
      return _listInternal(targetAbs, sandbox.root, showHidden);
    }

    return Isolate.run(() => _listInternal(targetAbs, sandbox.root, showHidden));
  }

  static List<FileEntry> _listInternal(String targetAbs, String root, bool showHidden) {
    final dir = Directory(targetAbs);
    final entities = dir.listSync(followLinks: false);
    final entries = <FileEntry>[];

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (!showHidden) {
        if (name.startsWith('.') || name.toLowerCase() == 'vault') {
          continue;
        }
      }

      final isDir = entity is Directory;
      final rel = p.normalize(p.relative(entity.path, from: root));
      int size = 0;
      DateTime modified = DateTime.now();

      try {
        final stat = entity.statSync();
        modified = stat.modified;
        size = isDir ? 0 : stat.size;
      } catch (_) {}

      final kind = isDir ? FileKind.folder : FileEntry.kindFromExtension(p.extension(name));
      entries.add(FileEntry(
        relativePath: rel,
        name: name,
        isDir: isDir,
        size: size,
        modified: modified,
        kind: kind,
      ));
    }

    // Folders first, then case-insensitive alphabetical
    entries.sort((a, b) {
      if (a.isDir != b.isDir) {
        return a.isDir ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });

    return entries;
  }

  /// Creates a folder with name validation and unique naming
  Future<FileEntry> createFolder(String dirRel, String name) async {
    final err = validateName(name);
    if (err != null) throw FileOpException(err);

    final parentAbs = sandbox.resolve(dirRel);
    final targetAbs = await uniquePath(parentAbs, name.trim(), isDir: true);
    final newDir = Directory(targetAbs);
    await newDir.create(recursive: true);

    final rel = sandbox.relativeOf(targetAbs);
    _eventController.add(FsCreated(rel));

    return FileEntry(
      relativePath: rel,
      name: p.basename(targetAbs),
      isDir: true,
      size: 0,
      modified: DateTime.now(),
      kind: FileKind.folder,
    );
  }

  /// Creates a note or HTML note
  Future<FileEntry> createNote(String dirRel, String name, FileKind kind) async {
    final err = validateName(name);
    if (err != null) throw FileOpException(err);

    var cleanName = name.trim();
    if (kind == FileKind.html && !cleanName.toLowerCase().endsWith('.html') && !cleanName.toLowerCase().endsWith('.htm')) {
      cleanName = '$cleanName.html';
    } else if (kind == FileKind.note && !cleanName.toLowerCase().endsWith('.md') && !cleanName.toLowerCase().endsWith('.txt')) {
      cleanName = '$cleanName.md';
    }

    final parentAbs = sandbox.resolve(dirRel);
    final targetAbs = await uniquePath(parentAbs, cleanName, isDir: false);
    final file = File(targetAbs);

    if (kind == FileKind.html) {
      await file.writeAsString('''<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>${p.basenameWithoutExtension(targetAbs)}</title>
  <style>
    body { font-family: sans-serif; line-height: 1.6; padding: 20px; }
  </style>
</head>
<body>
  <h1>${p.basenameWithoutExtension(targetAbs)}</h1>
  <p>Start writing your magazine note here...</p>
</body>
</html>''');
    } else {
      await file.writeAsString('# ${p.basenameWithoutExtension(targetAbs)}\n\n');
    }

    final rel = sandbox.relativeOf(targetAbs);
    _eventController.add(FsCreated(rel));

    return FileEntry(
      relativePath: rel,
      name: p.basename(targetAbs),
      isDir: false,
      size: await file.length(),
      modified: DateTime.now(),
      kind: kind,
    );
  }

  /// Renames an item while enforcing protected folders and non-overwrite guards
  Future<String> rename(String rel, String newName) async {
    if (sandbox.isProtected(rel)) {
      throw const FileOpException('Cannot rename system folder.');
    }

    final err = validateName(newName);
    if (err != null) throw FileOpException(err);

    final sourceAbs = sandbox.resolve(rel);
    final sourceEntity = (await FileSystemEntity.type(sourceAbs, followLinks: false) == FileSystemEntityType.directory)
        ? Directory(sourceAbs)
        : File(sourceAbs);

    if (!await sourceEntity.exists()) {
      throw FileOpException('Item "$rel" does not exist.');
    }

    var targetName = newName.trim();
    final isDir = sourceEntity is Directory;
    if (!isDir) {
      final oldExt = p.extension(sourceAbs);
      if (oldExt.isNotEmpty && !targetName.toLowerCase().endsWith(oldExt.toLowerCase()) && !targetName.contains('.')) {
        targetName = '$targetName$oldExt';
      }
    }

    final targetAbs = p.join(p.dirname(sourceAbs), targetName);
    if (targetAbs != sourceAbs && await FileSystemEntity.type(targetAbs, followLinks: false) != FileSystemEntityType.notFound) {
      throw FileOpException('An item named "$targetName" already exists.');
    }

    await sourceEntity.rename(targetAbs);
    final newRel = sandbox.relativeOf(targetAbs);
    _eventController.add(FsMoved(rel, newRel));
    return newRel;
  }

  /// Moves items to destination directory with collision avoidance
  Future<List<String>> move(List<String> relList, String destDirRel) async {
    final destAbs = sandbox.resolve(destDirRel);
    final destDir = Directory(destAbs);
    if (!await destDir.exists()) {
      throw FileOpException('Destination "$destDirRel" does not exist.');
    }

    final movedList = <String>[];
    for (final rel in relList) {
      if (sandbox.isProtected(rel)) {
        throw const FileOpException('Cannot move system folder.');
      }

      final sourceAbs = sandbox.resolve(rel);
      final isDir = await FileSystemEntity.type(sourceAbs, followLinks: false) == FileSystemEntityType.directory;

      if (isDir) {
        if (destAbs == sourceAbs || p.isWithin(sourceAbs, destAbs)) {
          throw const FileOpException('Cannot move a folder into itself or its subfolder.');
        }
      }

      final baseName = p.basename(sourceAbs);
      final targetAbs = await uniquePath(destAbs, baseName, isDir: isDir);

      if (isDir) {
        final d = Directory(sourceAbs);
        try {
          await d.rename(targetAbs);
        } catch (_) {
          await _copyDirRecursive(d, Directory(targetAbs));
          await d.delete(recursive: true);
        }
      } else {
        final f = File(sourceAbs);
        try {
          await f.rename(targetAbs);
        } catch (_) {
          await f.copy(targetAbs);
          await f.delete();
        }
      }

      final targetRel = sandbox.relativeOf(targetAbs);
      movedList.add(targetRel);
      _eventController.add(FsMoved(rel, targetRel));
    }

    return movedList;
  }

  /// Copies items recursively with uniquePath
  Future<List<String>> copy(List<String> relList, String destDirRel) async {
    final destAbs = sandbox.resolve(destDirRel);
    final destDir = Directory(destAbs);
    if (!await destDir.exists()) {
      throw FileOpException('Destination "$destDirRel" does not exist.');
    }

    final copiedList = <String>[];
    for (final rel in relList) {
      final sourceAbs = sandbox.resolve(rel);
      final isDir = await FileSystemEntity.type(sourceAbs, followLinks: false) == FileSystemEntityType.directory;
      final baseName = p.basename(sourceAbs);
      final targetAbs = await uniquePath(destAbs, baseName, isDir: isDir);

      if (isDir) {
        await _copyDirRecursive(Directory(sourceAbs), Directory(targetAbs));
      } else {
        await File(sourceAbs).copy(targetAbs);
      }

      final targetRel = sandbox.relativeOf(targetAbs);
      copiedList.add(targetRel);
      _eventController.add(FsCreated(targetRel));
    }

    return copiedList;
  }

  static Future<void> _copyDirRecursive(Directory source, Directory target) async {
    if (!await target.exists()) {
      await target.create(recursive: true);
    }
    await for (final entity in source.list(followLinks: false)) {
      final name = p.basename(entity.path);
      final newPath = p.join(target.path, name);
      if (entity is Directory) {
        await _copyDirRecursive(entity, Directory(newPath));
      } else if (entity is File) {
        await entity.copy(newPath);
      }
    }
  }

  /// Moves items to .trash with metadata and returns groupId for Undo
  Future<String> delete(List<String> relList) async {
    final groupId = '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(99999)}';
    final trashGroupAbs = p.join(sandbox.root, '.trash', groupId);
    final itemsDirAbs = p.join(trashGroupAbs, 'items');
    await Directory(itemsDirAbs).create(recursive: true);

    final itemsMeta = <Map<String, String>>[];
    final itemsToMove = <Map<String, String>>[];

    for (final rel in relList) {
      if (sandbox.isProtected(rel)) {
        throw const FileOpException('Cannot delete system folder.');
      }
      final sourceAbs = sandbox.resolve(rel);
      final storedName = p.basename(sourceAbs);
      itemsMeta.add({
        'originalRel': rel,
        'storedName': storedName,
      });
      itemsToMove.add({
        'sourceAbs': sourceAbs,
        'destAbs': p.join(itemsDirAbs, storedName),
        'rel': rel,
      });

      // If item is a note, also look for its attachments folder attachments/<note-name-without-ext>
      final baseWithoutExt = p.basenameWithoutExtension(sourceAbs);
      final attachmentRel = p.join('attachments', baseWithoutExt);
      final attachmentAbs = sandbox.resolve(attachmentRel);
      if (await Directory(attachmentAbs).exists()) {
        final attStored = 'att_$baseWithoutExt';
        itemsMeta.add({
          'originalRel': attachmentRel,
          'storedName': attStored,
        });
        itemsToMove.add({
          'sourceAbs': attachmentAbs,
          'destAbs': p.join(itemsDirAbs, attStored),
          'rel': attachmentRel,
        });
      }
    }

    // Write meta.json BEFORE moving files
    final metaFile = File(p.join(trashGroupAbs, 'meta.json'));
    await metaFile.writeAsString(jsonEncode({
      'deletedAt': DateTime.now().toIso8601String(),
      'items': itemsMeta,
    }));

    // Move files into trash items/
    for (final item in itemsToMove) {
      final src = item['sourceAbs']!;
      final dest = item['destAbs']!;
      final isDir = await FileSystemEntity.type(src, followLinks: false) == FileSystemEntityType.directory;
      if (isDir) {
        await Directory(src).rename(dest);
      } else {
        await File(src).rename(dest);
      }
      _eventController.add(FsDeleted(item['rel']!));
    }

    return groupId;
  }

  /// Restores items from trash group back to original relative paths
  Future<void> restore(String groupId) async {
    final trashGroupAbs = p.join(sandbox.root, '.trash', groupId);
    final groupDir = Directory(trashGroupAbs);
    if (!await groupDir.exists()) {
      throw FileOpException('Trash group "$groupId" not found.');
    }

    final metaFile = File(p.join(trashGroupAbs, 'meta.json'));
    if (!await metaFile.exists()) {
      throw const FileOpException('Trash metadata file missing.');
    }

    final meta = jsonDecode(await metaFile.readAsString()) as Map<String, dynamic>;
    final items = (meta['items'] as List).cast<Map<String, dynamic>>();

    for (final item in items) {
      final originalRel = item['originalRel'] as String;
      final storedName = item['storedName'] as String;
      final storedAbs = p.join(trashGroupAbs, 'items', storedName);

      final originalAbs = sandbox.resolve(originalRel);
      final parentDirAbs = p.dirname(originalAbs);
      await Directory(parentDirAbs).create(recursive: true);

      final isDir = await FileSystemEntity.type(storedAbs, followLinks: false) == FileSystemEntityType.directory;
      final restoreTargetAbs = await uniquePath(parentDirAbs, p.basename(originalAbs), isDir: isDir);

      if (isDir) {
        await Directory(storedAbs).rename(restoreTargetAbs);
      } else {
        await File(storedAbs).rename(restoreTargetAbs);
      }

      _eventController.add(FsCreated(sandbox.relativeOf(restoreTargetAbs)));
    }

    // Delete trash group directory
    await groupDir.delete(recursive: true);
  }

  /// Permanently deletes a single trash group
  Future<void> deleteForever(String groupId) async {
    final trashGroupAbs = p.join(sandbox.root, '.trash', groupId);
    final groupDir = Directory(trashGroupAbs);
    if (await groupDir.exists()) {
      await groupDir.delete(recursive: true);
    }
  }

  /// Empties all items inside .trash
  Future<void> emptyTrash() async {
    final trashDir = Directory(p.join(sandbox.root, '.trash'));
    if (await trashDir.exists()) {
      await for (final entity in trashDir.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    }
  }

  /// Purges trash items older than [days]
  Future<void> purgeOld({int days = 30}) async {
    final trashDir = Directory(p.join(sandbox.root, '.trash'));
    if (!await trashDir.exists()) return;

    final cutoff = DateTime.now().subtract(Duration(days: days));
    await for (final entity in trashDir.list(followLinks: false)) {
      if (entity is Directory) {
        final metaFile = File(p.join(entity.path, 'meta.json'));
        if (await metaFile.exists()) {
          try {
            final meta = jsonDecode(await metaFile.readAsString());
            final deletedAt = DateTime.parse(meta['deletedAt'] as String);
            if (deletedAt.isBefore(cutoff)) {
              await entity.delete(recursive: true);
            }
          } catch (_) {}
        }
      }
    }
  }

  /// Searches for files by name matching query
  Future<List<FileEntry>> search(String query, {String? dirRel, bool recursive = true}) async {
    final startAbs = sandbox.resolve(dirRel ?? '');
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isEmpty) return [];

    if (kIsWeb) {
      return _searchInternal(startAbs, sandbox.root, cleanQuery, recursive);
    }

    return Isolate.run(() => _searchInternal(startAbs, sandbox.root, cleanQuery, recursive));
  }

  static List<FileEntry> _searchInternal(String startAbs, String root, String query, bool recursive) {
    final dir = Directory(startAbs);
    if (!dir.existsSync()) return [];

    final results = <FileEntry>[];
    final entities = dir.listSync(recursive: recursive, followLinks: false);

    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (name.startsWith('.') || name.toLowerCase() == 'vault') continue;

      if (name.toLowerCase().contains(query)) {
        final isDir = entity is Directory;
        final rel = p.normalize(p.relative(entity.path, from: root));
        int size = 0;
        DateTime mod = DateTime.now();
        try {
          final stat = entity.statSync();
          mod = stat.modified;
          size = isDir ? 0 : stat.size;
        } catch (_) {}

        results.add(FileEntry(
          relativePath: rel,
          name: name,
          isDir: isDir,
          size: size,
          modified: mod,
          kind: isDir ? FileKind.folder : FileEntry.kindFromExtension(p.extension(name)),
        ));
      }
    }

    return results;
  }

  /// Computes recursive storage usage by category
  Future<StorageUsage> usage() async {
    if (kIsWeb) {
      return _usageInternal(sandbox.root);
    }
    return Isolate.run(() => _usageInternal(sandbox.root));
  }

  static StorageUsage _usageInternal(String root) {
    final dir = Directory(root);
    if (!dir.existsSync()) return const StorageUsage();

    int total = 0;
    int notes = 0;
    int html = 0;
    int images = 0;
    int other = 0;
    int vault = 0;

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final rel = p.relative(entity.path, from: root);
        if (rel.startsWith('.')) continue;
        if (rel.startsWith('vault')) {
          vault += entity.lengthSync();
          continue;
        }

        final size = entity.lengthSync();
        total += size;
        final kind = FileEntry.kindFromExtension(p.extension(entity.path));
        switch (kind) {
          case FileKind.note:
            notes += size;
            break;
          case FileKind.html:
            html += size;
            break;
          case FileKind.image:
            images += size;
            break;
          case FileKind.other:
          case FileKind.folder:
            other += size;
            break;
        }
      }
    }

    return StorageUsage(
      totalBytes: total,
      notesBytes: notes,
      htmlBytes: html,
      imagesBytes: images,
      otherBytes: other,
      vaultBytes: vault,
    );
  }

  /// Copies an external file into the sandbox with unique naming
  Future<FileEntry> importFile(String sourceAbsPath, String destDirRel) async {
    final srcFile = File(sourceAbsPath);
    if (!await srcFile.exists()) {
      throw FileOpException('Source file "$sourceAbsPath" does not exist.');
    }

    final destAbs = sandbox.resolve(destDirRel);
    final targetAbs = await uniquePath(destAbs, p.basename(sourceAbsPath), isDir: false);
    await srcFile.copy(targetAbs);

    final rel = sandbox.relativeOf(targetAbs);
    _eventController.add(FsCreated(rel));

    return FileEntry(
      relativePath: rel,
      name: p.basename(targetAbs),
      isDir: false,
      size: await File(targetAbs).length(),
      modified: DateTime.now(),
      kind: FileEntry.kindFromExtension(p.extension(targetAbs)),
    );
  }

  void dispose() {
    _eventController.close();
  }
}

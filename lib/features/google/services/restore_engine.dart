import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import '../../../core/backup/backup_source.dart';
import '../../../core/crypto/sha256.dart';
import '../../files/sandbox.dart';
import 'backup_cipher.dart';
import 'remote_store.dart';

class RestoreReport {
  int vaultItemsRestored = 0;
  int notesRestored = 0;
  int conflictsResolved = 0;
  int skipped = 0;
  final List<String> failed = [];

  bool get isSuccess => failed.isEmpty;
}

class RestoreEngine {
  RestoreEngine({
    required this.remote,
    required this.vaultSource,
    required this.notesSource,
    required this.sandbox,
    this.backupCipher,
  });

  final RemoteStore remote;
  final BackupSource vaultSource;
  final BackupSource notesSource;
  final Sandbox sandbox;
  final BackupCipher? backupCipher;

  Future<RestoreReport> run() async {
    final report = RestoreReport();
    final remoteFiles = await remote.list();

    // --- 1. Restore Vault Files (v-...) ---
    final vaultRemotes = remoteFiles.values.where((f) => f.name.startsWith('v-')).toList();
    for (final rf in vaultRemotes) {
      try {
        final originalId = rf.name.substring(2).replaceAll('~', '/');

        // Download stream
        final stream = await remote.download(rf.id);
        final builder = BytesBuilder();
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        final downloadedBytes = builder.takeBytes();

        // Verify SHA-256 against stored remote property
        final expectedHash = rf.properties['sha256'];
        if (expectedHash != null && expectedHash.isNotEmpty) {
          final computedHash = Sha256.hex(Sha256.digest(downloadedBytes));
          if (computedHash != expectedHash) {
            throw StateError('Corrupted download: SHA-256 mismatch for vault item ${rf.name}');
          }
        }

        // Restore using vault source
        await vaultSource.restoreItem(originalId, Stream.value(downloadedBytes));
        report.vaultItemsRestored++;
      } catch (e) {
        report.failed.add(rf.name);
      }
    }

    // --- 2. Restore Notes Files (n-...) ---
    if (remoteFiles.containsKey('n-manifest') && backupCipher != null) {
      Map<String, dynamic> manifest = {};
      try {
        final manifestRemote = remoteFiles['n-manifest']!;
        final stream = await remote.download(manifestRemote.id);
        final builder = BytesBuilder();
        await for (final chunk in stream) {
          builder.add(chunk);
        }
        final decryptedManifest = await backupCipher!.open(builder.takeBytes(), 'n-manifest');
        manifest = jsonDecode(utf8.decode(decryptedManifest)) as Map<String, dynamic>;
      } catch (e) {
        report.failed.add('n-manifest');
        return report;
      }

      for (final entry in manifest.entries) {
        final remoteName = entry.key;
        final info = entry.value as Map<String, dynamic>;
        final relPath = info['relPath'] as String;

        try {
          final remoteFile = remoteFiles[remoteName];
          if (remoteFile == null) {
            report.failed.add(remoteName);
            continue;
          }

          final stream = await remote.download(remoteFile.id);
          final builder = BytesBuilder();
          await for (final chunk in stream) {
            builder.add(chunk);
          }
          final sealedBytes = builder.takeBytes();
          final decryptedBytes = await backupCipher!.open(sealedBytes, remoteName);

          // Check if local file exists to avoid overwriting modified content
          String finalRelPath = relPath;
          try {
            final targetAbs = sandbox.resolve(relPath);
            final targetFile = File(targetAbs);
            if (await targetFile.exists()) {
              final localBytes = await targetFile.readAsBytes();
              final localHash = Sha256.hex(Sha256.digest(localBytes));
              final remoteHash = Sha256.hex(Sha256.digest(decryptedBytes));

              if (localHash == remoteHash) {
                report.skipped++;
                continue;
              } else {
                // Conflict: Never overwrite different local content
                final dir = p.dirname(relPath);
                final ext = p.extension(relPath);
                final stem = p.basenameWithoutExtension(relPath);
                final conflictName = '$stem (restored)$ext';
                finalRelPath = dir == '.' || dir.isEmpty ? conflictName : p.join(dir, conflictName);
                report.conflictsResolved++;
              }
            }
          } catch (_) {}

          await notesSource.restoreItem(finalRelPath, Stream.value(decryptedBytes));
          report.notesRestored++;
        } catch (e) {
          report.failed.add(remoteName);
        }
      }
    }

    return report;
  }
}

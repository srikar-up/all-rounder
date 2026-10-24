import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/backup/backup_source.dart';
import '../../../core/crypto/sha256.dart';
import '../models/backup_report.dart';
import '../models/remote_file.dart';
import 'backup_cipher.dart';
import 'remote_store.dart';

class BackupEngine {
  BackupEngine({
    required this.remote,
    required this.sources,
    this.backupCipher,
    this.includeNotes = true,
  });

  final RemoteStore remote;
  final List<BackupSource> sources;
  final BackupCipher? backupCipher;
  final bool includeNotes;

  bool _isCancelled = false;
  final StreamController<BackupProgress> _progressController =
      StreamController<BackupProgress>.broadcast();

  Stream<BackupProgress> get progress => _progressController.stream;

  void cancel() {
    _isCancelled = true;
  }

  static const int notesMaxSizeBytes = 25 * 1024 * 1024; // 25 MB cap

  static String remoteNameForVault(String itemId) {
    return 'v-${itemId.replaceAll('/', '~')}';
  }

  static String remoteNameForNote(String relativePath) {
    final hexDigest = Sha256.hex(Sha256.digest(utf8.encode(relativePath)));
    final hash32 = hexDigest.length >= 32 ? hexDigest.substring(0, 32) : hexDigest;
    return 'n-$hash32';
  }

  Future<BackupReport> run() async {
    _isCancelled = false;
    final report = BackupReport();

    // 1. Gather all items from all sources
    final allItems = <BackupItem>[];
    for (final src in sources) {
      final items = await src.listItems();
      for (final item in items) {
        final isVault = item.id.startsWith('vault/');
        if (!isVault && !includeNotes) {
          continue; // Skip notes if toggle is off
        }
        allItems.add(item);
      }
    }

    final totalCount = allItems.length;
    _progressController.add(BackupProgress(0, totalCount));

    // 2. Fetch existing remote store state
    Map<String, RemoteFile> remoteFiles;
    try {
      remoteFiles = await remote.list();
    } catch (_) {
      remoteFiles = {};
    }

    // Load existing remote notes manifest if present and cipher available
    Map<String, dynamic> notesManifest = {};
    if (includeNotes && backupCipher != null && remoteFiles.containsKey('n-manifest')) {
      try {
        final remoteManifestFile = remoteFiles['n-manifest']!;
        final manifestStream = await remote.download(remoteManifestFile.id);
        final builder = BytesBuilder();
        await for (final chunk in manifestStream) {
          builder.add(chunk);
        }
        final decryptedBytes = await backupCipher!.open(builder.takeBytes(), 'n-manifest');
        notesManifest = jsonDecode(utf8.decode(decryptedBytes)) as Map<String, dynamic>;
      } catch (_) {
        notesManifest = {};
      }
    }

    int processedCount = 0;
    bool notesModified = false;

    // 3. Process each item sequentially
    for (final item in allItems) {
      if (_isCancelled) {
        report.cancelled = true;
        break;
      }

      final isVault = item.id.startsWith('vault/');
      final remoteName = isVault
          ? remoteNameForVault(item.id)
          : remoteNameForNote(item.id);

      final existingRemote = remoteFiles[remoteName];

      try {
        if (isVault) {
          // Vault item: check SHA-256 match in remote appProperties
          if (existingRemote != null &&
              existingRemote.properties['sha256'] == item.sha256) {
            report.skipped++;
          } else {
            // Upload vault item directly without re-encrypting (already ciphertext)
            await remote.upload(
              remoteName,
              item.openRead(),
              item.size,
              existingId: existingRemote?.id,
              properties: {
                'sha256': item.sha256,
                'id': item.id,
              },
            );
            report.uploaded++;
          }
        } else {
          // Notes item: verify BackupCipher is configured
          if (backupCipher == null) {
            throw StateError('BackupCipher required to encrypt notes');
          }

          // Check memory size cap
          if (item.size > notesMaxSizeBytes) {
            report.tooLarge++;
            report.failed.add(remoteName);
            processedCount++;
            _progressController.add(BackupProgress(processedCount, totalCount));
            continue;
          }

          // Check skip condition against manifest
          final existingRecord = notesManifest[remoteName] as Map<String, dynamic>?;
          if (existingRecord != null &&
              existingRemote != null &&
              existingRecord['size'] == item.size &&
              existingRecord['modified'] == item.modified.toIso8601String() &&
              existingRecord['sha256'] == item.sha256) {
            report.skipped++;
          } else {
            // Read into memory and seal with BackupCipher
            final rawBytesBuilder = BytesBuilder();
            await for (final chunk in item.openRead()) {
              rawBytesBuilder.add(chunk);
            }
            final rawBytes = rawBytesBuilder.takeBytes();
            final sealedBytes = await backupCipher!.seal(rawBytes, remoteName);

            await remote.upload(
              remoteName,
              Stream.value(sealedBytes),
              sealedBytes.length,
              existingId: existingRemote?.id,
              properties: {
                'kind': 'note',
              },
            );

            // Update manifest entry
            notesManifest[remoteName] = {
              'relPath': item.id,
              'size': item.size,
              'modified': item.modified.toIso8601String(),
              'sha256': item.sha256,
            };
            notesModified = true;
            report.uploaded++;
          }
        }
      } catch (e) {
        report.failed.add(remoteName);
      }

      processedCount++;
      _progressController.add(BackupProgress(processedCount, totalCount));
    }

    // 4. Upload updated n-manifest LAST
    if (includeNotes && backupCipher != null && notesModified && !_isCancelled) {
      try {
        final manifestJson = jsonEncode(notesManifest);
        final sealedManifest = await backupCipher!.seal(
          utf8.encode(manifestJson),
          'n-manifest',
        );

        final existingManifest = remoteFiles['n-manifest'];
        await remote.upload(
          'n-manifest',
          Stream.value(sealedManifest),
          sealedManifest.length,
          existingId: existingManifest?.id,
          properties: {'kind': 'manifest'},
        );
      } catch (e) {
        report.failed.add('n-manifest');
      }
    }

    // 5. Update last successful backup info if everything succeeded
    if (report.isSuccess) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(
          'all_rounder_last_backup_time',
          DateTime.now().toIso8601String(),
        );
        await prefs.setInt('all_rounder_last_backup_uploaded', report.uploaded);
      } catch (_) {}
    }

    return report;
  }

  void dispose() {
    _progressController.close();
  }
}

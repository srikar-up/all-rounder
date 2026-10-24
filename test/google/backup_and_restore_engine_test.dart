import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:all_rounder/core/crypto/kdf.dart';
import 'package:all_rounder/core/crypto/recovery_code.dart';
import 'package:all_rounder/core/crypto/sha256.dart';
import 'package:all_rounder/features/files/sandbox.dart';
import 'package:all_rounder/features/google/services/backup_cipher.dart';
import 'package:all_rounder/features/google/services/backup_engine.dart';
import 'package:all_rounder/features/google/services/backup_key_store.dart';
import 'package:all_rounder/features/google/services/fake_remote_store.dart';
import 'package:all_rounder/features/google/services/notes_backup_source.dart';
import 'package:all_rounder/features/google/services/restore_engine.dart';
import 'package:all_rounder/features/vault/models/vault_header.dart';
import 'package:all_rounder/features/vault/services/vault_backup_source.dart';
import 'package:all_rounder/features/vault/services/vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Drive Remote Store & Engines Tests (Phase 2, 3, 5, 7)', () {
    late Directory testRoot;
    late Directory notesDir;
    late Directory vaultDir;
    late Sandbox sandbox;
    late VaultRepository vaultRepo;
    late VaultBackupSource vaultSource;
    late NotesBackupSource notesSource;
    late FakeRemoteStore remoteStore;
    late BackupKeyStore keyStore;
    late BackupCipher backupCipher;

    setUp(() async {
      testRoot = await Directory.systemTemp.createTemp('all_rounder_backup_test_');
      notesDir = Directory(p.join(testRoot.path, 'notes'));
      await notesDir.create(recursive: true);

      sandbox = Sandbox(testRoot.path);

      // Initialize Vault
      vaultRepo = VaultRepository(testRoot.path, customKdfParams: KdfParams.test);
      vaultSource = VaultBackupSource(vaultRepo.vaultDir);
      notesSource = NotesBackupSource(sandbox);
      remoteStore = FakeRemoteStore();

      // Setup Backup Key
      keyStore = BackupKeyStore(InMemoryKeyStorageBackend());
      await keyStore.createKey();
      final keyBytes = await keyStore.getKeyBytes();
      backupCipher = BackupCipher(keyBytes!);
    });

    tearDown(() async {
      vaultRepo.lock();
      if (await testRoot.exists()) {
        try {
          await testRoot.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('3.1 first backup uploads all files; second backup skips everything', () async {
      // 1. Create a vault file
      await vaultRepo.create('passphrase123');
      final secretDoc = File(p.join(testRoot.path, 'secret.txt'));
      await secretDoc.writeAsString('vault confidential data');
      await vaultRepo.addFile(secretDoc);
      vaultRepo.lock();

      // 2. Create normal notes
      final note1 = File(p.join(notesDir.path, 'todo.md'));
      await note1.writeAsString('# My Todo List');

      final note2 = File(p.join(notesDir.path, 'ideas.txt'));
      await note2.writeAsString('Great ideas for project');

      final engine1 = BackupEngine(
        remote: remoteStore,
        sources: [vaultSource, notesSource],
        backupCipher: backupCipher,
      );

      final report1 = await engine1.run();
      expect(report1.isSuccess, true);
      // 2 notes + vault.header + index.enc + 1 data blob = 5 items
      expect(report1.uploaded, 5);
      expect(report1.skipped, 0);

      // Verify remote names are obfuscated: notes must not reveal plaintext path
      final remoteList = await remoteStore.list();
      expect(remoteList.containsKey('notes/todo.md'), false);
      expect(remoteList.containsKey('n-manifest'), true);

      // Verify vault items have v- prefix
      final vaultRemotes = remoteList.keys.where((k) => k.startsWith('v-')).toList();
      expect(vaultRemotes.length, 3); // header, index, 1 data blob

      // 3. Run second backup immediately - everything unchanged must be skipped
      final engine2 = BackupEngine(
        remote: remoteStore,
        sources: [vaultSource, notesSource],
        backupCipher: backupCipher,
      );

      final report2 = await engine2.run();
      expect(report2.isSuccess, true);
      expect(report2.uploaded, 0);
      expect(report2.skipped, 5);
    });

    test('3.2 modifying one note only uploads that one note and manifest', () async {
      await vaultRepo.create('passphrase123');
      vaultRepo.lock();

      final note1 = File(p.join(notesDir.path, 'note1.md'));
      await note1.writeAsString('Content 1');

      final note2 = File(p.join(notesDir.path, 'note2.md'));
      await note2.writeAsString('Content 2');

      final engine = BackupEngine(
        remote: remoteStore,
        sources: [vaultSource, notesSource],
        backupCipher: backupCipher,
      );

      final r1 = await engine.run();
      expect(r1.uploaded, 4); // 2 notes + header + index

      // Modify note2 only
      await Future.delayed(const Duration(milliseconds: 50));
      await note2.writeAsString('Content 2 Modified!');

      final r2 = await engine.run();
      expect(r2.uploaded, 1); // only note2 uploaded
      expect(r2.skipped, 3); // note1 and vault files skipped
    });

    test('3.3 interrupted backup records failure and stops cleanly', () async {
      final note1 = File(p.join(notesDir.path, 'note1.md'));
      await note1.writeAsString('Content 1');

      final note2 = File(p.join(notesDir.path, 'note2.md'));
      await note2.writeAsString('Content 2');

      // Configure fake remote store to fail on the 2nd upload
      remoteStore.failOnNthUpload = 2;

      final engine = BackupEngine(
        remote: remoteStore,
        sources: [notesSource],
        backupCipher: backupCipher,
      );

      final report = await engine.run();
      expect(report.isSuccess, false);
      expect(report.failed.isNotEmpty, true);
    });

    test('3.4 cancel flag stops backup between items', () async {
      for (var i = 0; i < 5; i++) {
        final f = File(p.join(notesDir.path, 'file_$i.txt'));
        await f.writeAsString('File content $i');
      }

      final engine = BackupEngine(
        remote: remoteStore,
        sources: [notesSource],
        backupCipher: backupCipher,
      );

      // Cancel right after first progress update
      engine.progress.listen((p) {
        if (p.done >= 1) engine.cancel();
      });

      final report = await engine.run();
      expect(report.cancelled, true);
      expect(report.uploaded, lessThan(5));
    });

    test('3.5 full restore round-trip into empty directory reproduces all files byte-for-byte', () async {
      // 1. Populate original notes and vault
      final noteFile = File(p.join(notesDir.path, 'important_note.md'));
      const noteContent = '# Crucial Information\nThis must survive round trip.';
      await noteFile.writeAsString(noteContent);

      await vaultRepo.create('my-strong-vault-passphrase');
      final secretFile = File(p.join(testRoot.path, 'vault_secret.bin'));
      final secretBytes = Uint8List.fromList(List.generate(2048, (i) => (i * 7) % 256));
      await secretFile.writeAsBytes(secretBytes);
      final meta = await vaultRepo.addFile(secretFile);
      vaultRepo.lock();

      // 2. Perform backup
      final engine = BackupEngine(
        remote: remoteStore,
        sources: [vaultSource, notesSource],
        backupCipher: backupCipher,
      );
      final backupReport = await engine.run();
      expect(backupReport.isSuccess, true);

      // 3. Create fresh restore target directory simulating a new phone
      final restoreRoot = await Directory.systemTemp.createTemp('all_rounder_restored_phone_');
      try {
        final restoreSandbox = Sandbox(restoreRoot.path);
        final restoreVaultRepo = VaultRepository(restoreRoot.path, customKdfParams: KdfParams.test);
        final restoreVaultSource = VaultBackupSource(restoreVaultRepo.vaultDir);
        final restoreNotesSource = NotesBackupSource(restoreSandbox);

        final restoreEngine = RestoreEngine(
          remote: remoteStore,
          vaultSource: restoreVaultSource,
          notesSource: restoreNotesSource,
          sandbox: restoreSandbox,
          backupCipher: backupCipher,
        );

        final restoreReport = await restoreEngine.run();
        expect(restoreReport.isSuccess, true);
        expect(restoreReport.notesRestored, 1);
        expect(restoreReport.vaultItemsRestored, 3); // header, index, 1 blob

        // Verify restored note content
        final restoredNote = File(p.join(restoreRoot.path, 'notes', 'important_note.md'));
        expect(await restoredNote.exists(), true);
        expect(await restoredNote.readAsString(), noteContent);

        // Verify restored vault unlocks and decrypts
        expect(restoreVaultRepo.exists, true);
        await restoreVaultRepo.unlockWithPassphrase('my-strong-vault-passphrase');
        expect(restoreVaultRepo.isUnlocked, true);
        final decryptedSecret = await restoreVaultRepo.readBytes(meta.id);
        expect(decryptedSecret, equals(secretBytes));
      } finally {
        if (await restoreRoot.exists()) {
          await restoreRoot.delete(recursive: true);
        }
      }
    });

    test('3.6 restore does not overwrite different local content, creates (restored) copy', () async {
      // 1. Backup original version
      final noteFile = File(p.join(notesDir.path, 'doc.txt'));
      await noteFile.writeAsString('Version 1 on Cloud');

      final engine = BackupEngine(
        remote: remoteStore,
        sources: [notesSource],
        backupCipher: backupCipher,
      );
      await engine.run();

      // 2. Local file is edited to Version 2
      await noteFile.writeAsString('Version 2 edited locally on phone');

      // 3. Run restore
      final restoreEngine = RestoreEngine(
        remote: remoteStore,
        vaultSource: vaultSource,
        notesSource: notesSource,
        sandbox: sandbox,
        backupCipher: backupCipher,
      );

      final report = await restoreEngine.run();
      expect(report.conflictsResolved, 1);

      // Original file remains intact with Version 2
      expect(await noteFile.readAsString(), 'Version 2 edited locally on phone');

      // Restored copy created alongside
      final conflictFile = File(p.join(notesDir.path, 'doc (restored).txt'));
      expect(await conflictFile.exists(), true);
      expect(await conflictFile.readAsString(), 'Version 1 on Cloud');
    });

    test('3.7 wrong backup key fails decrypting notes manifest cleanly', () async {
      final noteFile = File(p.join(notesDir.path, 'note.txt'));
      await noteFile.writeAsString('Secret note');

      final engine = BackupEngine(
        remote: remoteStore,
        sources: [notesSource],
        backupCipher: backupCipher,
      );
      await engine.run();

      // Attempt restore with a different random key
      final wrongCipher = BackupCipher(RecoveryCode.generateBytes(32));
      final restoreEngine = RestoreEngine(
        remote: remoteStore,
        vaultSource: vaultSource,
        notesSource: notesSource,
        sandbox: sandbox,
        backupCipher: wrongCipher,
      );

      final report = await restoreEngine.run();
      expect(report.failed.contains('n-manifest'), true);
      expect(report.notesRestored, 0);
    });

    test('3.8 notes source rejects path traversal and forbidden folders', () async {
      final dummyStream = Stream.value(utf8.encode('test'));

      expect(
        () => notesSource.restoreItem('../outside.txt', dummyStream),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => notesSource.restoreItem('vault/attack.bin', dummyStream),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => notesSource.restoreItem('.trash/hidden.txt', dummyStream),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}

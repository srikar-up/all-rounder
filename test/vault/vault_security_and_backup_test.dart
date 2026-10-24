import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:all_rounder/core/crypto/kdf.dart';
import 'package:all_rounder/core/crypto/sha256.dart';
import 'package:all_rounder/features/vault/models/vault_header.dart';
import 'package:all_rounder/features/vault/services/vault_auto_lock.dart';
import 'package:all_rounder/features/vault/services/vault_backup_source.dart';
import 'package:all_rounder/features/vault/services/vault_rate_limiter.dart';
import 'package:all_rounder/features/vault/services/vault_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VaultRateLimiter Tests (Phase 3)', () {
    late InMemoryAttemptStorage storage;
    late VaultRateLimiter limiter;

    setUp(() {
      storage = InMemoryAttemptStorage();
      limiter = VaultRateLimiter(storage);
    });

    test('no lockout for fewer than 3 failed attempts', () async {
      expect(await limiter.remainingLockoutSeconds(), 0);

      await limiter.recordFailure();
      expect(await limiter.remainingLockoutSeconds(), 0);

      await limiter.recordFailure();
      expect(await limiter.remainingLockoutSeconds(), 0);
    });

    test('exponential backoff after 3 or more failed attempts', () async {
      // 3 failures -> 1 second backoff
      final delay1 = await limiter.recordFailure();
      expect(delay1, 1);
      expect(await limiter.remainingLockoutSeconds(), 1);

      // 4 failures -> 2 seconds backoff
      final delay2 = await limiter.recordFailure();
      expect(delay2, 2);

      // 5 failures -> 4 seconds backoff
      final delay3 = await limiter.recordFailure();
      expect(delay3, 4);

      // 6 failures -> 8 seconds backoff
      final delay4 = await limiter.recordFailure();
      expect(delay4, 8);
    });

    test('recordSuccess clears failure count and remaining lockout', () async {
      await limiter.recordFailure();
      await limiter.recordFailure();
      await limiter.recordFailure();
      expect(await limiter.remainingLockoutSeconds(), greaterThan(0));

      await limiter.recordSuccess();
      expect(await limiter.remainingLockoutSeconds(), 0);
    });

    test('backoff does not exceed maximum cap (300 seconds)', () async {
      for (var i = 0; i < 20; i++) {
        await limiter.recordFailure();
      }
      final lockout = await limiter.remainingLockoutSeconds();
      expect(lockout, lessThanOrEqualTo(300));
    });
  });

  group('VaultAutoLock Tests (Phase 3)', () {
    test('delay durations match expectations', () {
      expect(AutoLockDelay.immediately.seconds, 0);
      expect(AutoLockDelay.thirtySeconds.seconds, 30);
      expect(AutoLockDelay.oneMinute.seconds, 60);
      expect(AutoLockDelay.fiveMinutes.seconds, 300);
    });

    test('immediately auto lock invokes callback on paused', () {
      bool locked = false;
      final observer = VaultAutoLockObserver(
        onLock: () => locked = true,
        delay: AutoLockDelay.immediately,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(locked, true);
    });

    test('delayed auto lock does not lock immediately on paused', () {
      bool locked = false;
      final observer = VaultAutoLockObserver(
        onLock: () => locked = true,
        delay: AutoLockDelay.fiveMinutes,
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      expect(locked, false);
    });
  });

  group('VaultBackupSource Tests (Phase 6)', () {
    late Directory tempDir;
    late VaultRepository repo;
    late VaultBackupSource backupSource;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_backup_test_');
      repo = VaultRepository(tempDir.path, customKdfParams: KdfParams.test);
      backupSource = VaultBackupSource(repo.vaultDir);
    });

    tearDown(() async {
      repo.lock();
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('listItems returns empty list when vault directory does not exist', () async {
      final nonExistentDir = Directory(p.join(tempDir.path, 'does_not_exist'));
      final source = VaultBackupSource(nonExistentDir);
      final items = await source.listItems();
      expect(items, isEmpty);
    });

    test('listItems lists header, index and blobs with accurate SHA-256 and sizes', () async {
      await repo.create('test-passphrase-123');

      // Add two files to vault
      final file1 = File(p.join(tempDir.path, 'doc.txt'));
      await file1.writeAsString('Hello World from Vault Test');
      final meta1 = await repo.addFile(file1);

      final file2 = File(p.join(tempDir.path, 'image.bin'));
      await file2.writeAsBytes(List.generate(1024, (i) => i % 256));
      final meta2 = await repo.addFile(file2);

      // Lock vault - backup source reads ciphertext only
      repo.lock();
      expect(repo.isUnlocked, false);

      final items = await backupSource.listItems();
      expect(items.length, 4); // header, index, and 2 blobs

      final ids = items.map((i) => i.id).toSet();
      expect(ids.contains('vault/vault.header'), true);
      expect(ids.contains('vault/index.enc'), true);
      expect(ids.contains('vault/data/${meta1.blobId}'), true);
      expect(ids.contains('vault/data/${meta2.blobId}'), true);

      // Verify each item's SHA-256 and stream
      for (final item in items) {
        expect(item.size, greaterThan(0));
        expect(item.sha256.length, 64);

        // Read stream and compute digest to confirm matching hash
        final streamBytes = await item.openRead().fold<List<int>>(<int>[], (p, e) => p..addAll(e));
        expect(streamBytes.length, item.size);

        final expectedHash = Sha256.hex(Sha256.digest(streamBytes));
        expect(item.sha256, expectedHash);
      }

      // Hash caching test: second listItems should succeed with identical hashes
      final cachedItems = await backupSource.listItems();
      expect(cachedItems.length, items.length);
      for (var i = 0; i < items.length; i++) {
        expect(cachedItems[i].sha256, items[i].sha256);
      }
    });

    test('restoreItem rejects malicious paths and non-vault IDs', () async {
      final dummyBytes = Stream.value(utf8.encode('test content'));

      // Path traversal
      expect(
        () => backupSource.restoreItem('vault/../outside.txt', dummyBytes),
        throwsA(isA<ArgumentError>()),
      );

      // Absolute path tricks
      expect(
        () => backupSource.restoreItem('/etc/passwd', dummyBytes),
        throwsA(isA<ArgumentError>()),
      );

      // Non-vault files
      expect(
        () => backupSource.restoreItem('vault/malicious.sh', dummyBytes),
        throwsA(isA<ArgumentError>()),
      );

      // Invalid blob name pattern
      expect(
        () => backupSource.restoreItem('vault/data/evil.exe', dummyBytes),
        throwsA(isA<ArgumentError>()),
      );

      expect(
        () => backupSource.restoreItem('vault/data/../index.enc', dummyBytes),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('full round trip: restore into empty directory unlocks and decrypts all files', () async {
      await repo.create('correct-horse-battery-staple');

      final secretDoc = File(p.join(tempDir.path, 'confidential.txt'));
      await secretDoc.writeAsString('Extremely confidential data for vault testing.');
      final meta = await repo.addFile(secretDoc);

      final originalItems = await backupSource.listItems();

      // Create a fresh new directory to simulate another device restore
      final restoreRoot = await Directory.systemTemp.createTemp('vault_restored_target_');
      try {
        final restoreDir = Directory(p.join(restoreRoot.path, 'vault'));
        final restoreBackupSource = VaultBackupSource(restoreDir);

        // Restore every item into the new location
        for (final item in originalItems) {
          await restoreBackupSource.restoreItem(item.id, item.openRead());
        }

        // Now instantiate a VaultRepository on the restored directory
        final restoredRepo = VaultRepository(restoreRoot.path, customKdfParams: KdfParams.test);
        expect(restoredRepo.exists, true);
        expect(restoredRepo.isUnlocked, false);

        // Unlock with original passphrase
        await restoredRepo.unlockWithPassphrase('correct-horse-battery-staple');
        expect(restoredRepo.isUnlocked, true);

        // Verify index files exist
        expect(restoredRepo.index.files.length, 1);
        expect(restoredRepo.index.files.first.name, 'confidential.txt');

        // Read decrypted bytes and verify exact plaintext match
        final decryptedBytes = await restoredRepo.readBytes(meta.id);
        expect(utf8.decode(decryptedBytes), 'Extremely confidential data for vault testing.');
      } finally {
        if (await restoreRoot.exists()) {
          await restoreRoot.delete(recursive: true);
        }
      }
    });
  });
}

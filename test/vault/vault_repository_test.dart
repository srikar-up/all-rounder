import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/core/crypto/aead_box.dart';
import 'package:all_rounder/features/vault/models/vault_header.dart';
import 'package:all_rounder/features/vault/services/vault_repository.dart';

void main() {
  group('VaultRepository Tests (Phase 2)', () {
    late Directory tempDir;
    late VaultRepository repo;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('vault_repo_test_');
      repo = VaultRepository(tempDir.path, customKdfParams: KdfParams.test);
    });

    tearDown(() async {
      repo.lock();
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } catch (_) {}
      }
    });

    test('2.1 create then unlock with passphrase and recovery code', () async {
      final recoveryCode = await repo.create('MasterSecret123');
      expect(repo.isUnlocked, isTrue);
      expect(repo.exists, isTrue);

      // Lock
      repo.lock();
      expect(repo.isUnlocked, isFalse);

      // Wrong passphrase fails
      expect(() => repo.unlockWithPassphrase('WrongPass'), throwsA(isA<VaultCryptoException>()));
      expect(repo.isUnlocked, isFalse);

      // Correct passphrase succeeds
      await repo.unlockWithPassphrase('MasterSecret123');
      expect(repo.isUnlocked, isTrue);

      // Lock again and unlock with recovery code
      repo.lock();
      expect(() => repo.unlockWithRecoveryCode('ABCD-EFGH-1234'), throwsA(anything));
      expect(repo.isUnlocked, isFalse);

      await repo.unlockWithRecoveryCode(recoveryCode);
      expect(repo.isUnlocked, isTrue);
    });

    test('2.2 add, read and export give identical bytes, delete removes blob', () async {
      await repo.create('Passphrase456');

      final sampleFile = File('${tempDir.path}/original.png');
      final originalBytes = Uint8List.fromList(List.generate(5000, (i) => (i * 13) % 256));
      await sampleFile.writeAsBytes(originalBytes);

      final meta = await repo.addFile(sampleFile, customName: 'test_image.png');
      expect(repo.index.files.length, 1);
      expect(repo.index.files.first.name, 'test_image.png');

      // Read bytes into memory
      final inMemoryBytes = await repo.readBytes(meta.id);
      expect(inMemoryBytes, equals(originalBytes));

      // Export to file
      final exportedFile = File('${tempDir.path}/exported.png');
      await repo.exportTo(meta.id, exportedFile);
      expect(await exportedFile.readAsBytes(), equals(originalBytes));

      // Delete item
      await repo.deleteItem(meta.id, isFolder: false);
      expect(repo.index.files.isEmpty, isTrue);

      // Blob must be removed from disk
      final blobPath = '${tempDir.path}/vault/data/${meta.blobId}';
      expect(await File(blobPath).exists(), isFalse);
    });

    test('2.3 change passphrase rewraps VMK and invalidates old passphrase', () async {
      await repo.create('OldPassphrase123');
      final sample = File('${tempDir.path}/doc.txt');
      await sample.writeAsString('Confidential document contents');
      final meta = await repo.addFile(sample);

      await repo.changePassphrase('OldPassphrase123', 'NewPassphrase789');

      repo.lock();

      // Old passphrase fails
      expect(() => repo.unlockWithPassphrase('OldPassphrase123'), throwsA(isA<VaultCryptoException>()));

      // New passphrase succeeds and files remain readable
      await repo.unlockWithPassphrase('NewPassphrase789');
      final read = await repo.readBytes(meta.id);
      expect(String.fromCharCodes(read), 'Confidential document contents');
    });

    test('2.4 header tampering is detected and fails unlock', () async {
      await repo.create('SecurePassword');
      repo.lock();

      final headerFile = File('${tempDir.path}/vault/vault.header');
      final headerContent = await headerFile.readAsString();

      // Tamper with header content
      await headerFile.writeAsString(headerContent.replaceFirst('argon2id', 'argon2i'));

      expect(() => repo.unlockWithPassphrase('SecurePassword'), throwsA(isA<VaultCryptoException>()));
    });

    test('2.5 lock() makes operations throw', () async {
      await repo.create('Pass');
      repo.lock();

      expect(() => repo.readBytes('any_id'), throwsA(isA<VaultCryptoException>()));
      expect(() => repo.createFolder('folder'), throwsA(isA<VaultCryptoException>()));
      expect(() => repo.addFile(File('x')), throwsA(isA<VaultCryptoException>()));
    });

    test('2.6 corrupt index.enc falls back to index.enc.bak', () async {
      await repo.create('Pass123');
      await repo.createFolder('Docs');
      expect(repo.index.folders.length, 1);

      // Verify backup exists
      final indexEnc = File('${tempDir.path}/vault/index.enc');
      final indexBak = File('${tempDir.path}/vault/index.enc.bak');
      expect(await indexEnc.exists(), isTrue);

      // Add second item to create a backup
      await repo.createFolder('Photos');
      expect(await indexBak.exists(), isTrue);

      repo.lock();

      // Corrupt primary index.enc
      await indexEnc.writeAsBytes([1, 2, 3, 4, 5, 6, 7, 8]);

      // Unlock should fall back to .bak without failing
      await repo.unlockWithPassphrase('Pass123');
      expect(repo.isUnlocked, isTrue);
      expect(repo.index.folders.isNotEmpty, isTrue);
    });
  });
}

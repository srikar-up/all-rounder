import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/core/crypto/aead_box.dart';
import 'package:all_rounder/core/crypto/kdf.dart';
import 'package:all_rounder/core/crypto/recovery_code.dart';
import 'package:all_rounder/core/crypto/vault_file_crypto.dart';

void main() {
  group('Vault Crypto Core Tests (Phase 1)', () {
    late Uint8List testKey;

    setUp(() {
      testKey = RecoveryCode.generateBytes(32);
    });

    test('1.1 AeadBox seal and open round-trip for various sizes', () async {
      for (final size in [0, 1, 1000, 100000]) {
        final plain = Uint8List(size);
        for (var i = 0; i < size; i++) {
          plain[i] = (i * 31 + 7) & 0xFF;
        }

        final sealed = await AeadBox.seal(testKey, plain, aad: [1, 2, 3]);
        expect(sealed.length, equals(plain.length + AeadBox.nonceLength + AeadBox.tagLength));

        final opened = await AeadBox.open(testKey, sealed, aad: [1, 2, 3]);
        expect(opened, equals(plain));
      }
    });

    test('1.2 AeadBox tamper and authentication checks', () async {
      final plain = Uint8List.fromList([1, 2, 3, 4, 5]);
      final sealed = await AeadBox.seal(testKey, plain, aad: [10, 20]);

      // Two seals differ due to random nonces
      final sealed2 = await AeadBox.seal(testKey, plain, aad: [10, 20]);
      expect(sealed, isNot(equals(sealed2)));

      // Wrong key throws
      final wrongKey = RecoveryCode.generateBytes(32);
      expect(() => AeadBox.open(wrongKey, sealed, aad: [10, 20]), throwsA(isA<VaultCryptoException>()));

      // Wrong AAD throws
      expect(() => AeadBox.open(testKey, sealed, aad: [10, 99]), throwsA(isA<VaultCryptoException>()));

      // Flipped bit in ciphertext or tag throws
      final tampered = Uint8List.fromList(sealed);
      tampered[AeadBox.nonceLength + 1] ^= 0x01;
      expect(() => AeadBox.open(testKey, tampered, aad: [10, 20]), throwsA(isA<VaultCryptoException>()));

      // Truncated data throws
      expect(() => AeadBox.open(testKey, sealed.sublist(0, 20)), throwsA(isA<VaultCryptoException>()));
    });

    test('1.3 KDF HKDF and Argon2id derive consistent keys', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));

      // HKDF
      final hkdfKey1 = await Kdf.hkdf(testKey, salt: salt, info: 'arv1/file');
      final hkdfKey2 = await Kdf.hkdf(testKey, salt: salt, info: 'arv1/file');
      expect(hkdfKey1.length, 32);
      expect(hkdfKey1, equals(hkdfKey2));

      final hkdfDifferentInfo = await Kdf.hkdf(testKey, salt: salt, info: 'arv1/index');
      expect(hkdfKey1, isNot(equals(hkdfDifferentInfo)));

      // Argon2id with test parameters
      final argon1 = await Kdf.argon2id('test-passphrase-123', salt: salt, memoryKiB: 64, iterations: 1, parallelism: 1);
      final argon2 = await Kdf.argon2id('test-passphrase-123', salt: salt, memoryKiB: 64, iterations: 1, parallelism: 1);
      expect(argon1.length, 32);
      expect(argon1, equals(argon2));

      final argonDiffPass = await Kdf.argon2id('other-passphrase', salt: salt, memoryKiB: 64, iterations: 1, parallelism: 1);
      expect(argon1, isNot(equals(argonDiffPass)));
    });

    test('1.4 Base32 RecoveryCode round-trip, grouping, and error handling', () {
      for (var i = 0; i < 20; i++) {
        final bytes = RecoveryCode.generateBytes(32);
        final encoded = RecoveryCode.encode(bytes);

        // Grouped by 4 characters with delimiter
        expect(encoded.contains('-'), isTrue);

        // Case-insensitive, space, and dash tolerant decode
        final decoded = RecoveryCode.decode(encoded);
        expect(decoded, equals(bytes));

        final spacedLower = encoded.toLowerCase().replaceAll('-', ' ');
        final decodedSpaced = RecoveryCode.decode(spacedLower);
        expect(decodedSpaced, equals(bytes));
      }

      // Invalid character throws
      expect(() => RecoveryCode.decode('ABCD-1890'), throwsFormatException);
    });

    test('1.5 VaultFileCrypto chunked blob round-trip and tamper detection', () async {
      final tempDir = await Directory.systemTemp.createTemp('vault_crypto_test_');
      try {
        final fileKey = RecoveryCode.generateBytes(32);
        final fileId = RecoveryCode.generateBytes(16);

        // Test boundary sizes: 0, 1, 65535, 65536, 65537
        for (final size in [0, 1, 65535, 65536, 65537]) {
          final srcFile = File('${tempDir.path}/src_$size.dat');
          final encFile = File('${tempDir.path}/enc_$size.bin');

          final rawData = Uint8List(size);
          for (var i = 0; i < size; i++) {
            rawData[i] = (i * 17) & 0xFF;
          }
          await srcFile.writeAsBytes(rawData);

          await VaultFileCrypto.encryptFile(
            source: srcFile,
            target: encFile,
            fileKey: fileKey,
            fileId: fileId,
          );

          // Decrypt to stream and reconstruct
          final decryptedChunks = <int>[];
          await for (final chunk in VaultFileCrypto.decryptToStream(
            source: encFile,
            fileKey: fileKey,
            fileId: fileId,
          )) {
            decryptedChunks.addAll(chunk);
          }

          expect(decryptedChunks, equals(rawData));
        }

        // Tamper test: flipped byte in ciphertext must throw
        final goodEnc = File('${tempDir.path}/enc_65536.bin');
        final tamperedFile = File('${tempDir.path}/enc_tampered.bin');
        final encBytes = await goodEnc.readAsBytes();
        encBytes[35] ^= 0x01; // flip bit in chunk ciphertext
        await tamperedFile.writeAsBytes(encBytes);

        expect(
          () async {
            await for (final _ in VaultFileCrypto.decryptToStream(
              source: tamperedFile,
              fileKey: fileKey,
              fileId: fileId,
            )) {}
          },
          throwsA(isA<VaultCryptoException>()),
        );

        // Tamper test: wrong fileId must throw
        final wrongFileId = RecoveryCode.generateBytes(16);
        expect(
          () async {
            await for (final _ in VaultFileCrypto.decryptToStream(
              source: goodEnc,
              fileKey: fileKey,
              fileId: wrongFileId,
            )) {}
          },
          throwsA(isA<VaultCryptoException>()),
        );

        // Tamper test: truncated file must throw
        final truncatedFile = File('${tempDir.path}/enc_truncated.bin');
        await truncatedFile.writeAsBytes(encBytes.sublist(0, encBytes.length - 10));
        expect(
          () async {
            await for (final _ in VaultFileCrypto.decryptToStream(
              source: truncatedFile,
              fileKey: fileKey,
              fileId: fileId,
            )) {}
          },
          throwsA(isA<VaultCryptoException>()),
        );
      } finally {
        await tempDir.delete(recursive: true);
      }
    });

    test('1.6 Failed encryption cleans up temporary file', () async {
      final tempDir = await Directory.systemTemp.createTemp('vault_cleanup_test_');
      try {
        final nonExistentSource = File('${tempDir.path}/does_not_exist.bin');
        final target = File('${tempDir.path}/target.bin');

        try {
          await VaultFileCrypto.encryptFile(
            source: nonExistentSource,
            target: target,
            fileKey: testKey,
            fileId: RecoveryCode.generateBytes(16),
          );
        } catch (_) {}

        // Ensure no .tmp or target file is left
        expect(await File('${target.path}.tmp').exists(), isFalse);
        expect(await target.exists(), isFalse);
      } finally {
        await tempDir.delete(recursive: true);
      }
    });
  });
}

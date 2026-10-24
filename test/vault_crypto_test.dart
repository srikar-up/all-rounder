import 'package:flutter_test/flutter_test.dart';
import 'package:all_rounder/features/vault/services/vault_crypto_service.dart';
import 'package:all_rounder/features/vault/state/vault_notifier.dart';

void main() {
  group('Vault & Crypto Specification Tests (Plan Section 5)', () {
    test('Recovery phrase generation produces 12 words', () {
      final phrase = VaultCryptoService.generateRecoveryKey();
      final words = phrase.split(' ');
      expect(words.length, 12);
      expect(words.every((w) => w.isNotEmpty), isTrue);
    });

    test('AES-GCM mock payload round-trip encryption & decryption', () {
      const plaintext = 'Secret payload: 42-X-CONFIDENTIAL';
      const key = 'test_key_master';

      final encrypted = VaultCryptoService.encryptPayload(plaintext, key);
      expect(encrypted.startsWith('v1:AES-GCM:'), isTrue);
      expect(encrypted.contains(plaintext), isFalse);

      final decrypted = VaultCryptoService.decryptPayload(encrypted, key);
      expect(decrypted, equals(plaintext));
    });

    test('VaultNotifier lock/unlock lifecycle with PIN and recovery key', () {
      final vault = VaultNotifier();

      // Starts locked
      expect(vault.isUnlocked, isFalse);

      // Wrong PIN fails
      final wrongPin = vault.unlockWithPasscode('0000');
      expect(wrongPin, isFalse);
      expect(vault.isUnlocked, isFalse);

      // Correct PIN unlocks
      final correctPin = vault.unlockWithPasscode('1234');
      expect(correctPin, isTrue);
      expect(vault.isUnlocked, isTrue);

      // Lock again
      vault.lock();
      expect(vault.isUnlocked, isFalse);

      // Unlock with recovery key
      final recoverySuccess = vault.unlockWithRecoveryKey(vault.recoveryKey);
      expect(recoverySuccess, isTrue);
      expect(vault.isUnlocked, isTrue);
    });
  });
}

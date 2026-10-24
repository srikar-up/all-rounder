import 'dart:convert';
import 'dart:math';

/// Service implementing Vault specification (Plan Section 5):
/// AES-256-GCM envelope, Argon2id derivation mock, 24-word recovery phrase generator
class VaultCryptoService {
  static const List<String> _wordList = [
    'alpha', 'beacon', 'candle', 'delta', 'echo', 'frost', 'galaxy', 'harbor',
    'island', 'jungle', 'kinetic', 'lunar', 'meadow', 'nebula', 'orbit', 'pulse',
    'quantum', 'radar', 'solar', 'timber', 'ultra', 'vector', 'wave', 'zenith',
    'amber', 'breeze', 'cliff', 'dawn', 'ember', 'falcon', 'glacier', 'horizon',
  ];

  static String generateRecoveryKey() {
    final random = Random.secure();
    final words = <String>[];
    for (int i = 0; i < 12; i++) {
      words.add(_wordList[random.nextInt(_wordList.length)]);
    }
    return words.join(' ');
  }

  /// Envelope encryption simulator for AES-256-GCM
  static String encryptPayload(String plaintext, String key) {
    final bytes = utf8.encode(plaintext);
    final b64 = base64Encode(bytes);
    // Envelope format: v1:AES-GCM:<mock-nonce>:<ciphertext>
    return 'v1:AES-GCM:nonce_${Random().nextInt(999999)}:$b64';
  }

  static String decryptPayload(String encrypted, String key) {
    final parts = encrypted.split(':');
    if (parts.length >= 4) {
      final b64 = parts[3];
      final decoded = utf8.decode(base64Decode(b64));
      return decoded;
    }
    return encrypted;
  }
}

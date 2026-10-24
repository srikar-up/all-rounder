import 'dart:math';
import 'dart:typed_data';
import 'xchacha20_poly1305.dart';

class VaultCryptoException implements Exception {
  const VaultCryptoException(this.message);
  final String message;

  @override
  String toString() => message;
}

class AeadBox {
  static const nonceLength = 24;
  static const tagLength = 16;

  /// Returns nonce(24) | ciphertext | tag(16) using XChaCha20-Poly1305
  static Future<Uint8List> seal(
    List<int> key,
    List<int> plain, {
    List<int> aad = const [],
    List<int>? customNonce,
  }) async {
    final nonce = customNonce ?? _generateSecureRandom(nonceLength);
    final sealed = XChaCha20Poly1305.seal(
      key: key,
      nonce: nonce,
      plaintext: plain,
      aad: aad,
    );
    return sealed;
  }

  /// Opens sealed data [nonce(24) | ciphertext | tag(16)] or throws VaultCryptoException
  static Future<Uint8List> open(
    List<int> key,
    List<int> sealed, {
    List<int> aad = const [],
  }) async {
    if (sealed.length < nonceLength + tagLength) {
      throw const VaultCryptoException('Data is too short');
    }
    try {
      final clear = XChaCha20Poly1305.open(
        key: key,
        sealed: sealed,
        aad: aad,
      );
      return clear;
    } catch (_) {
      throw const VaultCryptoException('Wrong key, or the data was modified');
    }
  }

  static Uint8List _generateSecureRandom(int length) {
    final rnd = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = rnd.nextInt(256);
    }
    return bytes;
  }
}

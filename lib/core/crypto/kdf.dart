import 'dart:convert';
import 'dart:typed_data';
import 'argon2.dart';
import 'sha256.dart';

class Kdf {
  /// HKDF-SHA256 (RFC 5869) deriving 32-byte key
  static Future<Uint8List> hkdf(
    List<int> secret, {
    required List<int> salt,
    required String info,
    int length = 32,
  }) async {
    return Sha256.hkdf(
      secret: secret,
      salt: salt,
      info: utf8.encode(info),
      length: length,
    );
  }

  /// Argon2id password-based key derivation (RFC 9106)
  static Future<Uint8List> argon2id(
    String passphrase, {
    required List<int> salt,
    required int memoryKiB,
    required int iterations,
    required int parallelism,
    int hashLength = 32,
  }) async {
    return Argon2.deriveKey(
      password: passphrase,
      salt: salt,
      memoryKiB: memoryKiB,
      iterations: iterations,
      parallelism: parallelism,
      hashLength: hashLength,
    );
  }
}

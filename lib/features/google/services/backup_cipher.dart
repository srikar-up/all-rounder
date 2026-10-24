import 'dart:convert';
import 'dart:typed_data';
import '../../../core/crypto/aead_box.dart';

class BackupCipher {
  final Uint8List key;

  const BackupCipher(this.key);

  /// Seals plaintext bytes bound to the remote filename via authenticated associated data
  Future<Uint8List> seal(List<int> plain, String remoteName) async {
    final aad = utf8.encode('ARBK1|$remoteName');
    return AeadBox.seal(key, plain, aad: aad);
  }

  /// Opens sealed ciphertext bytes verifying authentication and remote filename binding
  Future<Uint8List> open(List<int> sealed, String remoteName) async {
    final aad = utf8.encode('ARBK1|$remoteName');
    return AeadBox.open(key, sealed, aad: aad);
  }
}
